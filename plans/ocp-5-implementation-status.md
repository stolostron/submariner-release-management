# OCP 5 FBC implementation status

Prepared 2026-09-24. Changes are committed locally and have not been pushed or applied.
The supported Submariner stream for the real OCP 5.0 catalog is still undecided.

## Review locations

| Change | Checkout |
| --- | --- |
| Release tooling, onboarding helper, skill, workflows, regression tests | `/home/dfarrell07/konflux/submariner-release-management` |
| FBC build/test safety and major-version support | `/home/dfarrell07/konflux/ocp-5-work/submariner-operator-fbc` |
| OCP 5.0 tenant overlay, generated resources, tenant instructions | `/home/dfarrell07/konflux/ocp-5-work/tenant` |
| Stage/prod admission application entries | `/home/dfarrell07/konflux/ocp-5-work/admission` |

The existing FBC Tekton feature branch and original release-data checkout were
preserved. FBC tooling is based on freshly fetched main
`b3bd5f3a449001e51d7d385a72f5d6f5cda4a7a1`. Configuration drafts use cached main
`8c18efee295889f5d86b03d16930a2f11977fd58`; fetching GitLab failed because
`gitlab.cee.redhat.com` could not resolve. Refresh/rebase those drafts before review.

Related local commits:

- FBC build/test workflows: `8b6e9909ae7219a543b7ffbaf431987c1292248d`.
- Tenant configuration: `ae77531d7496e7e20159fc63e08a051511f9f060`.
- Release admissions: `82ff6f2fc5fa0e109e8ef98840fb487a1986c889`.

## Implemented behavior

- Complete OCP IDs (`4-22`, `5-0`) propagate through release generation, scope,
  status, snapshot verification, production index checks, and Jira descriptions.
  Historical minor inputs remain accepted by the shared normalization helper.
- Modern records match the exact Submariner version; date matching applies only
  to legacy filenames. Prod reuses the exact version-matched stage snapshot.
- Onboarding defaults to a read-only plan. Preparation uses separate resumable
  worktrees; it does not switch checkouts, delete branches, commit, push, or apply.
- Inclusive `--min-supported-sub 0.24` maps to drop-through cutoff `0.23`.
  Legacy positional cutoffs retain their meaning and print a warning. Missing
  supported channels fail explicitly; cutoffs now remove every patch in a stream.
- Tenant generation validates seven resource identities and relationships, keeps
  autorelease off, and sets the new operator ITS to the package default channel.
  Stage and prod admissions retain their existing policies and index templates.
- FBC tests isolate candidate files, including uncommitted content. Reset refuses
  ordinary working checkouts. Builds stage and validate output before publication,
  preserve unrelated catalogs, and roll back published catalogs on failure.
- Rendering accepts arbitrary checkout names and 5-only catalog sets. Retry
  output cannot mix partial YAML or diagnostics into a successful render.
- Pipeline preparation validates both events, full identities, four architectures,
  OCP-specific base image, catalog input, CEL paths, service account, and PR policy.
- Release verification rejects absent, malformed, skipped, or pending test
  results and requires both standard and operator scenarios. Explicit expected
  commits pin catalog reads and snapshot selection.
- Live verification checks deployed configuration, matched admissions, successful
  expected-commit push builds, test completion, image architectures, and base
  annotations. It explicitly leaves actual OCP runtime compatibility unverified.

## Validation

Passed:

- Full release-management `make test`, plus focused checks after subsequent edits.
- Thirty offline onboarding/major-transition regression tests.
- Full authenticated FBC suite for the existing catalogs. A mixed 4.x/5.0
  candidate containing the new pipelines also passed its suite with
  authentication-dependent tests explicitly skipped.
- Existing catalog validation, ShellCheck, Ruff, Markdown lint, and skill validation.
- Real 5-only render/build using 0.24 as test data: default channel `stable-0.24`,
  bundles 0.24.0 and 0.24.1, `opm validate` successful.
