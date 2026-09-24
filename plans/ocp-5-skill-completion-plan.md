# Complete the reusable OCP onboarding skill

Plan revised 2026-09-24. Deliver the existing **`add-fbc-ocp-version` skill** so it
can add a new Submariner FBC OCP major/minor version, with **5.0 as the real first
application**. Keep one skill, its wrapper, the existing Python helper, and one
canonical workflow. Extend the tested foundation rather than build new orchestration.

## What the finished skill must do

For “add OCP X.Y”, use the known repository paths, independently selected source
commits, an approved minimum Submariner stream, and the appropriate OPM base.
Ask only for missing decisions that prevent the next action. A planning request
returns a read-only plan; an addition request continues through the authorized
preparation and validation phases rather than stopping after printing that plan.
The CLI can retain its read-only default. Preserve existing authorization to commit.

The result is a reviewable, repeatable change across the existing repositories:

| Area | Required output |
| --- | --- |
| Tenant | Registered overlay; Application, Component, ImageRepository, two ITS objects and two manual ReleasePlans |
| Admission | New application in the existing stage/prod RPAs, preserving approved policies and destinations |
| FBC | Correct drop-through map entry, populated rendered catalog, push/PR pipelines for the requested version |
| Validation | Correct source/bundle identities, target-base image test, required local checks, explicit live readiness |

Use full major/minor identities throughout. For 5.0 that means `5-0` resource/path
names and `registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0`.
An inclusive minimum of 0.24 maps to cutoff 0.23; **0.24 remains fixture data until
chosen as product policy**. Validate the actual base and supported stream rather
than assuming every syntactically valid future OCP version is available.

Keep source worktrees, unrelated staged/untracked edits, and existing PR work intact.
Reruns must produce identical artifacts or explain a conflict without overwriting it.
Tenant and admission changes remain separately reviewable. Report local preparation,
merged build, and actual installation separately; none implies production publication.

## Four implementation batches

### 1. Make the skill drive the complete workflow

Files: `skills/add-fbc-ocp-version/`, `scripts/fbc-onboard.py`, `Makefile`, and
`.agents/workflows/add-fbc-ocp-version.md`; keep the FBC workflow a short pointer.

- Interpret plan/add/resume requests and proceed to the requested milestone. Resolve
  both the executable and supporting workflow from the skill's verified backing
  checkout, including a copied/installed skill used outside this repository.
- Add independent release-data/FBC ref inputs; retain `--base` as a compatible
  shorthand with explicit conflict handling. Resolve and report immutable SHAs.
  Select overlay and pipeline predecessors independently from their own sources.
- Make configuration and catalog preparation depend only on their own repository.
  Keep workspace-only verification. Before writes, check tool versions/paths, source
  layouts, target conflicts, populated channels and the selected base's capabilities.
  Missing channels or an unsupported Kustomize must fail before mutation.
- Reuse current worktree/resume behavior. Give a concrete refresh/rebase or fresh
  workspace instruction on conflicts. Keep progress out of promised JSON output;
  distinguish unavailable remote information from confirmed absence.

**Done:** the skill works from the release repo, FBC repo and outside Git; independent
SHA pins and differing predecessors work; policy-free planning/configuration works;
an add request with sufficient inputs produces the change sets and validates them.

### 2. Close the demonstrated generation and validation gaps

Files: generation/validation functions in `scripts/fbc-onboard.py` and their existing
tests/fixtures. Make narrow FBC changes only where its existing build helpers need them.

- Always derive the retained minimum from `drop-versions.json`, including when
  `verify` omits the optional minimum. Check rendered package, channels, graph and
  bundle versions/digests against the selected source; keep real `opm validate`.
- Validate ITS package/context/resolver and complete RPA index/pipeline/account
  settings against the selected approved configuration. Preserve unrelated fields
  and comments. YAML edits must handle supported list layouts and validate the
  candidate before writing; errors must not leave previously valid YAML corrupted.
- Verify overlay registration and compare generated tenant objects with a fresh
  scratch render. Stale output must not hide source errors. Contain the repository
  builder's author injection so it cannot rewrite unrelated ReleasePlans on resume.
- Bound pipeline validation to the reviewed predecessor/template family. Preserve
  task structure except intended version changes; require enabled checks, correct
  source context, build-argument/platform forwarding and image-index/results wiring.
  Inspect a supported referenced definition; unknown/unresolved definitions remain
  unverified with a clear next action. Do not implement a general Tekton interpreter.
