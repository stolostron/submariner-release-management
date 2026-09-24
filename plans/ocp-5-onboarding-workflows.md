# Making OCP version onboarding reliable across the skill and workflows

Historical design for the pre-implementation baseline. The proposed interfaces
and reported failures below are not the current implementation contract. Use the
[implementation status](ocp-5-implementation-status.md) and the
[skill completion plan](ocp-5-skill-completion-plan.md) for the current state and next steps.

Follow-up investigation, 2026-09-24. This focuses on making the existing onboarding entry points dependable for
OCP 5.0, including failure, retry, and verification behavior. The broader image/build/release findings are in
[OCP 5.0 FBC support](ocp-5-fbc-support.md).

The recommendation is to retain `/add-fbc-ocp-version` as the user-facing entry point and make it coordinate
testable preparation and verification commands. The two workflow documents should explain those commands and
their handoffs, rather than carry independent implementations of version handling and catalog editing.

Updating the examples and accepting `5.0` in one regex would leave several independently reproduced failures.
The highest-priority prerequisite is test isolation: the documented FBC validation sequence can erase the change
it is supposed to validate.

This is an investigation and proposed implementation contract. The interfaces below are not implemented.
Only plan documents were changed in the working repositories. Experiments and Git commits used disposable fixtures.

## Confirmed additional failures

| Area | Reproduction result | Consequence |
| --- | --- | --- |
| Skill from the FBC repo | Reports the orchestrator script is missing | Skill depends on the caller's working directory |
| Skill outside a Git repo | Exits 128 with no diagnostic | `set -e` prevents the intended friendly error |
| Invalid `5.0` argument | Switches a fixture's user branch to `main`, then rejects input | Validation occurs after Git mutations |
| Existing onboarding branch | Replaces a branch containing a unique commit | Re-running can discard existing branch work |
| Manifest builder fails | Leaves one new commit and a partial overlay | “Verifies before committing” is not true for the complete change |
| Seven malformed generated YAMLs | Script exits successfully and creates three commits | File counts do not validate resources |
| Extra third argument | Accepted and ignored | Misspelled or unsupported options can appear to work |
| Remote branch query fails | Treated as branch absence; processing continues | Network/auth failure becomes “not found” |
| Untracked generated-directory work | Passes preflight; output replacement deletes it | Tracked-only cleanliness check is inadequate |
| FBC test reset | Removes new `catalog-5-0/` and restores template/mirror edits | Documented build → test → commit order loses inputs |
| Invalid 5.0 catalog | `test-build.sh` returns success; direct `opm validate` fails | Test discovery still checks only 4.x |
| Earlier catalog invalid, last valid | `make validate-catalogs` exits successfully | Loop masks an earlier failure |
| Only a 5.0 template present | Renderer exits before trying to render it | Empty legacy-template group is treated as a shell failure |
| Transient rendering failure | Retry diagnostic appears in redirected YAML output | Successful retry can leave polluted catalog data |
| Ordinary custom worktree name | Generator rejects the directory name | Directory basename checks obstruct isolated worktrees |
| GitHub directory check | `gh api .../contents/catalog-4-22 --jq '.name'` errors | Contents API returns an array for directories |

Evidence boundaries:

- The onboarding harness executed a copy of the actual script with only its hardcoded repository path redirected.
  It used actual copied overlay/RPA inputs, disposable Git repositories, and a controlled manifest-builder fixture.
  Fault injection established what the orchestrator detects; it did not assert that real Kustomize emits malformed YAML.
- The untracked-file case modeled the real `build-single.sh` behavior of deleting its generated output directory.
- FBC reset and `test-build.sh` ran directly in a disposable local clone; the invalid catalog was checked with real OPM.
- The Makefile failure-propagation probe used the real recipe with a deterministic OPM stand-in.
- The retry probe executed the actual retry function with a fail-once renderer and disabled fixture sleeps.
- These are regression requirements for a future fix, not a claim that the current implementation passed them.

## The bot handoff already failed in the previous onboarding

[The merged 4.22 onboarding PR][ocp422-pr] explicitly records that tenant configuration was already merged but
the bot never created the expected pipeline PR. The pipelines were copied from 4.21 and updated manually.
The branch was `add-ocp-4-22-support`, not the workflow's assumed `konflux-submariner-fbc-4-22`.