- Native amd64 image built with the OCP 5.0 base; `/configs` validates and the gRPC
  service returns the expected Submariner package. The test owns and cleans up its
  container and random local port.
- Tenant generation and semantic checks; all Submariner manifests regenerate
  identically. After committing the tenant draft, the complete
  `tox -e tenants-config-test` passed with **60,108 tests**, including both
  static checks, full manifest regeneration, attribution, and onboarding checks.
- Live/public probes correctly report no deployed 5.0 application and no 0.24.1
  entry in the public OCP 5.0 index.

Release-data's `tenants-config-test` wrapper initially rejected the uncommitted
draft because it requires a clean checkout. The post-commit run passed all phases.
Both full repository `tox` runs completed. Main tests passed: **133,513** in the
tenant draft and **132,516** in the admission draft. Ruff, YAML lint, ShellCheck,
and CODEOWNERS checks passed in both. The only failing environment was `warnings`:
the existing Red Hat Desktop ITS references missing policy
`registry-red-hat-desktop-extensions-prod`. The same failure was reproduced on the
untouched original checkout; it was not changed as part of this work. Consequently,
full `tox` is not green, despite the affected checks passing.

## Remaining gates

1. Choose the first supported Submariner stream. The real FBC map and active
   release list do not yet include 5.0. The 0.24 catalogs above are test fixtures.
2. Restore GitLab connectivity, refresh the configuration bases, and review the
   local commits. Merge/reconcile tenant configuration and admissions.
3. Prepare the actual catalog/pipeline change from the chosen populated stream;
   required PR checks must pass at its exact head, followed by a merged push build
   with all four manifest architectures and the required base annotations.
4. Record operator installation and QE evidence on an actual OCP 5.0 cluster.
   Current integration tooling can fall back to 4.x or skip installation. A local
   image build or aggregate ITS pass cannot establish runtime compatibility.
5. Verify a scoped stage release, promote its exact QE-approved snapshot, confirm
   public-index membership, then activate `5-0` in the default release scope.

Use the [onboarding workflow](../.agents/workflows/add-fbc-ocp-version.md) and
[skill](../skills/add-fbc-ocp-version/SKILL.md) for the repeatable commands.

## Deep review follow-up

The second review found and fixed gaps missed by the original tests:

- Reject duplicate build arguments, incorrect service accounts, wrong/disabled
  event triggers, duplicate platforms, expiring push images (including inherited
  defaults), and semantic tenant configuration errors.
- Resolve predecessor overlays from the selected Git commit, ignore dirty input
  overlays, and reject resuming a worktree from an unrelated/newer base.
- Apply the same resource contract to local and live verification. Bind live
  build evidence to the correct application, component, repository, main-branch
  push, revision, and the snapshot's exact image digest. Release verification
  independently proves GitHub main ancestry and the original push-pipeline
  identity, including for retest events.
- Restore all catalogs after an interrupted publication, including a signal
  immediately after moving an original directory. Preserve recovery data if
  rollback itself fails. A build no longer rewrites its source template.
- Use Make's target directory (`CURDIR`) for tool installation. The previous
  inherited `PWD` could install OPM/grpcurl in the caller's unrelated checkout;
  the clean-tools E2E starts without binaries to exercise actual bootstrapping.
- Reject stale catalogs absent from the build map or conflicting with the
  requested minimum; require the Submariner package identity.
- Parse stage Releases structurally, checking their identity and release plan.
  Commit only generated releases, preserving unrelated staged changes.
- Read bundle-update snapshots once, select push events from labels, require
  completed passing results, and verify the image's exact `csv-version` before
  changing catalogs. Restrict bundle-update commits to configured catalog paths.
- Replace the obsolete live E2E fixture with the candidate template; assert every
  configured catalog exists and has the correct included/pruned bundle behavior.
