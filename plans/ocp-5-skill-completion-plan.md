# Remaining work for correct OCP 5 onboarding

Audited 2026-09-24. Target: OCP **5.0**, using the existing
`add-fbc-ocp-version` skill. This is the execution plan after the first implementation
and its review, not a claim that the remaining behavior is implemented.

The foundation works for the exercised local preparation and image-build paths.
It is not yet sufficient to certify a new version as ready: this audit reproduced
additional false-positive validation cases and found missing operational handoffs.
Complete the local contracts first, then collect the distinct configuration, PR,
merged-build, installation, and release evidence described below.

This plan supersedes the unimplemented recommendations in the earlier
[investigation](ocp-5-fbc-support.md) and [workflow design](ocp-5-onboarding-workflows.md).
The [implementation status](ocp-5-implementation-status.md) records completed work
and historical test results. Keep that distinction when reading the older documents.

## Starting points and preserved work

| Change set | Local commit | Checkout |
| --- | --- | --- |
| Release tooling and skill | `4b26db8898e7d1b13e3e482feb24f25e72e5de39` | `submariner-release-management` |
| FBC build/test foundation | `8b6e9909ae7219a543b7ffbaf431987c1292248d` | `ocp-5-work/submariner-operator-fbc` |
| Tenant draft | `ae77531d7496e7e20159fc63e08a051511f9f060` | `ocp-5-work/tenant` |
| Admission draft | `82ff6f2fc5fa0e109e8ef98840fb487a1986c889` | `ocp-5-work/admission` |

Paths in this table are relative to `/home/dfarrell07/konflux`. These commits are
local; nothing has been pushed, merged remotely, applied, or released by this work.
The original FBC feature branch and the operator checkout must remain intact.
Continue making signed-off commits for coherent, tested changes, as requested.
The preparation helper itself should retain its default of leaving drafts uncommitted.

The next implementation checkouts are:

- `/home/dfarrell07/konflux/ocp-5-skill-work/release-management`, branch
  `ocp-5-skill-completion`, based on this plan's commit.
- `/home/dfarrell07/konflux/ocp-5-skill-work/fbc-tooling`, branch
  `ocp-5-fbc-completion`, based on `8b6e990`.

Keep tenant and managed-admission changes in their existing separate branches.
Refresh/rebase those drafts only after GitLab is reachable and new main is inspected.
Do not create the real catalog change from an arbitrary supported-stream assumption.

## Fresh observations

These are observations from this audit, not durable promises about remote state.

| Check | Observed result | Planning consequence |
| --- | --- | --- |
| FBC remote main | `b3bd5f3a449001e51d7d385a72f5d6f5cda4a7a1` | The local safety commit is still absent from main |
| GitLab release-data remote | DNS resolution fails | Cached main freshness remains unknown |
| Live `submariner-fbc-5-0` Application | NotFound | No deployed OCP 5 build/install evidence exists through this application |
| Open FBC PRs | One unrelated documentation PR, #76 | No existing OCP 5 onboarding PR was found in the returned open-PR list |
| OCP 5 operator-registry base | All four Linux architectures resolve | Base availability does not prove operator compatibility |
| Catalog template streams | `stable-0.17` through `stable-0.24`; no 0.25 | Selecting 0.25 requires bundle/template work first |
| Existing 0.24.1 bundle | OCP label `v4.15-v4.19` | Review compatibility and declarations before claiming 5.0 support |
| Component 0.24 push snapshots | 130 queried; none with all tests `TestPassed` | Live bundle-update E2E prerequisite remains unmet |
| Latest 0.24 push snapshot | Pending status despite completion detail | Diagnose the discrepancy; detail text cannot establish a pass |
| Legacy branch protection | HTTP 404, “Branch not protected” | Do not infer that required checks are absent |
| FBC effective branch rules | Ruleset `14555132` supplies seven required checks | Query effective rules as well as legacy protection |

