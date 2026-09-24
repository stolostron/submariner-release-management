# Add an OCP version to Submariner FBC

Use the existing `add-fbc-ocp-version` skill or `scripts/add-fbc-ocp-version.sh`.
It accepts full OCP identities such as `4.22`, `4-22`, `5.0`, and `5-0`.
Python 3 with PyYAML, Git, jq, yq, Kustomize, and the FBC build prerequisites are
required. Repository paths are explicit options, not assumptions about cwd.
For an installed skill, its wrapper's `--workflow` returns this document's path
in the verified `RELEASE_MANAGEMENT_REPO` checkout.

## Plan and inputs

```bash
./scripts/add-fbc-ocp-version.sh 5.0 --min-supported-sub 0.24
```

This command is read-only. The minimum is inclusive: `0.24` includes streams
0.24 and newer. `drop-versions.json` retains its existing exclusive semantics,
so the equivalent map entry is `"5.0": "0.23"`. A legacy positional `0.23`
remains a cutoff and emits a warning. If the supported stream is undecided,
omit it for planning and configuration; do not invent compatibility policy.

The plan reports the local base commits and explicitly does not claim remote
freshness. Fetch both repositories before preparation. A failed fetch blocks
claims of freshness; cached bases can still support a clearly identified draft.
Review the base-image tag and architectures with registry inspection. OCP 5.0
uses `registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0`; do not
change the RHEL generation merely because the OCP major changes.

Pin the repositories independently with `--release-data-ref` and `--fbc-ref`.
Both default to `origin/main`; `--base` is a shorthand only when the same ref name
works in both repositories. A shared commit SHA normally cannot. The plan reports
resolved SHAs, independently selected overlay/pipeline predecessors, and blockers.
Use `--overlay-previous`/`--pipeline-previous` only to select a reviewed predecessor.
Select the release-data-required Kustomize version with `--kustomize` if needed.

## Complete an add or resume request

After reviewing the plan and resolving the minimum stream, run the complete local
sequence with the same repository paths, immutable refs and workspace:

```bash
./scripts/add-fbc-ocp-version.sh 5.0 --min-supported-sub 0.24 \
  --release-data-ref <release-data-sha> --fbc-ref <fbc-sha> \
  --workspace /path/to/ocp-5-work --phase prepare
./scripts/add-fbc-ocp-version.sh 5.0 \
  --workspace /path/to/ocp-5-work --phase test-image
```

`prepare` runs configuration, catalog preparation and local verification. The image
phase explicitly selects the requested catalog and OCP base. Progress goes to stderr;
successful phases emit JSON on stdout. Run repository checks, review the three diffs,
and commit when authorized. An add request continues beyond a read-only plan.
Reruns use the same workspace/refs; a base mismatch requires reviewing and rebasing
the existing work or selecting a fresh workspace. No automated reset or overwrite.
The separate phases below remain useful when policy or a repository is unavailable.

## Prepare configuration

```bash
./scripts/add-fbc-ocp-version.sh 5.0 --phase prepare-config \
  --workspace /path/to/ocp-5-work \
  --release-data-repo /path/to/konflux-release-data
```

This creates separate `tenant` and `admission` worktrees. It never switches the
source checkout, deletes an existing branch, commits, pushes, or applies. Reruns
reuse only matching worktrees and validate existing output instead of overwriting
it. Choose a different workspace if an unrelated branch already exists.
This phase needs no FBC checkout or minimum Submariner stream.

The tenant change adds eight overlay files, registers the overlay, runs the
repository's `build-manifests.sh` for this tenant, and validates seven generated
resource identities and their application/image/test relationships. The new
operator ITS uses the package default channel, avoiding the nonexistent `stable`
channel. Both release plans retain manual release. Admissions add the application
to the existing stage/prod RPAs without changing shared policy or destinations.

Follow `konflux-release-data/AGENTS.md`: run `tox` and the tenant checks in the
appropriate worktrees, review CODEOWNERS coverage, and keep the tenant and managed
admission changes separately reviewable. Merge/reconcile configuration before
expecting service accounts, image-push secrets, PAC, or release-plan matching.
Confirm both live release plans match their admissions and retain autorelease off.

## Prepare catalog and pipelines