- Read the predecessor's actual OPM base argument rather than reconstructing its
  default tag. Reuse accepted overrides; carry the default-channel patch forward once.
- Keep existing full-ID, legacy-cutoff, trigger, expiry, rollback and source-preservation
  protections. Do not require new tasks or broad refactors to add another version.

**Done:** all demonstrated incorrect accepts below are rejected or explicitly
unverified, the real predecessor-derived pipelines/configuration pass, and reruns
preserve both valid artifacts and unrelated work.

### 3. Verify the requested version using existing build/release tools

Files: existing `verify_live`, snapshot helpers, onboarding workflow and E2E runner;
reuse FBC `make test-image` and the scoped FBC release verification commands.

- Invoke the image test with the **requested catalog and OCP base explicitly**.
  Bare `make test-image` currently tests 4.22/upstream OPM and cannot prove 5.0.
  Retain the required CI check context; change image CI narrowly if necessary to
  exercise the new target. A new matrix/runner framework is not a prerequisite.
- Strengthen existing live checks: actual RPA contracts or an explicit unknown when
  access is unavailable; correct account/secret bindings; expected commit on main;
  original push build/snapshot/image linkage; effective build args; actual catalog
  contents and all four platform manifests with compatible base annotations.
  Reuse the existing release verifier's provenance/content checks where applicable.
  Do not accept a PR retest as a push build or pending tests as passed tests.
- Use existing GitHub commands to identify/adapt the actual bot PR or select the
  manual pipeline path. Check the current head against effective rulesets as well
  as legacy protection, including required app identities. A protection-endpoint
  404 alone does not mean no checks. Keep this a bounded workflow/helper check.
- Reuse the existing install/QE path and inspect actual task execution, selected
  bundle/channel and observed cluster version. For 5.0, evaluate the upstream
  [0.3 install migration][install-migration] if the inherited 0.1 path cannot test
  5.0. Change only the new overlay as needed. The migration requires profile access
  and can still skip installation when no unreleased bundle is selected.

**Done:** the skill can demonstrate that the new version's artifacts and build are
correct, report missing live evidence honestly, and direct a concrete install/QE
check. A no-op install or a 4.x cluster never establishes OCP 5 runtime support.

### 4. Prove reuse, then perform the real 5.0 onboarding

Files: `scripts/tests/test_fbc_*.py`, `scripts/tests/e2e_fbc_onboarding.py`, skill and
workflow instructions; then the real tenant/admission/catalog change sets.

- Extend the existing disposable E2E to enter through the packaged skill wrapper
  and exercise the documented complete sequence. Include synthetic 4.23, 5.0 and
  5.1 cases so another minor/major does not require a skill rewrite. Future-version
  fixtures test generation; they do not assert registry or product availability.
- For 5.0, use real Kustomize and OPM, explicit target-base image validation and
  gRPC serving, rerun byte comparison, source/index preservation and conflicting
  minimum rejection. Compare index contents, not only Git status. Update existing
  fixtures that currently bless unresolved/empty pipelines; add focused regressions.
- Finish the short skill's invocation, argument, next-action and failure guidance
  alongside the implementation. Validate skill metadata and check realistic plan,
  add and resume requests; metadata validation alone does not prove skill behavior.
- Run the real procedure below with the approved stream. Leave a concrete catalog
  and pipeline change, not just fixtures or a claim that tooling is ready.

**Done:** another OCP version follows the same skill and passes the reuse tests;
5.0 has real prepared changes. Mark it **onboarded** only after configuration
reconciles and the merged 5.0 build/snapshot/artifact checks pass. Track installation
and release status separately until their existing workflows supply the evidence.

## Required regression coverage

Cover the reproduced failures and acceptance cases below in the existing suite;
the detailed earlier audit remains in Git commit `15bf04b`.