The cached release-data base is `8c18efee295889f5d86b03d16930a2f11977fd58`.
The base image inspected was
`registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0`, with amd64, arm64,
ppc64le and s390x manifests. The 0.24.1 bundle inspected was
`registry.redhat.io/rhacm2/submariner-operator-bundle@sha256:a8bb318b8afa37daf2ce9394d80c46224e872b593934fbb68fd89e20e6665f84`.
The latest queried push snapshot, `submariner-0-24-20260922-114334-000-d7`, reports
`BuildPLRInProgress` alongside a completion time and passing-with-warnings detail.

The current required check contexts are `Image Build & Test`, `OPM Validation`,
`Shell Scripts`, `YAML Files`, `Unit & Integration`, `Documentation`, and `DCO`.
The rules bind the first six to GitHub App ID 15368 and DCO to App ID 1861, with
strict checks enabled. Discover them again for the actual PR; do not freeze this
list into a permanent substitute for repository policy.

The remote integration-catalog main is
`1251d2990cee3f562325b48fe3404bce4f8c857f`; the release-service `production` ref
is `155acaca6dff636f322238d5edbe60d22abaeb5c`.
Use those inspected revisions when reproducing this audit. Existing local
integration-catalog checkouts are at a different revision and were not modified.

## Confirmed gaps in the current implementation

The first ten cases below were exercised against the current validator functions
using disposable mutations. “Accepted” describes the validator's behavior, not a
valid deployment. The catalog case also passed real `opm validate`.

| ID | Reproduction | Current result | Required correction |
| --- | --- | --- | --- |
| C1 | Set pipeline `skip-checks=true` | Accepted | Require effective validation checks to execute |
| C2 | Reference a nonexistent named pipeline | Accepted | Resolve/trust the selected definition or report it unverified |
| C3 | Replace the inline definition with zero tasks | Accepted | Validate executable task/result wiring, not only top-level params |
| C4 | Set `path-context=other-source` | Accepted | Bind context, Dockerfile and catalog input to the intended source |
| C5 | Set `build-image-index=false` | Accepted | Require effective multiarch image-index production |
| C6 | Point operator ITS at an unrelated resolver URL/path | Accepted | Validate resolver identity, revision policy and pipeline contract |
| C7 | Set operator ITS `PACKAGE_NAME=other-package` | Accepted | Require the Submariner package and intended context/channel |
| C8 | Wrong stage index repository, correct version placeholder | Accepted | Validate the full approved index contract |
| C9 | Use an unrelated release service account | Accepted | Preserve the correct stage/prod account and pipeline settings |
| C10 | Cutoff 0.99, retained 0.24 artifacts, no CLI minimum | Accepted | Always validate retained streams against the map |
| C11 | Pin `--base` to FBC commit `8b6e990…` | SHA fails in release-data | Independently pin each repository |
| C12 | Plan minimum 0.25 against current template | Missing stream not reported | Report prerequisites during planning |
| C13 | Install skill alone with checkout override | Wrapper works; workflow link missing | Resolve docs through backing checkout |

Additional gaps established by tracing the executable paths:

- `verify_live()` reads ReleasePlan match status but never reads the actual RPA.
  It also does not prove expected-commit ancestry, read catalog contents, verify
  the requested bundle/channel, validate live build arguments, or inspect install
  TaskRuns. Runtime is honestly reported as unverified; the other proof gaps need
  equally explicit treatment before readiness is asserted.
- The live verifier only selects push-labeled snapshots, while release verification
  can accept verified retests of an original push. Define and test one consistent
  provenance policy; do not accept PR retests merely to make these paths agree.
- FBC image CI still runs bare `make test-image`, whose defaults select
  `catalog-4-22` and the upstream OPM image. A successful required image check
  therefore does not establish OCP 5 image coverage.
- No command checks PR identity and effective required checks at the current head,
  or produces a persistent evidence report for the complete handoff.
- The prod generator copies the exact stage YAML snapshot, but does not prove that
  the stage Release succeeded. QE tracker checks are advisory, while messages and
  commit text call the snapshots “QE-verified.” Retain offline preparation, but
  separate it clearly from permission/evidence to apply a production release.
- Historical plans describe already-fixed defects and obsolete proposed arguments
  without a clear current-status boundary. The banners added with this plan address
  that immediate navigation issue; the skill/workflow still need a complete pass.