Therefore “wait for the bot branch, then require exactly two commits” is not a valid universal workflow.
The normal bot path should remain supported, but absence of that PR needs a documented, verifiable fallback.
Manual preparation of pipeline files does not replace Component, ImageRepository, service-account, or PaC onboarding.

## One entry point, explicit phases, evidence-based completion

Keep the existing skill name. Proposed phases:

| Phase | Responsibility | Completion evidence |
| --- | --- | --- |
| `plan` | Resolve repositories, revisions, versions, image, and current state | Proposed inputs, changes, and missing prerequisites |
| `config` | Prepare tenant overlay, generated resources, and RPA changes | Validated, scoped diff in an isolated checkout |
| `catalog` | Prepare a bot/manual PR's catalog and PipelineRuns | Valid catalog and pipeline parameters, with isolated tests |
| `verify` | Inspect repository, cluster, and registry state after handoffs | Separate configured/build-ready/release-ready results |

An example of the proposed interface, assuming 0.25 has independently been selected as the first supported stream:

```bash
scripts/add-fbc-ocp-version.sh 5.0 --min-submariner 0.25 --phase plan
make add-fbc-ocp-version OCP_VERSION=5.0 MIN_SUPPORTED_SUB=0.25 PHASE=plan
```

The example is not a support decision. The current catalog template has no 0.25 bundle, which `plan` should report.
That can allow infrastructure preparation while accurately marking catalog/build readiness as pending.

Useful explicit inputs are repository overrides, `--from 4.22`, an OPM image override, and a PR number for the
catalog phase. Resolve defaults from known merged configuration and validate them. Do not introduce a new tracker
database: determine resumable state from the actual files, Git refs, PR head, and cluster resources.

The skill should resolve the backing script from its installed package or an explicit verified release-management
checkout, rather than assuming the current Git repository owns it. It should remain a thin adapter: argument
description, phase selection, invocation, result interpretation, and the next concrete handoff.

Preparation should produce reviewable changes without automatic commits by default. This also matches the
current `konflux-release-data/AGENTS.md` instruction to commit only when requested. Existing authorization can
cover later commit/publish steps; the workflow should not add repeated confirmation prompts.

Push, MR/PR creation, merge, and release application remain distinguishable actions, so an exploration or a request
to prepare changes does not accidentally publish or release. No blanket new approval requirement is proposed.

## Input semantics must be unambiguous

### OCP IDs

Use complete IDs internally (`4-22`, `5-0`) and convert only at the boundaries:

- CLI: accept `5.0` or `5-0`, require an explicit minor, reject malformed/trailing/unknown arguments.
- Resource/path ID: `5-0`.
- Display/map key: `5.0`.
- Registry tag: `v5.0`.

Sort numerically by major and minor or with a validated version-aware sort. Use a predecessor below the target
or a validated explicit `--from`; adding 4.23 after 5.0 must not select 5.0 automatically.
Keep syntax support separate from activating a version in ongoing releases.

### Submariner minimum versus cutoff

The current positional second argument and Makefile `MIN_SUB` are historically passed directly into a map that
drops that Submariner stream. Silently changing their interpretation would break existing invocations.

Recommended compatibility contract:

1. Introduce an explicitly inclusive named input such as `--min-submariner` / `MIN_SUPPORTED_SUB`.
2. Retain the existing positional argument/`MIN_SUB` temporarily with a deprecation message explaining that it
   is the legacy excluded-stream cutoff, or reject it with a migration instruction. Never silently reinterpret it.
3. Preserve existing `drop-versions.json` semantics for this change. Translate a supported `0.N` minimum to the
   preceding excluded stream, validate the range, and report both values. Do not invent behavior for unsupported boundaries.
4. Reject simultaneous inclusive and legacy cutoff inputs. Validate that the resulting target catalog is nonempty
   before declaring catalog preparation complete.

Example: inclusive minimum 0.24 maps to cutoff 0.23; inclusive minimum 0.25 maps to cutoff 0.24. A cutoff value
is not proof that the required channel or bundle exists. Migrating the map itself to inclusive minima should be
a separate change with equivalence checks for every existing catalog.

### Base image

For 5.0, use the already verified image:

```text
registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0
```

Validate the actual image and required platform manifests. Do not mechanically derive image repository paths
for future major versions from this example. An explicit, verified mapping/override is safer than assuming all
future OpenShift major versions retain the same naming or RHEL base.

## Make configuration preparation safe to repeat

The present script needs a phased refactor rather than another series of textual substitutions:

