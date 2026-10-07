<!-- markdownlint-disable MD013 -->

# Jira planning verification

Evidence audit: October 6–7, 2026; latest pass re-read the complete assignment population, issue documents, public work and retained tenant artifacts.
[current-work.md](current-work.md) owns current engineering observations, [jira-update-queue.md](jira-update-queue.md) owns issue dispositions,
and [agentic-sdlc-jira-updates.md](agentic-sdlc-jira-updates.md) owns epic execution. Planning commits are published through [WIP PR #111](https://github.com/stolostron/submariner-release-management/pull/111), as requested. No Jira write, transition, PR post, cluster change or release was performed.
Private raw exports and pre-edit plan copies are retained outside this public checkout.

## Complete assigned-issue sweep

| Read | Result and limits |
| --- | --- |
| Paginated `assignee = currentUser() ORDER BY updated DESC`, no project/status/date restriction | 703 unique issues across ACM, CORENET, OPGM, KFLUXMIG, HYCLD, CLOUDWF, ODL, RCM and BREW |
| Active status-category query, also unrestricted | 80: 76 non-Vulnerability issues and four Vulnerability issues; its key set matches the active subset of the complete search |
| Terminal assigned history | 623: 144 non-Vulnerability and 479 Vulnerability issues; no reopening/bulk update proposed |
| Comprehensive initial full-view sweep | all 220 assigned issues plus nine related non-Vulnerability issues and four active private Vulnerability views; 233 full documents read |
| Non-Vulnerability `updated >= "2026-09-13"` query | 118 issues, 53 terminal; mutable update time does not prove recent implementation |
| Epic membership queries | ACM-39728 has ten direct children; CORENET-7155 has zero, and its description remains empty |
| Initial full comment pagination on 21 update/reconciliation targets | Returned unique ids reconcile with reported totals, including 159 comments on ACM-40644 rather than the 100 in its issue view |
| Latest public work discovery | 23 authored PRs updated since September 30, 16 currently open authored PRs, five authored issues updated since September 30; populations overlap |
| Initial direct PR sweep | 24 direct reads, including all 16 open authored PRs, releases#1444, EVPN #2–7 and cve-agent#35. Five merged PRs for ACM-34592 checked earlier |

The 76 non-Vulnerability active issues reconcile exactly to queue groups: automation 10, releases 17,
deadline/lifecycle/legacy eight, Kubernetes/MCN/EVPN 41. No private vulnerability keys or descriptions are copied into the queue.
Search counts and active categories were compared by unique key; absence in a filtered query was not treated as absence from Jira.
All assigned Vulnerability issues received inventory/status coverage; the deeper pass also fetched full views for the four active cases. No fresh shipped-image applicability/fix triage was performed.
Their four active cases remain private follow-up; the historical 259 closures below are a different population.

The comment CLI emits consecutive page objects and rendered text, which can omit rich-text links.
Pages were decoded, flattened and checked against each reported total; issue ADF was retained separately for exact links and field editing.
Neither rendered text nor an issue view's first 100 comments is a safe replacement document for Jira rich text.

Fresh observations add OPGM-364's existing lifecycle-publication scope and status request, ACM-25779's stale console template,
ACM-34593's original build-failure acceptance scope, and the already-created MCN CI subtask set.
The May draft saying it will split into subtasks is obsolete. ACM-34592's five linked PRs all merged May 28;
the latest pass now finds a successful October 2 route-agent push build for its sibling, with a separate failing EC scenario. Fix attribution and original acceptance criteria still need review. Both contribution children require an ai-helpers merge,
and ACM-39740 additionally requires another product's validation. CVE-agent#35's source merge is preparatory evidence only.

## Current checks and local work

The first proposed-action audit read 114 full non-Vulnerability documents, including 29 additional scope/duplicate candidates.
The second content pass repeated the complete 703-issue inventory and read 88 active/payload targets: descriptions, comments,
status, PR fields, parent/subtasks and actual update fields are unchanged against the preceding full-view baseline.
All comments on 26 targets were paginated again; both epic memberships and duplicate-query populations remain unchanged.
Both projects' complete create metadata and 20 existing targets' edit/transition metadata were re-read successfully with the same field constraints.
The 32 direct PR reads find unchanged source/state except this planning PR; Shipyard hosted checks have progressed, with some deployment checks still running.
Its current head still has no approval. Historical inventories retain their explicit cutoff and are separate from today's work.

| Deeper check | Result affecting the plan |
| --- | --- |
| Full GitHub review-thread pagination | Shipyard #2582: 32 threads, four unresolved/outdated, zero current/unresolved; no current-head approval. #2618: two threads, zero current/unresolved and an approval on current head despite older changes-requested aggregate |
| Exact local source inspection | Shipyard is clean at published 0777e63c; some hosted deployment checks are still running. Author-reported 1,372 checks were not repeated. Plugin a477bced and its two dirty court-permission test files were rechecked and remain unchanged |
| EVPN repo-wide PR/source reads, beyond author search | #4/#5 merged; #3/#6/#7 imports open, #7 verify failing. Current verification covers planning/public safety; decision/conflict acceptance remains unrecorded |
| OLMv1 private prototypes | Preparatory templates exist, including incomplete RBAC; not delivered addon support |

Exact heads, returned checks and handoffs belong to [current-work.md](current-work.md).
Author-reported runs, source contracts, approvals and successful runtime qualification are different evidence types;
the refresh did not execute plugin tests, trials, builds or hosted reruns.

### Production artifact checks

Direct `skopeo inspect` verified the already-recorded exact 0.24.1 production bundle reference/version;
the [work map](current-work.md#release-recovery-and-time-sensitive-work) retains its digest.
Seven recorded 4.16–4.22 indexes were probed with `oc image extract`, each bounded to 100 seconds; all timed out, so membership is unknown.
`oc get` of all three recorded September component production Release names returned NotFound in the authenticated tenant.
Repository YAMLs retain intent/snapshot identities, not success verdicts. Recover catalog/QE/release proof before closeout;
these reads establish bundle publication, not end-to-end validation or artifact absence. No status skill used an inferred version.

Static conductor review supersedes several old roadmap claims: all build-readiness scripts are review level;
scripted steps can have external verifiers; `run_conductor` is extracted and has an integration test target;
bundle snapshot selection has a warn-only tag-age check; checkout restoration is implemented.
The [shortened roadmap](autorelease-step-automation.md) preserves remaining write-acknowledgement, snapshot-selection, retry and concurrency questions.
No implementation or external runtime was changed to test those questions.

## Public PR evidence

The audit fetched pull-request metadata for 347 unique PRs through GitHub's API, covering the three remediation lists and the initial epic-period search.

| Evidence | Verified result |
| --- | --- |
| Glasswing list | 113 URLs in the September inventory; 105 historical merges, 8 drafts open at that cutoff. October 7 direct reads find those eight closed unmerged on October 3; the earlier claim that all were still open on October 6 was incorrect |
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

## Kubernetes rebase evidence

The inventory is pinned to fork branch bak42 at `febb7974696e870f933e8ad3741605d31ead0b5c`; a remote-ref read confirms that backup exists.
At that committed snapshot: 134 files, 20,792 lines, 32 gate documents, four design/compatibility documents,
13 shell/Python scripts, 238 Python test functions and 16 pattern-retention cases. Hooks/gate scripts are outside the script count.
Bak42 adds 69 commits beyond PR `7e1aa060`; current HEAD adds another 13, plus two dirty test files.
The checked fork refs remain at the PR and bak42; neither backs up the entire current source.

GitHub verifies 108 closed July draft PRs across five repos and six June PRs (one merged).
The legacy local matrix has **536 rows** dated July 29–September 24, **218** for 1.36.2, with latest unmutated PASS summaries for all six targets.
The inspected matrix-state has no `evidence/` archive and only one run-input record. Those rows cannot establish current retained-evidence qualification;
Proposed K2 status stays In Progress pending per-target evidence/failure dispositions or an explicit limited-acceptance decision. PR counts are not counts of accepted runs.

Current eval source captures model/tokens/turns/cost but emits zeros when terminal metrics are missing; exclude that fallback from measurements.
The runner collects artifacts and does not execute YAML judges. The guide's $17–27 light/$40–60 heavy estimates are documented observations,
not a benchmark repeated here. K3 retains valid measurements/judge outcomes and the unanswered reviewer/shared-harness question.
That question is an [issue comment](https://github.com/openshift-eng/ai-helpers/pull/617#issuecomment-5587555534), not a review thread.
The [published Kubernetes v1.37.1 release](https://github.com/kubernetes/kubernetes/releases/tag/v1.37.1) supports target availability, not a consumer result.

## Field and infrastructure evidence

The proposed-action audit read both projects' complete Story create metadata (ACM 81 fields, CORENET 21), project permissions,
and edit/transition metadata for 20 existing targets. All reads succeeded. Current project permissions allow create/edit/comment/link/assign/transition/resolve;
those permissions do not authorize writes on the user's behalf. Both Story type ids are 10009.
Reporter is required with a default; verify the approved/default reporter after creation.

| Action input | Verified result and correction |
| --- | --- |
| ACM creation | Component 33720, proposed priorities/Activity Types, `parent`, PR field, both point fields and sprint are writable. Use one membership path and read back the canary |
| CORENET creation | `parent`, proposed priority/Activity Type, Story Points and sprint are writable; legacy Epic Link, Original story points and Git Pull Request are absent. Set the latter two only in a subsequent edit after the new Story confirms support |
| CORENET edit support | Existing Stories 7062/7171/7615 expose Original story points and PR fields. Epic 7155 does not expose the PR field for editing; no epic PR-field edit is proposed |
| Related links | `Related`, id 10077, supports the proposed S1/ACM-45508 and K2/CORENET-7062 relationships. Check existing links before adding |
| Terminal transitions | Inspected closure-review targets require resolution. The epic and Story workflows differ; no transition id is reused, and no new Story's transitions can be verified before it exists |
| Comments | The authenticated account belongs to `Red Hat Employee`. REST supports initial restricted visibility; current `acli comment create` only exposes project-default visibility, so it is not the execution client for these comments |
| Sprint and points | Sprints 87579 and 87581 still report active. Story-point values and the story split remain proposed choices, not inferred approvals |

The duplicate/scope search found a closed broader Glasswing epic ACM-36285 with no children and related incidents,
not a matching shipyard-audit remediation story in the searched results. S5 now records that boundary instead of claiming no tracker exists.
Existing OCP readiness epic ACM-36458 has eight runtime-readiness children; S1 remains catalog/release onboarding, not those compatibility deliverables.
Existing Kubernetes delivery epic CORENET-7450 has nine children; CORENET-6983 retains 1.36 delivery scope.
K2/K4 qualify the plugin without recreating or changing those other-owned repository-bump tasks.
The September 13–30 Vulnerability JQL `BY currentUser()` returned 259 currently assigned closures earlier;
that historical population does not justify closing today's four private active cases.

The [epic edits](agentic-sdlc-jira-updates-payloads/submariner-sustenance/epic-description-edits.md) retain their own baseline/counting definitions.
[OCP rollout](ocp-5-0-fbc-rollout.md) owns immutable task/index inputs and expiry evidence;
[FBC recovery](fbc-failure-recovery.md) owns historical 401 diagnosis, prepared release-data render/regression results and prerequisite probes.
Earlier focused draft tests passed, but a full release-data warning-group failure reproduced on untouched cached main; the entire repository was not green.
Tenant/admission drafts still require fresh-base reads and separation of the tenant's unrelated documentation rewrite.

The latest authenticated namespace read returns zero PipelineRuns and 746 snapshots. Six retained FBC snapshots match the pinned
4.x source and recover the exact scenario/run associations: all aggregate Failed/operator TestFail, with completed standard warnings.
The exact map belongs to [FBC recovery](fbc-failure-recovery.md#retained-snapshot-and-scenario-identities).
The registry Secret remains unlinked to the runner; OCP 5 Application/Component/build account are NotFound.
Credential usability and deployed controller/field ownership remain unverified. The earlier GitLab read failed DNS;
no fresh-base access is claimed and no credential contents were printed.

The retained 0.23.4 component-stage snapshot has nine components and aggregate TestSucceeded=True;
its recorded stage Release is currently Released=True/Succeeded, confirming evidence already in the parent comments.
The retained 0.22.2 candidate also passes aggregate integration with warnings. Direct immutable bundle inspection/extraction verifies
its v0.22.2 label and 0.22.2 CSV. Seven mapped related-image digests differ from the snapshot operands; registry copying can change digests,
so content identity remains unreconciled rather than proven invalid. The snapshot operator inspects as v0.22.2;
the embedded production operator inspection fails. Neither candidate selection nor EC/bundle acceptance is inferred.
The October 2 route-agent-0-21 push check succeeds at 82adbacd, while its retained EC scenario fails.
That supports review of the original build issue without claiming compliance or adding EC acceptance to its original scope.

## Execution limits

Before an authorized write, refresh issue/comments/ADF/PR evidence, project create/transition/resolution/link metadata,
acceptance criteria and chosen points/sprint. Create one reviewed canary, read it back and only then continue the epic sequence.
Set restricted comment visibility at creation and verify it. Preserve full original ADF and write ids for correction/read-back.
Do not repeat a fact already recorded, bulk-close private vulnerabilities, resolve unrelated test subtasks as release work,
or infer product compatibility/qualification/production from local packaging, source merges or Jira status.
No native build/E2E, plugin trial, tenant regression or hosted rerun was repeated. The direct artifact/retained-Release reads above were performed; they did not execute a release.

## Proposed-action disposition

| Proposed action | Review result |
| --- | --- |
| Existing comments and independent epic edits | Missing deltas remain reviewable; full target comments and original ADF checked. They do not wait for new story creation. Summaries using S/K placeholders must wait for real keys and accurately reflect completed writes |
| S1/S5 creation and In Progress | Scope remains unfinished. S5 acceptance now consistently allows explicitly accepted evidence-based re-triage; unmerged draft closure does not satisfy remediation. Recheck existing scope before creation |
| S2/S3/S4 creation and proposed Resolved | Delivered contracts and linked merges support acceptance review; transition only after the approved criteria and the new canary's workflow/resolution are verified |
| K1–K5 creation and In Progress | Qualification/measurement/upstream gaps remain. Corrected field setup separates create from post-create edit; chosen points, sprint and actual canary metadata are required |
| Release/legacy/research closure reviews | No immediate transition is proposed. Preserve original acceptance scope and recover missing build/fix/QE/catalog or research evidence; unrelated failures are separate investigations |
| Deferred/other-owned/private work | No bulk comment, duplicate task creation, reopening, other-owner transition or vulnerability closure is proposed |

The second content pass corrected four substantive scope/claim problems:

* ACM-39736 requires **multiple** team members each to complete a release, with the maintainer not driving; gaps must be documented and fed back into improvements. One volunteer is a milestone, not its acceptance criterion. S4 and all rollups now retain that original scope.
* ACM-39738 requires contribution of **all generally relevant skills**. The CVE children retain their own criteria; the plugin remains on existing CORENET-7155 tracking. Parent acceptance requires an inventory reconciliation, without duplicate stories.
* ACM-45318 targets ART Go builders consumed through **Brew/OSBS**, not every Go builder. The addon has verified affected references; sampled UBI Go Toolset stages do not justify an independent-product migration by themselves. Shared/pipeline inputs must be checked before classifying another path as affected.
* Test-pod E2E and checkout restoration are scoped to the actual recorded runs/contracts. The audit's initial Won't Fix labels are classifications, not proof of owner-accepted risk dispositions.

Independent recomputation confirms the 335-entry historical inventory has 290 merged/32 closed/13 open across 12 repositories,
with 113 audit, 74 EC/Tekton and 68 CVE theme entries; all three PR-list sets belong to that inventory.
The pinned 0ed2981 baseline reproduces 18 skills, 51 scripts, 29 tests, one helper and 30,164 lines.
Primary PR reads confirm #109/#110 validation is author-reported; no onboarding runtime or RPM regeneration was repeated here.
The Shipyard contribution payloads use published 0777e63c with pending hosted checks and no current-head approval.
OPGM's draft stays on lifecycle publication scope. New-story/client/workflow choices and acceptance decisions remain execution gates;
read-only verification cannot establish that a future write or transition succeeds.

## Documentation validation

This content revision passes full `make -j4 test`, 136-file Markdown lint and 65 changed-document relative-link/anchor checks,
exact 76-issue queue coverage, original epic snippet checks, refreshed field/transition metadata checks and whitespace validation.
No release/test implementation changed. Raw documents, metadata, comments and validation logs remain outside this public checkout.

The first commit-hook attempt hit an existing sign-off assertion despite the earlier full-suite pass.
A private two-commit fixture reproduced the assertion's `git log | grep -q` race: Git exited 141 (SIGPIPE) while grep matched successfully.
The focused release-note suite then passed all 48 checks. No test implementation was changed; publication still requires a passing normal commit hook.
