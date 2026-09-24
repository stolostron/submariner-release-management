"""Offline regressions for the OCP-major transition and safe onboarding."""

import argparse
import importlib.util
import io
from contextlib import redirect_stdout
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "onboard", ROOT / "scripts/fbc-onboard.py"
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class Onboarding(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def git(self, *args, cwd=None):
        return mod.run("git", *args, cwd=cwd or self.root).strip()

    def init_repo(self):
        self.git("init", "-q")
        (self.root / "input").write_text("committed\n")
        self.git("add", ".")
        self.git(
            "-c",
            "user.name=Test",
            "-c",
            "user.email=test@example.org",
            "-c",
            "commit.gpgsign=false",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "-qm",
            "base",
        )

    def test_full_versions_and_bad_inputs(self):
        for value in ("5.0", "5-0"):
            self.assertEqual(mod.ocp(value), "5-0")
        for value in ("5", "5.00", "5.0.1", "5x0", "0.5", "../5-0"):
            with self.assertRaises(argparse.ArgumentTypeError):
                mod.ocp(value)

    def test_extra_argument_is_rejected_before_repository_access(self):
        result = subprocess.run(
            [str(ROOT / "scripts/add-fbc-ocp-version.sh"), "5.0", "0.23", "ignored"],
            cwd=self.root,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("unrecognized arguments", result.stderr)
        self.assertFalse(list(self.root.iterdir()))

    def test_legacy_cutoff_keeps_old_semantics(self):
        with patch.object(mod, "repo", side_effect=ValueError("stop after arguments")):
            with patch("sys.stderr") as stderr:
                with redirect_stdout(io.StringIO()) as output:
                    mod.main(["5.0", "0.23"])
                plan = json.loads(output.getvalue())
                self.assertEqual(plan["minimum_inclusive"], "0.24")
                self.assertEqual(plan["cutoff_exclusive"], "0.23")
                self.assertEqual(plan["blockers"]["catalog"], ["stop after arguments"])
                self.assertIn(
                    "inclusive minimum is 0.24",
                    "".join(call.args[0] for call in stderr.write.call_args_list),
                )
        with self.assertRaisesRegex(ValueError, "Do not combine"):
            mod.main(["5.0", "0.23", "--min-supported-sub", "0.25"])

    def test_worktree_preserves_dirty_checkout_and_existing_branch(self):
        self.init_repo()
        before = self.git("rev-parse", "HEAD")
        branch = self.git("branch", "--show-current")
        (self.root / "input").write_text("unsaved\n")
        (self.root / "untracked").write_text("retain\n")
        target = self.root.parent / (self.root.name + "-worktree")
        self.addCleanup(
            lambda: (
                self.git("worktree", "remove", "--force", str(target))
                if target.exists()
                else None
            )
        )
        mod.worktree(self.root, target, "HEAD", "ocp-5-test")
        self.assertEqual((self.root / "input").read_text(), "unsaved\n")
        self.assertEqual((self.root / "untracked").read_text(), "retain\n")
        self.assertEqual(self.git("branch", "--show-current"), branch)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        (target / "candidate").write_text("keep on resume\n")
        mod.worktree(self.root, target, "HEAD", "ocp-5-test")
        self.assertEqual((target / "candidate").read_text(), "keep on resume\n")
        with self.assertRaisesRegex(ValueError, "already exists"):
            mod.worktree(self.root, self.root / "other", "HEAD", "ocp-5-test")
        self.assertEqual(self.git("rev-parse", "ocp-5-test"), before)

    def test_resource_registration_is_idempotent_and_preserves_comments(self):
        path = self.root / "kustomization.yaml"
        path.write_text("# keep\nresources:\n  - old # comment\npatches: []\n")
        mod.add_resource(path, "new")
        once = path.read_text()
        mod.add_resource(path, "new")
        self.assertEqual(path.read_text(), once)
        self.assertEqual(mod.load(path)["resources"], ["new", "old"])
        self.assertIn("# comment", once)

    def test_predecessor_orders_major_and_minor(self):
        self.init_repo()
        for version in ("4-9", "4-22", "5-0", "5-1"):
            path = self.root / mod.OVERLAYS / f"{version}-overlay/input"
            path.parent.mkdir(parents=True)
            path.write_text("overlay\n")
        self.git("add", ".")
        self.git(
            "-c",
            "user.name=Test",
            "-c",
            "user.email=test@localhost",
            "-c",
            "core.hooksPath=/dev/null",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "overlays",
        )
        self.assertEqual(mod.predecessor_at_ref(self.root, "5-0", "HEAD"), "4-22")
        self.assertEqual(mod.predecessor_at_ref(self.root, "5-1", "HEAD"), "5-0")

    def test_seven_malformed_objects_do_not_count_as_configuration(self):
        directory = self.root / mod.GENERATED
        directory.mkdir(parents=True)
        for i in range(7):
            (directory / f"{i}.yaml").write_text("hello: world\n")
        with self.assertRaises((ValueError, KeyError)):
            mod.validate_tenant(self.root, "5-0")

    def test_new_release_yaml_full_identity_and_snapshot_guard(self):
        script = ROOT / "scripts/generate-fbc-release.sh"
        result = subprocess.run(
            [
                str(script),
                "5.0",
                "0.24.1",
                "submariner-fbc-5-0-abc",
                "stage",
                "20260924",
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=True,
        )
        data = yaml.safe_load((self.root / result.stdout.strip()).read_text())
        self.assertEqual(
            data["spec"]["releasePlan"], "submariner-fbc-release-plan-stage-5-0"
        )
        self.assertEqual(
            data["metadata"]["name"], "submariner-fbc-5-0-0-24-1-stage-20260924-01"
        )
        result = subprocess.run(
            [
                str(script),
                "5.0",
                "0.24.1",
                "submariner-fbc-4-22-abc",
                "prod",
                "20260924",
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "releases/fbc/5-0/prod").exists())

    def test_snapshot_results_fail_closed(self):
        command = f'source "{ROOT}/scripts/lib/fbc-snapshot.sh"; fbc_tests_passed 5-0'
        passing = [
            {"scenario": f"submariner-fbc-{kind}-5-0", "status": "TestPassed"}
            for kind in ("standard", "operator")
        ]
        cases = [
            (passing, 0),
            ([], 1),
            ({}, 1),
            (passing[:1], 1),
            (passing + passing, 1),
        ]
        for status in ("BuildPLRInProgress", "InProgress", "TestSkipped", "TestFailed"):
            cases.append(([passing[0], dict(passing[1], status=status)], 1))
        for data, expected in cases:
            result = subprocess.run(
                ["bash", "-c", command], input=json.dumps(data), text=True
            )
            self.assertEqual(result.returncode, expected, data)
        self.assertNotEqual(
            subprocess.run(
                ["bash", "-c", command], input="broken", text=True
            ).returncode,
            0,
        )

    def test_fbc_verifier_rejects_malformed_http_success_and_absent_snapshot(self):
        curl = self.root / "curl"
        curl.write_text("""#!/bin/bash
while [ "$#" -gt 0 ]; do
  case "$1" in -o) file=$2; shift 2 ;; *) shift ;; esac
done
if [ "${FIXTURE_VALID:-}" = yes ]; then
  printf 'image: quay.io/example@sha256:%064d\n' 0 > "$file"
else
  echo 'not a catalog' > "$file"
fi
printf 200
""")
        curl.chmod(0o755)
        oc = self.root / "oc"
        oc.write_text("""#!/bin/bash
echo '{"items":[]}'
""")
        oc.chmod(0o755)
        environment = dict(
            os.environ,
            PATH=str(self.root) + ":" + os.environ["PATH"],
            FBC_OCP_VERSIONS="5-0",
        )
        for mode, expected in [
            ("no", "malformed bundle content"),
            ("yes", "has no snapshot"),
        ]:
            result = subprocess.run(
                [str(ROOT / "scripts/verify-fbc-release.sh"), "0.24.1"],
                env=dict(environment, FIXTURE_VALID=mode),
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(expected, result.stderr)

    def test_prod_reuses_exact_stage_snapshot_for_five(self):
        # Execute production's actual selection function without commits or network.
        script = (ROOT / "scripts/create-fbc-releases.sh").read_text()
        function = script[
            script.index("verify_release() {") : script.index(
                "\n# ===", script.index("verify_release() {")
            )
        ]
        directory = self.root / "releases/fbc/5-0/stage"
        directory.mkdir(parents=True)
        for version, snapshot in [("0-24-0", "older"), ("0-24-1", "qe-validated")]:
            (
                directory / f"submariner-fbc-5-0-{version}-stage-20260924-01.yaml"
            ).write_text(
                yaml.safe_dump(
                    {
                        "apiVersion": "appstudio.redhat.com/v1alpha1",
                        "kind": "Release",
                        "metadata": {
                            "name": f"submariner-fbc-5-0-{version}-stage-20260924-01",
                            "namespace": "submariner-tenant",
                            "annotations": {"snapshot": "decoy"},
                        },
                        "spec": {
                            "releasePlan": "submariner-fbc-release-plan-stage-5-0",
                            "snapshot": f"submariner-fbc-5-0-{snapshot}",
                        },
                    }
                )
            )
        env = dict(os.environ, GIT_ROOT=str(self.root))
        result = subprocess.run(
            [
                "bash",
                "-euc",
                function
                + '\nVERSION=0.24.1; RELEASE_TYPE=prod; OCP_FILTER=5-0; declare -A SNAPSHOTS; verify_release; echo "SELECTED=${SNAPSHOTS[5-0]}"',
            ],
            env=env,
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertIn("SELECTED=submariner-fbc-5-0-qe-validated", result.stdout)

    def test_live_verification_requires_complete_build_evidence(self):
        from contextlib import redirect_stdout
        from io import StringIO
        from types import SimpleNamespace

        version, app, commit = "5-0", "submariner-fbc-5-0", "a" * 40
        base = "registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0"
        tests = [
            {"scenario": f"submariner-fbc-{kind}-{version}", "status": "TestPassed"}
            for kind in ("standard", "operator")
        ]
        snapshot = {
            "metadata": {
                "name": app + "-abc",
                "creationTimestamp": "2026-09-24T00:00:00Z",
                "labels": {
                    "pac.test.appstudio.openshift.io/event-type": "push",
                    "appstudio.openshift.io/build-pipelinerun": "build",
                },
                "annotations": {
                    "test.appstudio.openshift.io/status": json.dumps(tests)
                },
            },
            "spec": {
                "application": app,
                "components": [
                    {
                        "name": app,
                        "containerImage": f"quay.io/redhat-user-workloads/submariner-tenant/{app}@sha256:"
                        + "b" * 64,
                        "source": {
                            "git": {
                                "revision": commit,
                                "url": "https://github.com/stolostron/submariner-operator-fbc",
                            }
                        },
                    }
                ],
            },
        }
        architectures = ["amd64", "arm64", "ppc64le", "s390x"]

        resources = {
            (obj["kind"].lower(), obj["metadata"]["name"]): obj
            for obj in json.loads(
                (ROOT / "scripts/tests/fixtures/ocp5-tenant.json").read_text()
            )
        }
        build = {
            "metadata": {
                "labels": {
                    f"appstudio.openshift.io/{key}": app
                    for key in ("application", "component")
                },
                "annotations": {
                    "pipelinesascode.tekton.dev/event-type": "push",
                    "build.appstudio.redhat.com/target_branch": "main",
                },
            },
            "spec": {
                "params": [
                    {"name": "revision", "value": commit},
                    {
                        "name": "git-url",
                        "value": "https://github.com/stolostron/submariner-operator-fbc",
                    },
                    {"name": "build-platforms", "value": mod.PLATFORMS},
                ]
            },
            "status": {
                "conditions": [{"type": "Succeeded", "status": "True"}],
                "results": [
                    {"name": "IMAGE_DIGEST", "value": "sha256:" + "b" * 64},
                    {
                        "name": "IMAGE_URL",
                        "value": f"quay.io/redhat-user-workloads/submariner-tenant/{app}:tag",
                    },
                ],
            },
        }

        def fake_run(*args, **kwargs):
            if args[:3] == ("oc", "get", "secret"):
                self.assertEqual(args[-2:], ("-o", "name"))
                return "secret/image-push"
            if args[0] == "skopeo":
                if "@sha256:" + "b" * 64 in args[-1]:
                    return json.dumps(
                        {
                            "manifests": [
                                {
                                    "digest": "sha256:" + str(i) * 64,
                                    "platform": {"architecture": arch, "os": "linux"},
                                }
                                for i, arch in enumerate(architectures)
                            ]
                        }
                    )
                return json.dumps(
                    {"annotations": {"org.opencontainers.image.base.name": base}}
                )
            kind, name = args[2:4]
            if kind == "snapshots":
                return json.dumps({"items": [snapshot]})
            if kind == "pipelinerun":
                return json.dumps(build)
            if kind == "serviceaccount":
                return "{}"
            data = resources[kind, name]
            if kind == "releaseplan":
                env = "stage" if "stage" in name else "prod"
                data["status"] = {
                    "releasePlanAdmission": {
                        "active": True,
                        "name": f"rhtap-releng-tenant/submariner-fbc-{env}",
                    },
                    "conditions": [{"type": "Matched", "status": "True"}],
                }
            return json.dumps(data)

        args = SimpleNamespace(ocp=version, expected_commit=commit)
        with patch.object(mod, "run", side_effect=fake_run):
            output = StringIO()
            with redirect_stdout(output):
                self.assertTrue(mod.verify_live(args, base))
            result = json.loads(output.getvalue())
            self.assertTrue(result["build_ready"])
            self.assertIn("unverified", result["runtime_on_requested_ocp"])
            for name, value in (
                ("IMAGE_DIGEST", "sha256:" + "c" * 64),
                ("IMAGE_URL", "quay.io/wrong:tag"),
            ):
                item = next(
                    item for item in build["status"]["results"] if item["name"] == name
                )
                original = item["value"]
                item["value"] = value
                with redirect_stdout(StringIO()):
                    self.assertFalse(mod.verify_live(args, base))
                item["value"] = original
            annotation = "build.appstudio.redhat.com/target_branch"
            build["metadata"]["annotations"][annotation] = "wrong"
            with redirect_stdout(StringIO()):
                self.assertFalse(mod.verify_live(args, base))
            build["metadata"]["annotations"][annotation] = "main"
            architectures.pop()
            with redirect_stdout(StringIO()):
                self.assertFalse(mod.verify_live(args, base))
            architectures.append("s390x")
            tests[0]["status"] = "BuildPLRInProgress"
            snapshot["metadata"]["annotations"][
                "test.appstudio.openshift.io/status"
            ] = json.dumps(tests)
            with redirect_stdout(StringIO()):
                self.assertFalse(mod.verify_live(args, base))

    def test_prod_index_uses_full_version_and_distinguishes_failure(self):
        executable = self.root / "oc"
        executable.write_text("""#!/bin/bash
printf '%s\n' "$3" > "$PROBE_LOG"
[ "${PROBE_FAIL:-}" != yes ] || exit 1
for arg in "$@"; do
  case "$arg" in /configs/submariner/bundles/:*)
    directory=${arg#*:}
    [ "${PROBE_ABSENT:-}" = yes ] || touch "$directory/bundle-v0.24.1.yaml" ;;
  esac
done
""")
        executable.chmod(0o755)
        environment = dict(
            os.environ,
            PATH=str(self.root) + ":" + os.environ["PATH"],
            PROBE_LOG=str(self.root / "image"),
        )
        command = f'source "{ROOT}/scripts/lib/prod-bundle.sh"; prod_index_has_bundle 5.0 0.24.1'
        for options, expected in [
            ({}, "present"),
            ({"PROBE_ABSENT": "yes"}, "absent"),
            ({"PROBE_FAIL": "yes"}, "unreachable"),
        ]:
            result = subprocess.run(
                ["bash", "-c", command],
                env=dict(environment, **options),
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(result.stdout.strip(), expected)
            self.assertTrue((self.root / "image").read_text().strip().endswith(":v5.0"))


if __name__ == "__main__":
    unittest.main()
