#!/usr/bin/env python3
"""Real Kustomize/OPM onboarding E2E; all writes and commits are disposable.

Run with --release-data-repo and --fbc-repo pointing to local inputs. Requires
Kustomize >=5.7.1, OPM build prerequisites, and registry access. The selected
release-data ref is read from Git; the FBC candidate includes uncommitted edits.
0.24 is test data, not an assertion of the product's OCP 5 support policy.
"""

import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "onboard", ROOT / "scripts/fbc-onboard.py"
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def run(*args, cwd=None, env=None):
    subprocess.run(args, cwd=cwd, env=env, check=True)


def fingerprint(root):
    """Include ignored candidate files too, except Git internals and Python caches."""
    result = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if ".git" in relative.parts or "__pycache__" in relative.parts:
            continue
        if path.is_file():
            result[str(relative)] = (
                path.stat().st_mode & 0o777,
                hashlib.sha256(path.read_bytes()).hexdigest(),
            )
    result["HEAD"] = mod.run("git", "rev-parse", "HEAD", cwd=root).strip()
    result["STATUS"] = mod.run("git", "status", "--porcelain=v1", cwd=root)
    result["INDEX"] = mod.run("git", "ls-files", "--stage", "-z", cwd=root)
    result["BRANCH"] = mod.run("git", "branch", "--show-current", cwd=root)
    return result