## Completion contract

Keep readiness as separate, evidence-backed results. Preparation can succeed while
later results remain pending; an aggregate green result must not erase unknowns.

| Result | Required evidence |
| --- | --- |
| Plan complete | OCP ID, independent source SHAs, chosen/undecided minimum, prerequisites |
| Local configuration prepared | Reproducible manifests, approved resource contracts, repository checks |
| Local catalog prepared | Correct cutoff, bundles/graph, executable pipelines, source preservation |
| PR ready | Exact current head, effective required checks/apps, applicable OCP 5 PAC checks |
| Configuration reconciled | Live contracts, matched admissions, account/secret bindings |
| Merged build verified | Proven main commit, original push, exact snapshot/image, completed tests, four platforms/base provenance |
| Catalog artifact verified | Built package/bundle/channel match source; OCP-base validation and serving pass |
| Runtime verified | Actual install on observed 5.0.x; expected CSV/bundle and healthy operands |
| Stage verified | Successful named stage Release and resulting index, tied to that snapshot; appropriate QE evidence recorded |
| Production verified | Same approved stage snapshot, successful prod Release, expected bundle present in the public 5.0 index |

Reports should contain observation time, source refs, object names/UIDs where useful,
image digests, check/task identities, and an explicit passed/failed/pending/unknown
status per gate. Do not include credentials or kubeconfigs. A saved report is an
audit artifact, not a new state database or a replacement for checking current Git,
registry, PR, and cluster state. Expired/missing runtime records remain unknown.

## Implementation sequence and acceptance tests

### W1 — Independent inputs, preflight, and resumable preparation

Primary files: `scripts/fbc-onboard.py`, `scripts/add-fbc-ocp-version.sh`, `Makefile`,
`scripts/tests/test_fbc_onboarding.py`, `scripts/tests/test_fbc_review.py`.

Add separate release-data and FBC ref options. Keep the existing `--base` shorthand
only with documented precedence/conflict handling. Report both resolved SHAs.
Derive the tenant-overlay predecessor from the selected data ref and the pipeline
predecessor from the selected FBC ref; allow explicit overrides without conflating
them. A predecessor present in one repository need not exist in the other.

Resolve only the inputs needed by the requested phase. Configuration preparation
must work without the FBC checkout; catalog preparation must work without the
release-data checkout when its own predecessor/input contract is known. Preserve
workspace-only local verification and repository-free live verification.

Before mutation, check the required tools/versions, input files, populated stream,
base safety capability, and conflicts. Planning should report blocked prerequisites
without requiring authentication or a policy choice just to describe local work.
Remote freshness must remain unknown unless actually checked; never silently fetch,
switch branches, reuse the wrong base, or claim an old cached base is current.

For resumption, recompute repository ownership, branch, ancestry and artifact
contracts. Explain how to refresh/rebase a reviewed draft or select a fresh workspace
when upstream changes. Do not auto-reset an existing branch. Make JSON output
machine-readable on stdout and put tool progress on stderr where JSON is promised.

Acceptance: independent SHA pins; config without FBC; catalog without data;
different predecessors; nonexistent refs; moved base; dirty source; detached source;
same/unrelated worktree; partial preparation failure and retry; unsupported minimum;
missing/wrong Kustomize; no writes on plan failure. Existing full-ID/legacy-cutoff
and unrelated-staging protections must remain intact.

### W2 — Complete local catalog and configuration contracts

Primary files: `validate_catalog`, `validate_tenant_objects`, `validate_rpa`, their
fixtures/tests, and any narrowly needed FBC validation helpers.

Always validate map syntax and derive the retained minimum, even when verification
omits `--min-supported-sub`. Check the template-to-rendered relationship, channel
membership/default, bundle package/version/digest identity, pruning and upgrade
edges. Add explicit intended-bundle input for the first release where needed;
the minimum stream alone does not identify the artifact to release.

