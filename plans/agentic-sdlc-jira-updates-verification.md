<!-- markdownlint-disable MD013 -->

# Verification of the agentic-SDLC update plan

Read-only audit performed on 2026-10-06. This record distinguishes source checks from operations that still require execution preflight.
No Jira payload, transition, cluster change or release was applied during the audit.

## Public PR evidence

The audit fetched pull-request metadata for 347 unique PRs through GitHub's API, covering the three remediation lists and the initial epic-period search.

| Evidence | Verified result |
| --- | --- |
| Glasswing list | Exactly the same 113 URLs as the original local tracker; 105 merged, 8 open drafts; author, base branch and merge date match every row |
| CVE/revert list | 43 unique PRs: 26 merged, 17 closed without merging; 3 are lint-only reverts, leaving 40 CVE-fix PRs |
| EC/Tekton list | 33 unique PRs: 32 merged, 1 closed without merging |
| Initial epic-period inventory | 335 PRs across 12 repositories; 290 merged, 32 closed without merging, 13 open at the reconstructed cutoff |
| Full August 4–September 30 UTC search | 343 PRs across 14 repositories; this includes work created after the initial sweep and is a different population |

The [public inventory](agentic-sdlc-jira-updates-payloads/submariner-sustenance/epic-period-prs.json) records an explicit cutoff of
2026-09-30 at 05:00 UTC. It was reconstructed from an author/date search and each PR's creation, close and merge timestamps, not captured live at that time.
A second pass fetched complete close, reopen and merge timelines for all 335 entries. No entry has a reopen event; replaying the events at the cutoff
confirms every recorded state and the initial aggregate. Merge is terminal even when GitHub emits a close event at the same timestamp.
Theme membership is heuristic and recorded per entry; category counts were recomputed from those entries. A closed state does not establish a supersession reason.