| Case | Required result |
| --- | --- |
| Disabled checks, empty pipeline, wrong context, index disabled, unresolved reference | Reject or report unverified; never local-ready |
| Wrong ITS package/resolver; wrong RPA index/account | Reject; preserve approved configuration |
| Cutoff 0.99 with retained 0.24 bundles, no CLI minimum | Reject inconsistent artifacts |
| Shared SHA used across unrelated repos; unavailable 0.25 channel | Independent pins work; missing stream reported before writes |
| Copied skill with backing-checkout override | Executable and workflow both resolve |
| Valid indentless RPA list | Generate valid YAML; preserve input if preparation fails |
| Missing overlay registration or changed source with stale generated files | Reject; compare with real Kustomize output |
| Unrelated untracked ReleasePlan with missing author | Tenant preparation preserves its bytes and index |
| Unsupported Kustomize; predecessor with accepted OPM override | Reject before writes; valid overrides remain reusable |
| Plan/add/resume; dirty checkout; partial failure; conflicting resume | Complete requested phase with no unrelated file/index/branch loss |
| Synthetic 4.23 → 5.0 → 5.1 | Correct identities/base inputs/predecessors; byte-identical reruns |
| Wrong provenance/bundle/platform/base; skipped install or wrong cluster | Fail that claim; retain useful partial results |

Disposable probes passed three-version pipeline/admission generation and real
Kustomize generation of seven 5.1 tenant objects from 5.0. These exercise reuse,
not future-version availability. Extend E2E to the complete skill and real 5.0 image.

Run checks appropriate to each batch and commit as they pass. At completion run
release `make test` through the normal hook, skill validation, FBC validation/lint
and the relevant authenticated tests, the cross-repository E2E, and release-data's
required regeneration/tox checks. Keep any reproduced unrelated baseline failures
explicit; do not label the whole suite green while they remain.

## Real OCP 5.0 execution sequence

1. Resolve the approved minimum Submariner stream and initial install-test bundle.
   Check its compatibility declaration and template membership. An already released,
   approved bundle can be used without waiting for a new component snapshot.
   Invoke the existing bundle-update workflow only if a new/changed bundle is needed.
2. Use source commits containing the tested tooling; refresh release-data main when
   reachable and rebase the separate tenant/admission drafts. Run the skill to
   prepare/validate the real 5.0 map, catalog and pipeline pair with those source pins.
3. Review/publish the prepared changes under the execution task's authorization.
   Reconcile configuration before expecting PAC builds; use the bot PR if present
   or the validated manual pair. Verify exact-head checks and the merged main build.
4. Confirm the actual 5.0 catalog image, bundle contents, four architectures and
   required tests. Run an install/QE test on an observed 5.0.x cluster. If a generic
   unreleased-bundle ITS skips the chosen released bundle, use an explicit-bundle QE
   run rather than treating that skip as success.
5. Hand the exact snapshot to the existing scoped stage/prod release workflow.
   Require successful stage/QE evidence before promotion and public-index membership
   before advertising availability. Activate `5-0` in the default release scope
   only after those gates; keep ordinary 4.x behavior unchanged.

The support stream is still undecided. Previous reads found GitLab DNS unavailable
and no live 5.0 Application; recheck when executing. The 0.24 component snapshot
status discrepancy matters **if a bundle update is needed**, not as a universal
onboarding prerequisite. Local skill work can proceed independently of these gates.

## Scope and ready starting points

Keep broad PR-rule engines, durable evidence databases, generic runtime-verifier
frameworks, repository-wide ITS migrations, CI infrastructure redesign, production
promotion redesign and integration-controller repairs outside this completion.
Use existing procedures for those responsibilities; make a narrow supporting fix
only when the actual onboarding acceptance test demonstrates it is required.

Start with batch 1 in the prepared release worktree, then batch 2. Update tests and
skill guidance with each change; batch 3 reuses the strengthened contracts, and
batch 4 closes the end-to-end acceptance. No new worktrees or parallel implementations
are needed:

- `/home/dfarrell07/konflux/ocp-5-skill-work/release-management` — `ocp-5-skill-completion`.
- `/home/dfarrell07/konflux/ocp-5-skill-work/fbc-tooling` — `ocp-5-fbc-completion`, based on `8b6e990`.
- Existing configuration drafts: `ocp-5-work/tenant` at `ae77531d74` and
  `ocp-5-work/admission` at `82ff6f2fc5`, kept separate.

For local runs, prepend `/home/dfarrell07/konflux/ocp-5-work/bin` to `PATH`: its
Kustomize is the required 5.7.1; the current default binary is 5.6.0. The skill must
check the selected repository's tool requirements rather than rely on this path.

See [implementation status](ocp-5-implementation-status.md) for the completed
foundation and prior test records. This document is the remaining execution plan;
the implementations and the actual 5.0 rollout are still to be completed.

[install-migration]: https://github.com/konflux-ci/tekton-integration-catalog/blob/1251d2990cee3f562325b48fe3404bce4f8c857f/pipelines/deploy-fbc-operator/0.3/MIGRATION.md