Validate ITS package, all expected contexts, resolver kind/URL/path/revision policy,
and relevant params. Validate complete stage/prod index references, pipeline revision,
service accounts and credentials references against the inspected approved source.
Preserve unrelated fields; derive values from merged configuration instead of
inventing new defaults. Do not make the shared validator permanently depend on
today's mutable `main` contents. Detect duplicate YAML mapping keys as well as
duplicate named parameters when loading contract-bearing files.

Acceptance: C6–C10 become rejected; valid predecessor-derived data still passes;
empty/default-missing channels, stale graphs, wrong package/digest, duplicate YAML
keys, conflicting source/generated resources and altered stage/prod destinations
fail specifically. Kustomize regeneration remains identical on rerun.

### W3 — Validate effective pipeline behavior

Primary files: `pipelines`, `validate_pipelines`, pipeline fixtures/tests; FBC
`.tekton` generation inputs where a concrete correction is necessary.

Resolve effective defaults, require checks enabled and image-index creation, and
bind the root source context to the Dockerfile/catalog. For inline pipelines,
check that clone revision, build args/platform matrix, output image/digest results,
validation tasks, and their conditions actually connect to the declared params.
Start with the merged pipeline family used by this repository; do not attempt an
unbounded general Tekton semantic interpreter.

For referenced pipelines, distinguish a recognized/resolved, revision-pinned
definition from an unknown named or mutable reference. Inspect the resolved content
before asserting readiness; retain a useful unverified result when it cannot be
resolved. Preserve valid inline/ref forms and bot customizations. Unknown execution
semantics must not pass solely because top-level params look correct.

Validate the base-image override against the actual deployed release-service version
extraction contract. Record its resolved digest while preserving a compatible
OCP-version-bearing base annotation; a blind switch to a digest-only annotation
can break release routing. This follows the [Konflux FBC target design][fbc-targets].

Acceptance: C1–C5 become rejected/unverified as appropriate; disabled `when`
conditions, dropped build-arg forwarding, wrong clone revision, wrong result wiring,
missing matrix and ambiguous defaults fail; the real current 4.22-derived pair
passes. Test a valid resolved reference and an unavailable/malformed reference.

### W4 — Bind live configuration, source, snapshot, and image evidence

Primary files: `verify_live`, `scripts/lib/fbc-snapshot.sh`,
`scripts/verify-fbc-release.sh`, live fixtures/tests.

Reuse the strengthened contracts for live objects and read the actual managed
RPAs when authorized. If access is unavailable, report admission contents as
unknown and identify the required owner evidence; match status alone is narrower
evidence. Check service-account/secret bindings without reading secret values.

Prove the supplied commit is an ancestor of canonical main. Bind original push
PipelineRun identity and UID, snapshot component/source, effective build params,
build results and pinned image to each other. Reconcile valid incoming/retest
handling with release verification. Allow explicit snapshot selection with all
the same checks so a rerun cannot silently switch away from reviewed evidence.

Inspect the published platform manifests and relevant config metadata, rejecting
duplicate/conflicting platform entries. Extract catalog data without executing
untrusted cross-architecture images; compare package, channel and bundle identities
to the source and requested artifact. Record OPM validation and native serving
evidence separately from metadata inspection. Keep build and runtime verdicts distinct.

Use bounded subprocess/network timeouts. Report useful per-gate errors for missing
tools, malformed API/registry responses, Forbidden, NotFound, expired credentials,
and network failures. Do not collapse these into absent artifacts or a successful
empty set. Collect independent findings without running dependent unsafe checks.

Acceptance: wrong live RPA, stale match status, unmerged commit, wrong original
pipeline, retested PR, mismatched bundle, wrong live build args, missing architecture,
wrong base annotation, malformed manifests, stale snapshot, no tests and pending
tests fail. Verified push retests pass without admitting PR retests. All failures
produce a structured partial report and a non-success readiness result.

### W5 — PR discovery and exact-head readiness

Add a read-only PR verification capability and expose it through the skill/workflow.
Accept an explicit PR identifier, or discover candidates by repository, component,
base and changed files. Multiple candidates require selection; a failed query is
unknown state. Never infer a bot PR number/title or overwrite an existing pair.