The FBC safety changes (isolated tests and staged builds) must be present in the
selected `--fbc-ref`. Use a populated supported stream already in the template.

```bash
SKIP_AUTH_TESTS=true ./scripts/add-fbc-ocp-version.sh 5.0 \
  --min-supported-sub 0.24 --phase prepare-catalog \
  --workspace /path/to/ocp-5-work
```

This phase needs no release-data checkout. It checks the selected base's four
platforms before creating worktrees. For the final validation run authenticated
FBC tests as well; explicitly skipped authentication tests are not evidence of access.

The `fbc` worktree contains the cutoff map, rendered catalog, and push/PR pipeline
pair, with all four build platforms, the exact catalog INPUT_DIR, matching
service account, event-specific tags/expiry, and both pipeline files in CEL
triggers. Generation validates a populated default channel and runs the FBC
checks. No fixed file/commit count is assumed.

PAC may create an onboarding PR, but this has failed for prior versions. Search
for an existing PR by component, branch, and contents; do not guess its title or
number. Either adapt that PR or use the helper's manual pipeline pair copied from
the preceding merged pipeline. Preserve `pipelineRef` versus `pipelineSpec`.
Do not overwrite an existing pipeline pair: validate it and reconcile differences.
Check a known catalog file through the GitHub contents API; directory responses
are arrays, not objects with a `.name` field.

## Verify evidence

`--phase verify --workspace ... --min-supported-sub ...` checks local artifacts.
It explicitly reports deployment, multiarch build, and runtime status as unverified.
After deployment, run the read-only live checks with the expected merged SHA:

```bash
./scripts/add-fbc-ocp-version.sh 5.0 --phase verify-live \
  --expected-commit <40-character-merged-commit>
```

This checks live resource relationships, matched admissions, completed snapshot
tests, the successful push build, all four image platforms, and base annotations.
It still reports runtime compatibility as unverified. For scoped release creation,
set `FBC_EXPECTED_COMMIT` to that merged SHA and pass `--ocp 5.0`.
For remote readiness, record distinct evidence:

- Configuration: live Application, Component, ImageRepository, both ITS objects,
  both matched ReleasePlans, service account, and image-push secret exist.
- PR: required checks exist and succeed for the exact current head SHA. Pending,
  skipped, cancelled, failed, and absent required checks are not success.
- Build: merged-main push PipelineRun succeeds for the expected commit; all four
  manifest platforms exist; each catalog image preserves the base-image annotation
  consumed by the deployed release-service filter; `opm validate /configs` and the
  gRPC health probe succeed using the OCP-specific base.
- Release: snapshot has the intended bundle digest and completed passing tests;
  source SHA matches the expected merged commit. Use `--ocp 5.0` for a scoped
  initial release. Prod must reuse the exact stage snapshot QE validated.
- Runtime: operator installation actually ran with the intended bundle/channel,
  and the provisioned cluster reports 5.0. A fallback 4.x cluster or no-op install
  does not establish OCP 5 support. Record QE evidence separately.

Only after readiness is established, add `5-0` to the active list in
`scripts/lib/fbc-scope.sh`. Syntax support alone must not activate release scope.
Use `get-fbc-urls.sh --prod-index` to verify bundle membership before advertising
public index URLs. Registry reachability and bundle-tag existence alone are
insufficient.

## Reproduce the onboarding E2E test

The runner uses disposable repositories and 0.24 as explicit test data. It reads
release-data from the selected Git ref, includes the FBC candidate's uncommitted
changes, and runs the actual CLI phases twice. It verifies source preservation,
byte-for-byte repeatability, seven tenant objects, both admissions, both pipelines,
real mixed-major catalog rendering, and image validation plus gRPC serving.
It also rejects a conflicting minimum and verifies without the source repos.
Registry access, Podman, Kustomize >=5.7.1, and FBC build prerequisites are needed.

```bash
python3 scripts/tests/e2e_fbc_onboarding.py \
  --release-data-repo /path/to/konflux-release-data \
  --fbc-repo /path/to/submariner-operator-fbc
```

Do not edit the two input repositories while this runs: the test checks their
complete file state afterward. Fixture commits and the temporary image are local
and disposable. This test does not establish supported Submariner stream policy
or operator compatibility on a running OCP 5 cluster.
