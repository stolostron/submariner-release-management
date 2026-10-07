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
| Full issue views | Latest pass: all 220 assigned issues plus nine related non-Vulnerability issues and four active private Vulnerability views; 233 full documents read |
| Non-Vulnerability `updated >= "2026-09-13"` query | 118 issues, 53 terminal; mutable update time does not prove recent implementation |
| Epic membership queries | ACM-39728 has ten direct children; CORENET-7155 has zero, and its description remains empty |
| Full comment pagination on 21 update/reconciliation targets | Returned unique ids reconcile with reported totals, including 159 comments on ACM-40644 rather than the 100 in its issue view |
| Latest public work discovery | 23 authored PRs updated since September 30, 16 currently open authored PRs, five authored issues updated since September 30; populations overlap |
| Direct PR reads | Latest pass: 24 direct reads, including all 16 open authored PRs, releases#1444, EVPN #2–7 and cve-agent#35. Five merged PRs for ACM-34592 checked earlier |

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

The latest complete inventory still returns 703 unique assigned issues and the same 80 active keys/statuses.
All 233 full documents were compared with the previous full-view baseline: actual `updated` fields, descriptions, comments,
links, PR fields, parent/subtasks and status/summary show no changes. Freshness comparisons use full-view `updated` fields, which search rows do not expose.
The earlier fully paginated comment histories remain supported by those unchanged documents; re-fetch before any write.
Direct PR heads/states/reviews remain unchanged apart from the planning PR's publication; EVPN #3–7 label changes do not establish acceptance.

| Deeper check | Result affecting the plan |
| --- | --- |
| Full GitHub review-thread pagination | Shipyard #2582: 32 threads, four unresolved/outdated, zero current/unresolved; no current-head approval. #2618: two threads, zero current/unresolved and an approval on current head despite older changes-requested aggregate |
| Exact local source inspection | Shipyard has two clean local commits through 36afbd1e beyond published #2582 at 56e7233a; 1,372 checks are author-reported, not repeated. Plugin still has two dirty court-permission test files |
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

Issue reads checked Activity Type, component 33720, priorities, exact description snippets and ADF PR fields.
Active sibling sprint observations were ACM 2026-59 (87579) and CORENET 295 (87581); ACM 2026-58 (85613) is closed.
Those observations do not establish writable create/transition metadata or approved points/status choices.
The September 13–30 Vulnerability JQL `BY currentUser()` returned 259 currently assigned closures, a historical population separate from today's four active cases.

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

## Documentation validation

This refresh passes full `make -j4 test`, including Markdown lint across 136 files, plus 110 changed-document relative-link/anchor checks
and whitespace validation. All four original epic-description snippets and the insertion heading match exactly once in the refreshed document.
The queue still accounts for all 76 active assigned non-Vulnerability keys exactly once. Existing unrelated edits are preserved;
no release/test implementation was changed. Raw exports, source snapshots and validation logs remain outside this public checkout.

Five superseded design bodies now retain concise current contracts and immutable links to their complete pre-cleanup history.
Canonical recovery/rollout/queue documents retain active gates; historical detail is preserved in Git without duplicating it in the current plans.