Read both effective branch rules and legacy protection. Query check runs and commit
statuses with pagination, bind names to required app identities, and evaluate the
current PR head. Do not accept old-head successes, a same-named check from another
app, or vacuous success when policy lookup fails. Keep required PR checks separate
from push-only installation/EC gates; some existing EC PR checks are neutral.

Acceptance: legacy protection 404 plus a valid ruleset; multiple rulesets; pagination;
head changes during inspection; required missing/pending/failed/cancelled/skipped
checks; conflicting check apps; ambiguous PRs; API failure; no bot PR and manual pair.
Do not change repository protection settings as part of adding this verifier.

### W6 — Make OCP 5 image coverage repeatable in CI

Primary repository: FBC. Files: `.github/workflows/test-image.yml`, `Makefile`,
`scripts/test-image.sh`, applicable catalog/build tests.

Make image coverage select catalog and base explicitly. Keep the stable required
`Image Build & Test` context through an aggregate job if a matrix is introduced;
ruleset changes must not be an accidental prerequisite. Exercise OCP 5 catalog
inputs, the production-style 5.0 base and gRPC serving. Gate catalog selection on
the actual map/artifacts; do not add a nonexistent catalog to ordinary main CI.

Registry-authenticated image checks need a runner/event strategy that works for
the relevant PRs. Never expose registry credentials to arbitrary fork code or
quietly skip the only 5.0 coverage while reporting a green aggregate. Use an
explicit pending/unsupported result and the authenticated Konflux path where needed.
The multiarch Konflux build remains separate from a native amd64 CI image test.

Acceptance: a deliberately broken 5.0 catalog/base fails the 5.0 test; an intact
4.22 build cannot mask it; one failed matrix entry fails the aggregate; cleanup
preserves the caller's files and removes only owned containers/images. Retest
authenticated fetch and staged publication if their code changes.

### W7 — Establish real installation evidence and update the OCP 5 ITS

Primary configuration: the 5.0 tenant overlay only. Avoid changing all older OCP
ITS objects to solve this onboarding task.

The current draft inherits `pipelines/deploy-fbc-operator/0.1/...`, using the
fallback-capable EaaS selector. Evaluate the upstream [0.3 migration][install-migration]
first. Its recommended entry point is
`pipelineruns/deploy-fbc-operator/0.2/deploy-fbc-operator-run.yaml`, which invokes
the 0.3 pipeline and supplies the shared-data PVC. The new [selector][pick-version]
returns the fragment's OCP version directly. Confirm tenant access to the required
OpenShift CI profile, registry secret key, service accounts, quotas and an available
5.0 payload before changing the overlay. Do not assume the upstream default profile
is usable by this tenant.

Migration is insufficient by itself: the new pipeline still conditions installation
on a push event and a nonempty unreleased bundle. An already-released 0.24.1 bundle
or a no-op test may not exercise installation. Select the exact intended bundle;
if the generic unreleased-bundle path cannot test it, use a scoped explicit-bundle
QE/install run on an approved 5.0 cluster and retain that evidence.

Implement read-only runtime-evidence verification: link ITS/test PipelineRun to the
snapshot/image, verify selected package/channel/bundle, completed install task and
successful exit, actual observed cluster `5.0.x`, installed CSV/InstallPlan and
operator readiness. Record the agreed Submariner QE checks, including operand health
and relevant cross-cluster connectivity/upgrade cases. A requested version or image
tag is not proof of the observed cluster version. Preserve evidence before TTL cleanup.

Acceptance fixtures: skipped/no-op install; empty selected bundle; wrong bundle;
4.x fallback; wrong cluster context; pending/failed task; expired records; genuine
5.0 installation. Exercise the actual authorized cluster path afterward. If upstream
task changes are necessary, follow that repository's task-versioning and positive/
negative functional-test requirements in an isolated checkout.

### W8 — Complete the skill and release handoffs

Primary files: `skills/add-fbc-ocp-version/SKILL.md`, its wrapper, canonical workflow,
FBC workflow, `.claude/SKILLS.md`, and the scoped create/check/release workflows.