1. Parse and validate all arguments before Git operations. Locate the expected repositories and tools explicitly.
2. Read fresh base state for online preparation. Treat remote “no matching ref” separately from auth/network failures.
   An explicit offline plan may describe cached state; it must not claim remote uniqueness or deployment readiness.
3. Prepare in an isolated worktree so unrelated tracked/untracked work and the user's current branch remain intact.
   Reject conflicting changes in an existing preparation worktree; do not delete branches, reset, or stash user work.
4. If desired content already exists, compare its complete semantics and report a no-op. If partially prepared,
   finish missing owned pieces only. Existing-but-different values require a visible diff, not silent replacement.
5. Build and validate the entire intended change before creating any requested commits. Stage only reviewed paths.
6. Preserve distinct review/validation for tenant infrastructure and managed RPA configuration. The source repo
   explicitly treats these as different GitOps workflows, even when they are part of the same onboarding task.

Use YAML structure and exact membership checks for kustomizations and RPA application lists. Current `sed` insertion
can do nothing when its anchor is absent; an unescaped dotted version is also a regular expression, not a literal.
Test the desired resulting values rather than the presence of an arbitrary matching string somewhere in a file.

Expected semantic checks for the rendered new resources:

- Application and Component names/application references are `submariner-fbc-5-0` in `submariner-tenant`.
- Git source is the intended FBC repository/main; Dockerfile is `catalog.Dockerfile`.
- Component image, ImageRepository image, labels, ITS OCI ref, and push-secret reference agree.
- Stage/prod ReleasePlans reference the correct shared RPAs, target namespace, and application.
- Both ReleasePlans retain the intended manual release behavior (`auto-release: false`).
- Both RPAs contain exactly the intended additional application and preserve policies, packages, and index templates.
- Both expected IntegrationTestScenarios remain present; the operator test uses a channel that exists or resolves the default.
- There are no unresolved placeholders, stale source-version references in the new overlay, duplicate resources,
  or unrelated rendered changes.

Seven resources and eight source files are useful expectations for today's layout, not sufficient correctness tests.
Regenerate with the repo's current Kustomize/build scripts, then run its tenant and managed-config validation suites.
The current repo guidance additionally calls for `build-manifests.sh` and `tox`; a file-count check is no substitute.

## Give the FBC repo a real preparation helper

Add a helper such as `scripts/prepare-ocp-version.sh` in the FBC repo. That repo should own catalog pruning,
rendering, pipeline editing, and local image validation. The release-management entry point can invoke it with
the resolved inputs rather than duplicating its logic in a skill document.

The helper should work on either an identified bot PR or a normal feature branch based on current main:

1. Discover PRs using repository, target branch, changed files, and component identity. Use the actual PR number
   and head ref; do not assume a branch name, title, author alone, or number of commits proves identity.
2. If there is no bot PR, inspect real Component/PaC state. Use the established manual pipeline preparation path
   when appropriate, selecting a reviewed current pipeline source. Do not wait forever or invent missing credentials.
3. Add/update the map entry and render the intended catalog from the authoritative template. Require its package,
   channels, bundles, default channel, and graph to be valid. An offline copy can be an explicitly provisional
   artifact only when all inputs are available and verified; it cannot substitute for completed validation.
4. Modify `.spec.params` and metadata structurally. Support both inline `pipelineSpec` and `pipelineRef` documents;
   “insert text immediately before pipelineSpec” is not a durable interface.
5. Ensure one effective `INPUT_DIR` and `OPM_IMAGE`, correct output-image/service-account/component values,
   correct push/PR events, target branch, and all required path filters. Preserve unrelated pipeline parameters.
6. Preserve push versus PR image-tag/lifetime conventions and all four requested architectures. Verify target-base
   provenance in produced images, because release routing derives OCP from the base-image annotation.
7. Validate image mirror requirements and the documented 4096-byte mirror limit when including unreleased bundles.
   If the requested bundle is missing, report that dependency rather than synthesizing a bundle or silently borrowing another stream.
8. Validate in isolation and compare the candidate tree before/after testing. Re-running preparation should produce no further diff.

Use the same catalog/source-revision inputs for validation that will be reviewed. A pipeline copied from an older
branch needs current task/reference checks; changing only the OCP strings does not establish that it is current.

## Fix test isolation before trusting the onboarding workflow