- Clear repository-specific Git variables in the pre-commit test hook. Committing
  exposed inherited index paths breaking linked-worktree tests; a real partial
  commit regression checks worktree isolation and preserves unrelated staged edits.

The live E2E attempt was correctly blocked by snapshot
`submariner-0-24-20260922-114334-000-d7`: its status is `BuildPLRInProgress` while
its detail text says `Integration test passed with warnings`. No completed
`TestPassed`-only push snapshot was found in the tenant at review time. The
readiness checks do not infer success from that inconsistent text. The live
5.0 application is still absent, so no OCP 5 Konflux build or runtime pass is
claimed.

The actual 0.24.1 bundle inspected during review still carries
`com.redhat.openshift.versions=v4.15-v4.19`. This declaration needs an explicit
compatibility-policy decision and a rebuilt bundle as appropriate; it is not
changed automatically by catalog onboarding. The user's operator checkout was
left untouched.

### Review validation records

- Release-management full suite: `/tmp/ocp5-release-review-final-suite.log`.
- Twenty-nine focused Python tests: `/tmp/ocp5-review-unit.log`.
- Thirty focused Python tests including the commit-hook regression:
  `/tmp/ocp5-hook-regression-after.log`.
- Full release suite through the commit hook:
  `/tmp/ocp5-release-commit-validation.log`.
- FBC full suite including authenticated fetch (`SKIP_AUTH_TESTS=false`):
  `/tmp/ocp5-fbc-review-full-auth-suite.log`.
- Authenticated production-catalog fetch: `/tmp/ocp5-fbc-auth-final.log`;
  failed-test cleanup regression: `/tmp/ocp5-isolation-cleanup.log`.
- FBC ShellCheck and Markdown lint: `/tmp/ocp5-fbc-review-shellcheck.log` and
  `/tmp/ocp5-fbc-review-markdown.log`.
- Cross-repository CLI and image E2E: `/tmp/ocp5-onboarding-e2e-clean-tools.log`.
- Complete post-commit tenant validation:
  `/tmp/ocp5-tenant-postcommit-validation.log`.
- Live bundle-update E2E gate: `/tmp/ocp5-live-workflow-e2e.log` (blocked as above).
- Live OCP 5 readiness: `/tmp/ocp5-live-readiness-review.json` and `.log`
  (blocked by absent application).
- GitHub merged-main ancestry probe: `/tmp/ocp5-merged-main-check.log`.

The first CLI E2E run completed both onboarding passes and artifact checks but
correctly failed its final source-preservation assertion because review edits
were still being made to its FBC input. A later run built and served the image
successfully but exposed the Make `PWD` issue; it was interrupted during its repeat pass to correct that problem. The
final clean-tools run uses stable inputs, bootstraps tools inside its worktree,
and also builds/tests the OCP 5 image. Logs are local temporary evidence; the runner
is repository source for reproduction, not a promise of deployed state.

The previously skipped authenticated fetch test also found an obsolete checkout
basename restriction. Its full-index filesystem export exhausted `/tmp` during
review; package-only extraction avoids copying unrelated operator catalogs and
the large image cache. Test cleanup now handles read-only extracted directories
and preserves a failed child's exit status. Authenticated fetch checks the
package, bundles, and populated default channel, not just output-file existence.
The first cleanup/space failure was confined to disposable test directories.
The concurrent catalog render retried successfully after space was reclaimed.

The clean-tools onboarding E2E **passed**. It bootstrapped OPM and grpcurl inside
its worktree, prepared all three change sets, validated ten OCP catalogs (4.14
through 4.22 plus 5.0), built the OCP 5 image, validated `/configs`, served the
expected gRPC package, repeated the phases without artifact changes, rejected a
conflicting minimum, verified without source repositories, and proved both dirty
fixture inputs and original input repositories were preserved. The image,
container, and disposable repositories were cleaned up. The subsequent
package-fetch/cleanup fixes were validated separately and in the full FBC suite.