Keep the skill short: interpret request/phase, resolve the backing checkout and
supporting instructions, invoke the helper, interpret evidence, and state the next
specific handoff. Resolve installed-skill documentation through the same verified
checkout as the script. Make the existing OCP 5 minimum examples unmistakably
examples, not a compatibility decision. Use only implemented flags in runnable docs.

Document the independently pinned sources, refresh/resume procedure, manual/bot
pipeline paths, dependency checks, expected failures, and the distinction between
local preparation and live gates. Preserve existing authorization: do not require
another approval for local fixes or requested commits; do not turn a planning
request into a push, merge, cluster provisioning, message, or Release apply.

Expose a read-only stage/prod evidence check or equivalent explicit handoff. Offline
prod YAML generation may remain available, but label it as prepared until the named
stage Release succeeded and QE evidence matches that exact snapshot. Remove claims
that copying a stage YAML proves QE approval. Keep publication/apply behind the
actual release workflow and existing authorization, not a newly invented blanket
confirmation rule. Propagate the explicit 5.0 scope through all handoffs.

Acceptance scenarios: invoke from this repo, FBC, unrelated repo, outside Git,
whole plugin checkout, and copied skill with an override; use paths with spaces;
missing/wrong backing checkout; no policy chosen; existing authorized commits;
failed network query; existing bot PR; local success with live failure; stage YAML
present but unapplied/failed; QE evidence for another snapshot; exact approved
stage-to-prod snapshot. Run skill metadata validation and realistic CLI/E2E paths.

### W9 — Close the coverage gaps and rerun the cross-repository E2E

Extend the existing disposable E2E rather than create a second divergent onboarding
implementation. It must exercise the supported skill entry point, independent pinned
refs, new contract failures, configuration generation, actual catalogs and image,
reruns and refresh conflicts. Capture the source/index/worktree state before/after.
Do not mutate fixture source inputs concurrently with this test.

Use 0.24 only as explicit fixture data while real support policy is undecided.
Add 5-only and mixed-major cases, retained 4.x behavior, valid referenced and inline
pipeline fixtures, installed-skill invocation, and the 30 existing regressions.
Mock API tests should cover the evidence contracts; they must not count as live
installation, publication, or platform build proof. Add focused Python checks to
the relevant CI path if not already covered by `make test`; explicitly provision
their dependencies instead of relying on incidental runner packages.

Final validation: release `make test` through the real commit hook; skill validation;
FBC catalog validation, relevant lint and authenticated suite; real CLI/image E2E;
tenant manifest rebuild and complete `tox -e tenants-config-test` after its commit;
full config `tox` in both branches. Preserve the separately reproduced baseline
Desktop-policy warning failure unless the refreshed base fixes it; do not call
full tox green while that environment fails. Run live checks once their prerequisites
are present and retain results distinct from offline passes.

## Dependencies and commit order

| Commit-sized milestone | Depends on | Can start now? |
| --- | --- | --- |
| W1: phase inputs/preflight | Existing foundation | Yes |
| W2: catalog/resource contracts | W1 input model | Yes, with disposable fixtures |
| W3: effective pipelines | W1 and inspected merged pipeline family | Yes |
| W4: live evidence | W2–W3 contracts | Offline development now; real 5.0 proof later |
| W5: PR readiness | W1 evidence/output conventions | Yes, read-only discovery and fixtures |
| W6: CI image coverage | W3 contract and registry execution strategy | Local tooling now; actual catalog CI after policy/preparation |
| W7: runtime verifier and ITS migration | W2, W4, approved cluster access | Verifier/fixtures now; overlay/runtime after access decisions |
| W8: skill and release handoffs | Landed interfaces from W1–W7 | Incrementally with each implemented interface |
| W9: final integrated verification | W1–W8 | Extend tests with each change; full run at completion |

Start with W1. Give each behavioral correction a failing regression before the fix,
then commit after the appropriate checks. Do not re-run expensive authenticated
or cluster tests for documentation-only edits unless a required hook mandates it.
Do not refactor unrelated release skills or migrate older tenants as collateral work.

## Real rollout after the tooling is ready