The old FBC workflow says to generate the catalog, run `make validate-catalogs test`, and then stage/commit it.
The test suite invokes `reset-test-environment.sh`, which removes `catalog-*/` and restores files from `HEAD`.
In the reproduction this left a 5.0 map entry with no corresponding catalog, and erased template and mirror edits.
Some unit/integration helpers also replace or restore the catalog template directly in the working tree.

Preferred fix: run mutation-based tests inside a disposable snapshot of the candidate tree. Include its uncommitted
and new files. A plain worktree of `HEAD` is insufficient because it would test the old content instead of the proposal.
If legacy tests need Git restore semantics, create their baseline commit inside the disposable fixture only.
Move fixture setup/cleanup there and make the test runner own its lifecycle.

Also fix these independent test/build behaviors:

- Derive expected catalogs/templates from validated configuration, and assert every expected output exists.
  Merely globbing what is present cannot detect a missing 5.0 catalog.
- Include invalid 5.0 content in negative tests; fail if any catalog fails validation, regardless of order.
- Remove the exact directory-basename requirement. Resolve the repository root from the script location or an explicit root.
- Support empty old/new rendering groups without swallowing real discovery errors. A 5.0-only render should be valid input.
- Render each attempt into a fresh temporary file, send diagnostics to stderr, and only publish successful validated output.
  Redirecting logs to stderr alone does not remove partial output left by a failed first attempt.
- Generate into a clean staging area driven by current map keys; do not rediscover obsolete 5.x templates left from an earlier build.
- Preserve the previous catalog outputs on fetch/render/validation failure. `build/build.sh` currently deletes all catalogs first.
- Make image tests explicitly select the 5.0 catalog and the 5.0 production base. The existing first-directory/default-base test
  is not evidence of a successful 5.0 build.

This work improves existing 4.x reliability too. It is a prerequisite to a trustworthy OCP 5.0 onboarding command,
not a reason to rebuild or republish every existing catalog during the migration.

## Verify actual readiness at each handoff

Replace fixed sleeps and “a snapshot name exists” with repeatable read-only checks that identify the pending condition.
Polling should be bounded and resumable; a timeout should preserve progress and report the precise missing resource or check.

| Milestone | Required evidence |
| --- | --- |
| Config prepared | Semantic validation, expected scoped diff, repository checks pass |
| Config deployed | Exact new resources exist; both ReleasePlans match the intended active RPAs |
| PR prepared | Expected files/params, valid new catalog, tests cover the candidate tree, identified PR head |
| PR ready | Required checks for that exact head satisfy current policy; distinguish pending, skipped, and failed |
| Build ready | Successful main-source 5.0 snapshot and architecture outputs from the intended merged content |
| Release automation ready | Full-ID discovery, YAML generation, URLs, scope/status, and prod snapshot reuse work |
| Stage ready | Stage publication succeeded and produced the expected 5.0 catalog content |
| Tested on 5.0 | Install tasks ran, selected bundle/channel match, cluster version really is 5.0 |
| Prod ready | Required product/QE decisions met; promotion uses the exact tested stage snapshot |
| Published | Public 5.0 index contains the expected package/channel/bundle |

The live 4.22 ReleasePlans expose `Matched=True` and an active admission reference; use that kind of exact check
for 5.0 rather than merely confirming the ReleasePlan names exist.

For GitHub content, test a known file such as `catalog-5-0/package.yaml` at the intended ref, or parse the directory
array correctly. Use explicit PR numbers for checkout/checks and require relevant checks to exist; do not make success
depend on precisely two commits. Do not weaken EC policy to make a check green.

The earlier investigation established two independent install-test limitations: `CHANNEL_NAME=stable` does not
match the current versioned channels, and cluster selection can successfully fall back from 5.0 to 4.22.
Verify an actual installation and actual target-cluster version. If the shared ITS cannot establish this,
record a separate targeted QE run; no-op/skipped/fallback outcomes must not be labeled OCP 5 support.

These checks should report separate milestone states. A build-support request can finish at verified builds and
release-tool compatibility while clearly identifying unperformed runtime or publication work. Product support and
production publication are additional outcomes, not side effects of the onboarding skill.

## Exact documentation and code ownership

In release management:

- Refactor `scripts/add-fbc-ocp-version.sh` for validated inputs, configurable paths, safe preparation, and resume/verification behavior.
- Add focused onboarding tests and wire their Makefile/CI target.
- Implement the full-version helper and update its consumers listed in the broader support plan.
- Update `skills/add-fbc-ocp-version/SKILL.md` to describe the complete phased behavior and accurate input semantics.
- Replace the reversed order and manual minor-only loops in `.agents/workflows/add-fbc-ocp-version.md`.
- Update Makefile help/arguments, `.claude/SKILLS.md`, README/CLAUDE examples, and the incorrect cutoff explanation in
  `skills/learn-release/SKILL.md`. Keep examples tied to the implemented interface.

