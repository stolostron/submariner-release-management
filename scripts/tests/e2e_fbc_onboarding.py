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
            result[str(relative)] = hashlib.sha256(path.read_bytes()).hexdigest()
    result["HEAD"] = mod.run("git", "rev-parse", "HEAD", cwd=root).strip()
    result["STATUS"] = mod.run("git", "status", "--porcelain=v1", cwd=root)
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
        initialize(data)
        initialize(fbc)
        # Both dirty input files and a plausible untracked predecessor must be ignored.
        (data / "untracked-input").write_text("preserve\n")
        (data / mod.OVERLAYS / "4-99-overlay").mkdir()
        (data / mod.OVERLAYS / "4-99-overlay/input").write_text("not committed\n")
        (fbc / "README.md").write_text("dirty source input: preserve\n")
        fixture_before = [fingerprint(path) for path in (data, fbc)]
        command = [
            str(ROOT / "scripts/add-fbc-ocp-version.sh"),
            "5.0",
            "--min-supported-sub",
            "0.24",
            "--release-data-repo",
            str(data),
            "--fbc-repo",
            str(fbc),
            "--base",
            "HEAD",
            "--workspace",
            str(workspace),
        ]
        environment = dict(os.environ, SKIP_AUTH_TESTS="true")
        plan = json.loads(
            subprocess.check_output(command + ["--phase", "plan"], env=environment)
        )
        assert plan["previous"] == "4-22", plan
        for phase in ("prepare-config", "prepare-catalog", "verify"):
            run(*command, "--phase", phase, env=environment)
        image = f"localhost/submariner-fbc-e2e:{parent.name}"
        try:
            run(
                "make",
                "test-image",
                "CATALOG=catalog-5-0",
                f"IMG={image}",
                "OPM_IMAGE=registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0",
                cwd=workspace / "fbc",
            )
        finally:
            subprocess.run(["podman", "rmi", image], check=False)
        candidate_before = [
            fingerprint(workspace / name) for name in ("tenant", "admission", "fbc")
        ]
        # Resume every phase, verifying byte-for-byte idempotency and no new commits.
        for phase in ("prepare-config", "prepare-catalog", "verify"):
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
        # Verification remains possible after the original source checkouts go away.
        run(
            str(ROOT / "scripts/add-fbc-ocp-version.sh"),
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
        )
        assert before == [fingerprint(path) for path in sources]
    print(
        "PASS: real onboarding CLI, seven tenant resources, two RPAs, mixed-major catalogs,"
    )
    print(
        "pipeline pair, repeatability, conflicting-policy rejection, source preservation."
    )


if __name__ == "__main__":
    main()