1. Resolve the first supported Submariner stream and initial exact bundle. Review
   its OCP declaration, actual compatibility and availability in the template.
   Update/rebuild the bundle only under the approved support decision; keep the
   operator user's existing checkout untouched by using an isolated worktree.
2. Publish/review the release-tooling and FBC foundation changes through their
   normal workflows when authorized. The catalog preparation base must contain
   the required safety and validation changes; cached upstream main currently does not.
3. Restore GitLab access, refresh both configuration branches, reconcile any drift,
   apply the validated 5.0 ITS choice, regenerate and rerun checks. Keep tenant
   and admission reviews separate. Merge/reconcile them through the normal GitOps flow.
4. Verify live configuration, service-account/secret bindings and admissions. Select
   an existing PAC PR if one now exists, otherwise prepare the validated manual pair.
   Generate the real map/catalog with the approved minimum and exact source pins.
5. Pass local and exact-head PR gates; merge the reviewed catalog change when
   authorized. Verify the merged push build, snapshot, platform images and actual
   catalog/bundle content. Investigate pending test status instead of bypassing it.
6. Create a scoped 5.0 stage release through the release workflow, verify its result,
   and obtain actual 5.0 installation/QE evidence. If build-time installation is
   available earlier, preserve it and link it to the same artifact; avoid circularly
   requiring a stage release before an ITS that is itself required to stage.
7. Prepare/promote the exact approved stage snapshot, verify prod completion and
   public-index bundle membership. Only then activate `5-0` in the default release
   scope and verify the ordinary release path includes it.

This pass prepares local work. Publication, cluster provisioning and Release
application are separate execution steps; use the authorization available for
those tasks without adding repeated confirmation requirements.

## Decisions and external evidence still needed

- **Support policy:** inclusive first stream and initial bundle version/digest.
  Asked during this planning pass; no answer is assumed. Fixture 0.24 is not approval.
- **Runtime route:** access to the 0.3 pipeline's OpenShift CI profile and usable
  5.0 payload, or an approved explicit-cluster QE route. Determine actual supported
  architectures/features from the product QE plan; four build manifests alone are
  not a promise of four-architecture runtime testing.
- **Release-data connectivity:** fresh merged main and current repository instructions.
- **Test status discrepancy:** trustworthy successful snapshot evidence or diagnosis
  and correction of the contradictory status; never a text-based bypass.
- **Release evidence:** real OCP 5 application, reviewed/merged catalog SHA, successful
  build/ITS records, installation/QE and stage/prod results. These do not yet exist.

## Safe starting commands

These commands use the current interface and are read-only. Proposed ref/verification
options above are future work and are intentionally not presented as runnable commands.

```bash
repo=/home/dfarrell07/konflux/submariner-release-management
"$repo/skills/add-fbc-ocp-version/scripts/run.sh" 5.0 --phase plan \
  --release-data-repo /home/dfarrell07/konflux/konflux-release-data \
  --fbc-repo /home/dfarrell07/konflux/ocp-5-work/submariner-operator-fbc

gh api repos/stolostron/submariner-operator-fbc/rules/branches/main
oc get application submariner-fbc-5-0 -n submariner-tenant -o name \
  --request-timeout=20s
```

Audit scratch evidence is at `/tmp/ocp5-skill-audit.p575v8jc/`: contract-probe
results, the current read-only plan, and the inspected upstream pipeline/selector
YAML. These temporary files are not durable test artifacts. The confirmed cases
and acceptance criteria above must become maintained regressions during implementation.

[fbc-targets]: https://konflux-ci.dev/architecture/ADR/0026-specifying-ocp-targets-for-fbc/
[install-migration]: https://github.com/konflux-ci/tekton-integration-catalog/blob/1251d2990cee3f562325b48fe3404bce4f8c857f/pipelines/deploy-fbc-operator/0.3/MIGRATION.md
[pick-version]: https://github.com/konflux-ci/tekton-integration-catalog/blob/1251d2990cee3f562325b48fe3404bce4f8c857f/stepactions/bundles/pick-cluster-version/0.2/pick-cluster-version.yaml
