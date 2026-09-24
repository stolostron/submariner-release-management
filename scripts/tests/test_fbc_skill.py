"""Skill entrypoint, independent inputs, and mutation preflight contracts."""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from test_fbc_onboarding import ROOT, mod


class SkillFlow(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / "data"
        self.fbc = self.root / "fbc"
        for root in (self.data, self.fbc):
            root.mkdir()
            mod.run("git", "init", "-q", "-b", "main", cwd=root)
            for name, value in (
                ("user.name", "Fixture"),
                ("user.email", "fixture@example.invalid"),
                ("commit.gpgsign", "false"),
                ("core.hooksPath", "/dev/null"),
            ):
                mod.run("git", "config", name, value, cwd=root)
        base = self.data / mod.OVERLAYS / "base/kustomization.yaml"
        base.parent.mkdir(parents=True)
        base.write_text("resources: []\n")
        overlay = self.data / mod.OVERLAYS / "4-21-overlay"
        overlay.mkdir()
        for number in range(8):
            (overlay / f"{number}.yaml").write_text("[]\n")
        (self.data / "tenants-config/utils.sh").write_text(
            "export KUSTOMIZE_VERSION=v5.7.1\n"
        )
        admissions = json.loads(
            (ROOT / "scripts/tests/fixtures/ocp5-admissions.json").read_text()
        )
        (self.data / mod.RPA).mkdir(parents=True)
        for env, data in admissions.items():
            mod.save(self.data / mod.RPA / f"submariner-fbc-{env}.yaml", data)
        (self.fbc / ".tekton").mkdir()
        for event in ("push", "pull-request"):
            (self.fbc / ".tekton" / f"submariner-fbc-4-22-{event}.yaml").write_text(
                "{}\n"
            )
        (self.fbc / "test/lib").mkdir(parents=True)
        (self.fbc / "test/lib/isolate.sh").write_text("# fixture\n")
        (self.fbc / "drop-versions.json").write_text('{"4.22": "0.23"}\n')
        mod.save(
            self.fbc / "catalog-template.yaml",
            {
                "entries": [
                    {
                        "schema": "olm.package",
                        "name": "submariner",
                        "defaultChannel": "stable-0.24",
                    },
                    {
                        "schema": "olm.channel",
                        "name": "stable-0.24",
                        "entries": [{"name": "submariner.v0.24.1"}],
                    },
                ]
            },
        )
        for root in (self.data, self.fbc):
            mod.run("git", "add", ".", cwd=root)
            mod.run("git", "commit", "-qm", "Fixture", cwd=root)
        self.data_sha = mod.base_commit(self.data, "HEAD")
        self.fbc_sha = mod.base_commit(self.fbc, "HEAD")
        self.args = [
            "5.0",
            "--min-supported-sub",
            "0.24",
            "--release-data-repo",
            str(self.data),
            "--fbc-repo",
            str(self.fbc),
            "--release-data-ref",
            self.data_sha,
            "--fbc-ref",
            self.fbc_sha,
            "--workspace",
            str(self.root / "work"),
        ]

    def invoke(self, args):
        with (
            patch.object(mod, "require_tools"),
            patch.object(mod, "kustomize_binary", return_value="kustomize"),
        ):
            with redirect_stdout(io.StringIO()) as output:
                mod.main(args)
        return json.loads(output.getvalue())

    def test_independent_pins_and_predecessors_read_only(self):
        before = [
            mod.run("git", "status", "--porcelain=v1", cwd=root)
            for root in (self.data, self.fbc)
        ]
        result = self.invoke(self.args)
        self.assertNotEqual(self.data_sha, self.fbc_sha)
        self.assertEqual(result["sources"]["configuration"]["commit"], self.data_sha)
        self.assertEqual(result["sources"]["catalog"]["commit"], self.fbc_sha)
        self.assertEqual(result["sources"]["configuration"]["previous"], "4-21")
        self.assertEqual(result["sources"]["catalog"]["previous"], "4-22")
        self.assertEqual(result["blockers"], {"configuration": [], "catalog": []})
        self.assertFalse((self.root / "work").exists())
        self.assertEqual(
            before,
            [
                mod.run("git", "status", "--porcelain=v1", cwd=root)
                for root in (self.data, self.fbc)
            ],
        )

    def test_missing_channel_is_reported_then_rejected_before_writes(self):
        args = ["0.25" if arg == "0.24" else arg for arg in self.args]
        result = self.invoke(args)
        self.assertIn("No populated stable-0.25", result["blockers"]["catalog"][0])
        with self.assertRaisesRegex(ValueError, "No populated stable-0.25"):
            self.invoke(args + ["--phase", "prepare"])
        self.assertFalse((self.root / "work").exists())

    def test_configuration_does_not_require_fbc_or_policy(self):
        args = list(self.args)
        del args[1:3]
        args[args.index(str(self.fbc))] = "/missing-fbc"
        with (
            patch.object(mod, "prepare_tenant") as tenant,
            patch.object(mod, "prepare_rpas"),
        ):
            result = self.invoke(args + ["--phase", "prepare-config"])
        self.assertEqual(result["prepared"], ["tenant", "admission"])
        tenant.assert_called_once()
        self.assertNotIn("catalog", result["sources"])

    def test_catalog_does_not_require_release_data(self):
        args = list(self.args)
        args[args.index(str(self.data))] = "/missing-data"
        with (
            patch.object(mod, "prepare_catalog") as catalog,
            patch.object(mod, "inspect_base_image"),
        ):
            result = self.invoke(args + ["--phase", "prepare-catalog"])
        self.assertEqual(result["prepared"], ["fbc"])
        catalog.assert_called_once()
        self.assertNotIn("configuration", result["sources"])

    def test_conflicting_refs_fail_without_creating_workspace(self):
        with self.assertRaisesRegex(ValueError, "conflicting --base"):
            self.invoke(self.args + ["--base", "HEAD", "--phase", "prepare"])
        self.assertFalse((self.root / "work").exists())

    def test_unsupported_kustomize_is_detected_before_worktree_creation(self):
        binary = self.root / "kustomize"
        binary.write_text("#!/bin/sh\nprintf 'v5.6.0\\n'\n")
        binary.chmod(0o755)
        with patch.object(mod, "require_tools"):
            with self.assertRaisesRegex(ValueError, "v5.7.1 or newer required"):
                mod.main(
                    self.args
                    + ["--kustomize", str(binary), "--phase", "prepare-config"]
                )
        self.assertFalse((self.root / "work").exists())

    def test_installed_wrapper_resolves_executable_and_documentation(self):
        installed = self.root / "installed/add-fbc-ocp-version"
        shutil.copytree(ROOT / "skills/add-fbc-ocp-version", installed)
        script = installed / "scripts/run.sh"
        env = dict(os.environ, RELEASE_MANAGEMENT_REPO=str(ROOT))
        for cwd in (self.root, self.fbc, ROOT):
            with self.subTest(cwd=cwd):
                result = subprocess.run(
                    [str(script), "--workflow"],
                    cwd=cwd,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                self.assertEqual(
                    Path(result.stdout.strip()),
                    ROOT / ".agents/workflows/add-fbc-ocp-version.md",
                )
                result = subprocess.run(
                    [str(script), "--help"],
                    cwd=cwd,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                self.assertIn("--release-data-ref", result.stdout)