In the FBC repo:

- Add the preparation helper and a focused Makefile target; make `.agents/workflows/add-ocp-version.md` a thin operational guide.
- Fix candidate-tree test isolation, catalog enumeration, validation failure propagation, rendering retries/groups, and cleanup.
- Add explicit version/base-image selection to local image validation.
- Update README/CLAUDE links and related catalog-update workflows to use complete OCP versions.

In release data:

- Prepare the actual 5.0 overlay/generated/RPA changes only with resolved support inputs.
- Update the Submariner tenant onboarding section in `CLAUDE.md` to point to the maintained process and accurately
  distinguish tenant and managed configuration validation. Avoid retaining a third divergent shell recipe.

Do not combine these with unsolicited operator code rebases or product-support changes. Existing operator working
tree edits remain unrelated and untouched.

## Implementation batches and acceptance tests

Recommended order:

1. **FBC test/build reliability.** Fix destructive validation and false-success cases first; prove candidate inputs survive tests.
2. **Full OCP version handling.** Add a consistent representation and migrate all release consumers without activating 5.0 prematurely.
3. **Configuration preparation.** Safe isolated work, correct semantic checks, no partial commits, explicit remote-query errors.
4. **FBC preparation and verification.** Bot/manual paths, structural pipeline updates, actual 5.0 build coverage, resumability.
5. **Skill/workflow integration.** Document and exercise the implemented phases, then perform real 5.0 onboarding with agreed inputs.

The acceptance suite should cover:

- Both OCP input forms; malformed/extra options; unambiguous minimum/cutoff compatibility; paths containing spaces.
- Invocation from release management, FBC, outside Git, and an installed skill location.
- 4.22 → 5.0, 5.0 → 5.1, and late 4.23 when 5.0 already exists; explicit template selection.
- Dirty original worktrees; untracked generated files; preexisting branches with unique commits; no branch or work loss.
- Fresh preparation, unchanged rerun, interrupted preparation, conflicting partial state, and all network/ref-query failures.
- Missing YAML anchors, wrong resource kinds/references, duplicate RPA entries, malformed generated output, unrelated output changes.
- Bot PR present, bot PR missing with manual fallback, ambiguous PR matches, already-merged pipeline files, and changed PR heads.
- Inline and referenced pipelines, duplicate build arguments, incorrect base image, wrong catalog path, and incomplete path filters.
- Missing bundles, empty channels, invalid default channels/upgrade edges, and unchanged existing 4.x catalog semantics.
- Uncommitted target catalog/template/mirror edits survive test success and failure byte-for-byte.
- Invalid catalogs fail first/middle/last; a missing expected 5.0 catalog fails even if every present 4.x catalog is valid.
- 5.0-only rendering; retry after partial output; no stdout diagnostics in catalog data; stale-template removal; outputs survive failure.
- Identified main-source snapshot, all required architectures/tests, matched RPAs, real install, and actual 5.0 cluster.
- Versioned/legacy release records and exact stage-to-prod snapshot identity for the new major version.

No finite test suite can promise perfection, but these are concrete, observable criteria for dependable onboarding.
They address the failures actually found here rather than relying on successful-path examples alone.

## Evidence artifacts

The follow-up experiments are in `/tmp/ocp5-workflow-audit.i0ceLC/`:

- `probe-onboarding.py` and `onboarding-results.json`: seven onboarding failure/preflight cases.
- `reset/reset.log` and `reset/test-build.log`: destructive reset and omitted invalid 5.0 catalog.
- `fbc-extra-results.json`: isolated renderer, worktree-name, retry-output, and Makefile failure probes.
- `skill-wrapper-results.json`: invocation from the FBC repo and outside Git.
- Individual disposable repositories and logs preserve before/after evidence for review.

No original branch was switched or deleted, no original test reset was run, and no remote configuration was written.
Registry availability and local 5.0 image validation were established in the earlier support investigation; they
were not repeated here. The first supported Submariner stream and intended runtime/publication milestone remain
product decisions rather than assumptions embedded into a script.

[ocp422-pr]: https://github.com/stolostron/submariner-operator-fbc/pull/60