The complete-file statistics and merge dates of [release-management PR #109](https://github.com/stolostron/submariner-release-management/pull/109)
and [PR #110](https://github.com/stolostron/submariner-release-management/pull/110) match the plan. Their published validation sections support the
reported onboarding E2E and live RPM lockfile run; those runs were not independently repeated by this documentation audit.
[cve-agent PR #35](https://github.com/dfarrell07/claude-skills/pull/35) is merged;
[release-management PR #114](https://github.com/stolostron/submariner-release-management/pull/114) and
[OCP 5 FBC PR #82](https://github.com/stolostron/submariner-operator-fbc/pull/82) remain open.

## Jira observations

Both epics and relevant existing stories and release trackers were read through the authenticated Jira CLI. The ACM epic still has its ten existing children;
the CORENET epic still has an empty description and no children. Existing story statuses, component 33720, Activity Type choices and priority ids match
the plan. The four old epic-description snippets and the insertion heading each match once in the rendered description.

The bounded Vulnerability JQL in A8 returned 259, matching the original unbounded query. No private issue export, teammate name or account id is published here.
The query now also includes `BY currentUser()`: all 259 were transitioned by the authenticated maintainer and are currently assigned to that account.

The active sprint observed on ACM siblings is now 2026-59 (87579); 2026-58 (85613) is closed. CORENET Sprint 295 (87581) remains active on its epic.
Descriptions, comments and the Git Pull Request field are ADF documents. The payloads now require an ADF-capable client and preserve existing rich-text links.
No create-field metadata or available-transition endpoint was exercised, so those remain mandatory preflight checks; numeric transition ids were removed.
The execution instructions now use each story's own field values, validate the Kubernetes canary before editing the epic, and require restricted comment visibility at creation and on read-back.

## Kubernetes rebase evidence

The inventory is pinned to fork branch bak42 at `febb7974696e870f933e8ad3741605d31ead0b5c`; a remote-ref read confirms that backup exists.
At that committed snapshot: 134 files, 20,792 lines, 32 gate documents, four design/compatibility documents, 13 shell/Python script files across
`scripts/` and `evals/scripts/`, 238 Python test functions in 4,939 Python test-file lines, and 16 pattern-retention evaluation case directories.
Hooks and gate scripts are outside that 13-script count.

Compared with [the upstream PR head](https://github.com/openshift-eng/ai-helpers/pull/617), bak42 adds 69 commits and changes 90 files (+7,799/-2,641).
The 43 local backup refs and a fresh remote-ref query confirming 29 fork backup refs match the recorded counts. Current local work is newer; it must not be described as entirely backed up by bak42.
GitHub confirms 108 closed July draft PRs with the stated repository distribution, six June rebase PRs with one merged, and 175 upstream review entries
(85 bot, 83 author, 7 teammate). The September 8 measurement question is an
[issue comment](https://github.com/openshift-eng/ai-helpers/pull/617#issuecomment-5587555534), not a code-review thread.
The [Kubernetes v1.37.1 release](https://github.com/kubernetes/kubernetes/releases/tag/v1.37.1) supports the plugin's patch-target claim;
it does not prove a consumer rebase passed.

## Execution gates and limits

* Read current Jira create-field, transition, resolution and link-type metadata before writing. Confirm story splits, acceptance criteria, points and sprint choices;
  then perform the canary create and rich-text update and read them back. Read-only observations cannot prove a create or transition will succeed.
* The cluster rejected the current credentials as unauthorized. Live build, service-account and release state could not be rechecked.
  A11's cluster observations remain dated findings; its installation and historical-registry claims were narrowed to what the available evidence supports.
* The cached tenant configuration confirms the `stable` channel parameter. The catalog uses versioned channels; the
  [helper](https://github.com/konflux-ci/tekton-integration-catalog/blob/24ed4b2be4ff378d2d688b7bc380e47ef99a3eba/stepactions/bundles/get-unreleased-bundle/0.1/get-unreleased-bundle.yaml) can return no matching bundle,
  and the
  [pipeline](https://github.com/konflux-ci/tekton-integration-catalog/blob/24ed4b2be4ff378d2d688b7bc380e47ef99a3eba/pipelines/deploy-fbc-operator/0.1/deploy-fbc-operator.yaml) conditions later install tasks on a returned bundle. This static configuration check does not reconstruct archived passing-run logs.
* The documented registry-secret linkage and snapshot-label rerun mechanisms were checked against official Konflux documentation.
  Linking secrets, relabeling snapshots, inspecting old passing-run credentials and verifying a real install remain separate authorized operations.
* Local shell/Python inventory counts were checked against release-management commit `0ed2981` (81 files, 29 test files, 30,164 lines).
  The full `make test`, commit lint, Markdown links and PR-list consistency checks validate the proposed documentation, not the live rollout.

## Consolidated FBC rollout review

The [rollout plan](ocp-5-0-fbc-rollout.md) reconciles FBC #82's 159-line planning file with this plan and the canonical onboarding workflow.
The audit checked #82's complete seven-commit diff, current FBC main, published check failure, effective required checks/app IDs, and the local tenant/admission drafts.
It traced the 0.2 wrapper to the 0.3 pipeline at integration-catalog `24ed4b2be4ff378d2d688b7bc380e47ef99a3eba`, the pinned bundle helper's
image revision to konflux-test `5f33b66974c024e0e3b2d809de88297e9806f9a0`, and RPA-selected production release tasks to `9bfb0b2588a07e765fccef05e2919e4a44ff4401`.

The helper compares against the target OCP index, so release in 4.x does not establish a 5.0 no-op. Current Pyxis opt-in and publishing cannot be inferred
from historical successful releases. The acceptable-bundles artifact lists all 12 pinned task refs, with three expiries on October 30 and lifecycle injection
on October 31; #82's claim that the lifecycle pin is non-expiring is stale. The rollout plan records immutable artifact/layer digests for reproduction.
No native image/E2E, cluster index render, cluster install, provisioning, GitLab submission or release operation was repeated or performed here.
The registry diagnostic below is a separate local authenticated manifest inspection.

## Priority FBC failure recovery

The [recovery plan](fbc-failure-recovery.md) takes precedence over Jira payload application and planning cleanup.
A fresh GitHub main-ref read still points to `2e6b489e65620738d68504d9158418fe463e2073`.
Its latest published operator checks fail at `get-unreleased-bundle` for all six OCP 4.16–4.21 versions; the corresponding catalog builds succeeded.
The saved September 30 4.19 step log records anonymous production-index pulls returning 401. This establishes that run's registry failure,
not a fresh pod diagnosis or an independent explanation for every failed run. Standard checks have warnings and require complete snapshot review.

The minimal registry repair is a separate local, single-commit tenant change: source ServiceAccount, Kustomization resource entry and generated ServiceAccount.
Full tenant regeneration reproduces the committed output; all 60,102 tenant tests pass. CODEOWNERS validation passes with 8,514 tests passed and 10,006 skipped
after rerunning it following regeneration. The full main suite passes (132,517 tests), as do Ruff, YAML and shell checks.
The warning group affected by concurrent regeneration was rerun on the stable tree: 2,179 pass and one fails because another tenant references a missing EC policy.
A focused check on untouched cached main reproduces that policy failure. The repository is therefore not fully green.
Initial concurrent regeneration caused missing-file failures in CODEOWNERS and that warning group; their affected checks were rerun after regeneration.
The inspected integration controller preserves added secret links while maintaining its own
image-pull credentials. Official documentation confirms the mount-link and selected-snapshot rerun mechanisms.
A local authenticated 4.19 registry manifest inspection succeeds; integration-pod access and the named tenant credential remain unverified.

Live verification remains blocked by Unauthorized cluster credentials; GitLab main refresh/submission remains blocked by DNS resolution.
No live link, rerun or release was applied. The separate OCP 5 repair still requires reconciliation of its existing tenant draft and exact-head CI.

## Additional FBC fix verification

A second render of the registry-repair tenant produces 222 resources, including exactly one integration runner ServiceAccount; its output matches the committed generated file.
The 5.0 tenant draft adds seven resources while preserving all 221 existing baseline resources. Application, Component and ImageRepository references and generated outputs match.
Build-service source at [`918a4ce53681c988c6b81bd140a58747ad60e7c3`](https://github.com/konflux-ci/build-service/blob/918a4ce53681c988c6b81bd140a58747ad60e7c3/internal/controller/component_build_controller_service_account.go)
derives `build-pipeline-` from the Component metadata name in both API models. Its derived 5.0 name matches the currently published #82 failure.
The controller provisions that account and its role binding; creating a bare replacement account is not the proposed fix.

Tekton source at [`fbf48a876d1b367d66824eda7d8e72781e8d4423`](https://github.com/tektoncd/pipeline/blob/fbf48a876d1b367d66824eda7d8e72781e8d4423/pkg/credentials/dockercreds/creds.go)
accepts `dockerconfigjson` secrets without a Docker annotation and writes merged credentials to `.docker/config.json`.
Annotated basic-auth entries can override them; the recovery plan now checks competing credentials and the new task's effective credential path.
The [runtime-auth guide](https://tekton.dev/docs/pipelines/auth/#configuring-docker-authentication-for-docker) confirms the `secrets` mount mechanism.
These upstream source checks do not identify the deployed controller/Tekton versions.

A fresh authenticated local index inspection succeeds. Local `opm` v1.56.0 reaches image-blob copying but is stopped by the 120-second timeout; no completed render is claimed.
The Konflux task uses a separately pinned image, and neither this local diagnostic nor repository tests establish its credential validity or live recovery.
Cluster authentication remains Unauthorized and GitLab main still cannot be refreshed because DNS resolution fails.

## Local release-data plan audit — October 7

The main checkout and all three repair/onboarding worktrees were inspected locally; their working trees remain unchanged and clean.
All drafts use cached main `8c18efee295889f5d86b03d16930a2f11977fd58`, so this audit does not establish readiness against current GitLab main.
Repository instructions require tenant and managed changes in separate merge requests. Existing CODEOWNERS covers the proposed source,
generated and admission paths. The recovery plan now records three scopes: registry repair, 5.0 tenant onboarding and later release admissions.
The tenant draft's extra `CLAUDE.md` rewrite should be separated before submission; its configuration-only scope is 16 files, adding seven resources.

Focused checks against the existing drafts passed:

| Draft | Checks | Result |
| --- | --- | --- |
| 5.0 tenant | Tenant manifest tests selected with `-k submariner` | 264 passed; 59,835 deselected |
| 5.0 tenant | Root `tests/test_tenant.py`, selected with `-k submariner` | 266 passed; 6 skipped; 62,454 deselected |
| 5.0 admissions | Constraints, schemas, consistency, FBC, basics and service-account mapping tests selected with `-k submariner-fbc` | 23 passed; 13 skipped; 68,867 deselected |

Fresh Kustomize renders match every generated tenant resource in both drafts. Registry repair preserves all 221 baseline resources and adds one;
5.0 onboarding preserves all 221 and adds seven. Object comparisons confirm that each admission changes only its application's membership list.
The draft stage/prod ReleasePlans match their respective admission labels, application, origin and target; automatic release remains disabled.
These focused checks supplement the earlier full registry-repair validation; they do not replace fresh-base CI or live reconciliation.

The missing build account is provisioned from the tenant Component, independently of the release-admission additions.
Cached main defines neither the named registry Secret nor the integration-runner ServiceAccount, and does not establish its ArgoCD apply/pruning mode.
The registry repair consequently requires live credential and field-ownership verification. The earlier unrelated missing-policy test failure remains;
no new GitLab submission, cluster change or successful FBC rerun is claimed.