def initialize(root):
    run("git", "init", "-q", "-b", "main", cwd=root)
    run("git", "config", "user.name", "FBC E2E fixture", cwd=root)
    run("git", "config", "user.email", "fbc-e2e@localhost", cwd=root)
    run("git", "config", "commit.gpgsign", "false", cwd=root)
    run("git", "config", "core.hooksPath", "/dev/null", cwd=root)
    run("git", "add", "-f", ".", cwd=root)
    run("git", "commit", "-qm", "Disposable candidate baseline", cwd=root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-data-repo", type=Path, required=True)
    parser.add_argument("--release-data-ref", default="origin/main")
    parser.add_argument("--fbc-repo", type=Path, required=True)
    parser.add_argument("--kustomize", type=Path)
    args = parser.parse_args()
    sources = [args.release_data_repo.resolve(), args.fbc_repo.resolve()]
    before = [fingerprint(path) for path in sources]
    with tempfile.TemporaryDirectory(prefix="ocp5-onboarding-e2e-") as temporary:
        parent = Path(temporary)
        data, fbc, workspace = (parent / name for name in ("data", "catalog", "work"))
        data.mkdir()
        archive = subprocess.check_output(
            [
                "git",
                "archive",
                args.release_data_ref,
                str(mod.TENANT),
                "tenants-config/lib",
                "tenants-config/build-manifests.sh",
                "tenants-config/utils.sh",
                "tenants-config/ensure-releaseplan-authors.sh",
                str(mod.RPA),
            ],
            cwd=sources[0],
        )
        with tarfile.open(fileobj=io.BytesIO(archive)) as contents:
            contents.extractall(data, filter="data")
        shutil.copytree(
            sources[1],
            fbc,
            ignore=shutil.ignore_patterns(".git", "bin", ".catalog-build*"),
        )
        assert not (fbc / "bin").exists()
        for fixture in (data, fbc):
            (fixture / "index-preservation").write_text("original\n")
            initialize(fixture)
            (fixture / "index-preservation").write_text("staged input\n")
            run("git", "add", "index-preservation", cwd=fixture)
            (fixture / "index-preservation").write_text("unstaged input\n")
        installed = parent / "installed/add-fbc-ocp-version"
        shutil.copytree(ROOT / "skills/add-fbc-ocp-version", installed)
        wrapper = str(installed / "scripts/run.sh")
        # Both dirty input files and a plausible untracked predecessor must be ignored.
        (data / "untracked-input").write_text("preserve\n")
        (data / mod.OVERLAYS / "4-99-overlay").mkdir()
        (data / mod.OVERLAYS / "4-99-overlay/input").write_text("not committed\n")
        (fbc / "README.md").write_text("dirty source input: preserve\n")
        fixture_before = [fingerprint(path) for path in (data, fbc)]
        command = [
            wrapper,
            "5.0",
            "--min-supported-sub",
            "0.24",
            "--release-data-repo",
            str(data),
            "--fbc-repo",
            str(fbc),
            "--release-data-ref",
            mod.base_commit(data, "HEAD"),
            "--fbc-ref",
            mod.base_commit(fbc, "HEAD"),
            "--workspace",
            str(workspace),
        ]
        if args.kustomize:
            command += ["--kustomize", str(args.kustomize.resolve())]
        environment = dict(
            os.environ, SKIP_AUTH_TESTS="true", RELEASE_MANAGEMENT_REPO=str(ROOT)
        )
        workflow = subprocess.check_output(
            [wrapper, "--workflow"], cwd=parent, env=environment, text=True
        ).strip()
        assert Path(workflow).is_file() and Path(workflow).is_relative_to(ROOT)
        plan = json.loads(
            subprocess.check_output(command + ["--phase", "plan"], env=environment)
        )
        assert plan["previous"] == "4-22", plan
        result = json.loads(
            subprocess.check_output(
                command + ["--phase", "prepare"], cwd=parent, env=environment
            )
        )
        assert result["local_ready"] and result["prepared"] == [
            "tenant",
            "admission",
            "fbc",
        ]
        image_result = json.loads(
            subprocess.check_output(
                command + ["--phase", "test-image"], cwd=parent, env=environment
            )
        )
        assert (
            image_result["local_image_test"] == "passed"
            and image_result["catalog"] == "catalog-5-0"
        )
        # Resume must not let the tenant builder edit unrelated authors or let the
        # catalog renderer replace unrelated staged/unstaged catalog changes.
        unrelated = (
            workspace
            / "tenant/tenants-config/cluster/kflux-prd-rh02/tenants/e2e-unrelated/release-plan.yaml"
        )
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text(
            'kind: ReleasePlan\nmetadata:\n  name: unrelated\n  labels:\n    release.appstudio.openshift.io/standing-attribution: "true"\n'
        )
        catalog_input = workspace / "fbc/catalog-4-22/package.yaml"
        catalog_input.write_text(
            catalog_input.read_text() + "# unrelated staged change\n"
        )
        run("git", "add", "catalog-4-22/package.yaml", cwd=workspace / "fbc")
        catalog_input.write_text(
            catalog_input.read_text() + "# unrelated unstaged change\n"
        )
        candidate_before = [
            fingerprint(workspace / name) for name in ("tenant", "admission", "fbc")
        ]
        # Resume every phase, verifying byte-for-byte idempotency and no new commits.
        for phase in ("prepare", "verify"):
            run(*command, "--phase", phase, env=environment)
        assert candidate_before == [
            fingerprint(workspace / name) for name in ("tenant", "admission", "fbc")
        ]
        assert fixture_before == [fingerprint(path) for path in (data, fbc)]
        # A conflicting policy cannot silently change an existing catalog.
        wrong = list(command)
        wrong[wrong.index("0.24")] = "0.25"
        result = subprocess.run(wrong + ["--phase", "prepare-catalog"], env=environment)
        assert result.returncode != 0
        assert candidate_before == [
            fingerprint(workspace / name) for name in ("tenant", "admission", "fbc")
        ]
        # Verification does not need the original source checkout options.
        verify = [
            wrapper,
            "5.0",
            "--phase",
            "verify",
            "--workspace",
            str(workspace),
            "--min-supported-sub",
            "0.24",
            "--fbc-repo",
            "/does-not-exist",
            "--release-data-repo",
            "/does-not-exist",
        ]
        if args.kustomize:
            verify += ["--kustomize", str(args.kustomize.resolve())]
        run(*verify, env=environment)
        # Synthetic future-version cases exercise reuse without asserting that
        # those registry images or product support policies exist.
        generic_data, generic_fbc = parent / "generic-data", parent / "generic-fbc"
        shutil.copytree(data, generic_data, ignore=shutil.ignore_patterns(".git"))
        shutil.copytree(fbc, generic_fbc, ignore=shutil.ignore_patterns(".git"))
        previous = "4-22"
        for version in ("4-23", "5-0", "5-1"):
            base = f"registry.redhat.io/openshift{version.split('-')[0]}/ose-operator-registry-rhel9:v{version.replace('-', '.')}"
            mod.prepare_tenant(generic_data, version, previous, args.kustomize)
            mod.prepare_rpas(generic_data, version)
            mod.pipelines(generic_fbc, version, previous, base)
            files = list(
                (generic_data / mod.OVERLAYS / f"{version}-overlay").glob("*.yaml")
            )
            files += list((generic_data / mod.RPA).glob("*.yaml"))
            files += list((generic_fbc / ".tekton").glob(f"*{version}*.yaml"))
            generated = {path: path.read_bytes() for path in files}
            mod.prepare_tenant(generic_data, version, previous, args.kustomize)
            mod.prepare_rpas(generic_data, version)
            mod.pipelines(generic_fbc, version, previous, base)
            assert generated == {path: path.read_bytes() for path in files}
            assert len(mod.validate_tenant(generic_data, version, args.kustomize)) == 7
            previous = version
        assert before == [fingerprint(path) for path in sources]
    print(
        "PASS: installed skill, complete preparation/image phases, seven tenant resources, two RPAs, mixed-major catalogs,"
    )
    print(
        "pipeline pair, repeatability, conflicting-policy rejection, source/index preservation, and 4.23/5.0/5.1 reuse."
    )


if __name__ == "__main__":
    main()
