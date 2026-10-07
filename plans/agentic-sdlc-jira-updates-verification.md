<!-- markdownlint-disable MD013 -->

# Jira planning verification

Evidence audit: October 6–7, 2026; includes the complete assignment population, issue documents, public work and retained tenant artifacts.
[current-work.md](current-work.md) owns current engineering observations, [jira-update-queue.md](jira-update-queue.md) owns issue dispositions,
and [agentic-sdlc-jira-updates.md](agentic-sdlc-jira-updates.md) owns epic execution. Planning commits are published through [WIP PR #111](https://github.com/stolostron/submariner-release-management/pull/111), as requested. Four approved existing-story comments were posted and verified October 7 at 18:23 UTC. No field edit, transition, PR post, cluster change or release was performed.
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
The latest read-only content pass before posting repeated the complete 703-issue inventory and read 88 active/payload targets: descriptions, comments,
status, PR fields, parent/subtasks and actual update fields are unchanged against the preceding full-view baseline. All four active private Vulnerability full views were also refreshed, without shipped-image triage.
Before posting, all comments on 27 targets were paginated again, including the OLMv1 correction target; both epic memberships and duplicate-query populations remain unchanged. The bounded historical closure query still returns 259.
Both projects' complete create metadata and 21 existing targets' edit/transition metadata were re-read successfully with the same field constraints.
The latest 44 unique direct PR reads include the five legacy-closeout PRs, the OLMv1 reference and all six June Kubernetes qualification PRs. The June results remain one merged and five closed without merging; the K2 draft now links all six. Published heads/states are unchanged against the preceding pass apart from this planning PR. EVPN #6 verify passes at 629d9e67; tide remains pending and the import is still open. The focused first-chunk audit subsequently read all nine relevant PRs and their complete changed-file pages; Shipyard advanced during the successive focused audits; its dated posted comment retains the 3b67af1a snapshot.
The next-chunk read pins Shipyard to a88023ad, with hosted checks still running, one unresolved current YAML thread and four unresolved outdated threads. No review or approval is on that head; aggregate changes requested comes from earlier heads. Historical inventories retain their explicit cutoff and are separate from today's work.

| Deeper check | Result affecting the plan |
| --- | --- |
| Full GitHub review-thread pagination | Shipyard #2582: 37 threads, one unresolved/current and four unresolved/outdated; no review/approval on a88023ad. #2618: two threads, zero current/unresolved and an approval on current head despite older changes-requested aggregate |
| Exact local source inspection | Shipyard is clean at published a88023ad; returned hosted checks are still running. Author-reported 1,455 regression checks, 83 review-focused checks, six probes and client-go evidence were not repeated. Plugin a477bced and its two dirty court-permission test files were rechecked and remain unchanged |
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
and edit/transition metadata for 21 existing targets. All reads succeeded. Current project permissions allow create/edit/comment/link/assign/transition/resolve;
those permissions do not authorize writes on the user's behalf. Both Story type ids are 10009.
Reporter is required with a default; verify the approved/default reporter after creation.

| Action input | Verified result and correction |
| --- | --- |
| ACM creation | Component 33720, proposed priorities/Activity Types, `parent`, PR field, both point fields and sprint are writable. Use one membership path and read back the canary |
| CORENET creation | `parent`, proposed priority/Activity Type, Story Points and sprint are writable; legacy Epic Link, Original story points and Git Pull Request are absent. Set the latter two only in a subsequent edit after the new Story confirms support |
| CORENET edit support | Existing Stories 7062/7171/7615 expose Original story points and PR fields. Epic 7155 does not expose the PR field for editing; no epic PR-field edit is proposed |
| Related links | `Related`, id 10077, supports the proposed S1/ACM-45508, S1/OPGM-364 and K2/CORENET-7062 relationships. Check existing links before adding |
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
| Existing comments and independent epic edits | First four comments posted; remaining missing deltas and epic edits are pending review; full target comments and original ADF checked. They do not wait for new story creation. Summaries using S/K placeholders must wait for real keys and accurately reflect completed writes |
| S1/S5 creation and In Progress | Scope remains unfinished. S5 acceptance now consistently allows explicitly accepted evidence-based re-triage; unmerged draft closure does not satisfy remediation. Recheck existing scope before creation |
| S2/S3/S4 creation and proposed Resolved | Delivered contracts and linked merges support acceptance review; transition only after the approved criteria and the new canary's workflow/resolution are verified |
| K1–K5 creation and In Progress | Qualification/measurement/upstream gaps remain. Corrected field setup separates create from post-create edit; chosen points, sprint and actual canary metadata are required |
| Release/legacy/research closure reviews | No immediate transition is proposed. Preserve original acceptance scope and recover missing build/fix/QE/catalog or research evidence; unrelated failures are separate investigations |
| ACM-37426 timeline correction | Exact title and description drafts are prepared; apply together only after confirming the 5.1 target and install/migration contract, preserving original reference links |
| Deferred/other-owned/private work | No bulk comment, duplicate task creation, reopening, other-owner transition or vulnerability closure is proposed |

Completeness check: every active assigned non-Vulnerability issue has a payload or an explicit review/defer disposition in the queue. ACM-34592/ACM-40644 remain acceptance reviews, not pending unconditional transitions. The four-comment first chunk is posted and verified; it did not depend on story creation or the PR-field canary. Its autorelease and CVE drafts each contain one complete comment; new-story, sprint/points, contribution inventory and acceptance decisions remain explicit gates. The Kubernetes epic describes evidence gates as a design contract, with enforcement and installed-runtime qualification still required. S1’s execution order now includes the already-planned lifecycle relationship alongside addon consumption, with duplicate-link checks and read-back; the audit draft links the open helper-pod prerequisite directly.

The content passes corrected these scope/claim problems:

* ACM-39736 requires **multiple** team members each to complete a release, with the maintainer not driving; gaps must be documented and fed back into improvements. The maintainer’s October 7 report that another team member has started using CVE/autorelease tooling is adoption evidence, not evidence of completed full releases or feedback. The three relevant comments and ownership-transfer description now include that milestone; S4 and all rollups retain the original acceptance scope.
* ACM-39738 requires contribution of **all generally relevant skills**. The CVE children retain their own criteria; the plugin remains on existing CORENET-7155 tracking. Parent acceptance requires an inventory reconciliation, without duplicate stories.
* ACM-45318 targets ART Go builders consumed through **Brew/OSBS**, not every Go builder. The addon has verified affected references; sampled UBI Go Toolset stages do not justify an independent-product migration by themselves. Shared/pipeline inputs must be checked before classifying another path as affected.
* CORENET-7615 records decision owners/dates **when decided**; it does not require every pending decision to be settled. Its separate reviewer-confirmation and three-conflict resolution criteria remain. Optional sections are consolidated into one update per target.
* Test-pod E2E and checkout restoration are scoped to the actual recorded runs/contracts. The audit's initial Won't Fix labels are classifications, not proof of owner-accepted risk dispositions.

Independent recomputation confirms the 335-entry historical inventory has 290 merged/32 closed/13 open across 12 repositories,
with 113 audit, 74 EC/Tekton and 68 CVE theme entries; all three PR-list sets belong to that inventory.
The pinned 0ed2981 baseline reproduces 18 skills, 51 scripts, 29 tests, one helper and 30,164 lines.
Primary PR reads confirm #109/#110 validation is author-reported; no onboarding runtime or RPM regeneration was repeated here.
The first-chunk audit matched each original acceptance scope and complete comment history, and confirmed issue-level Browse/Add Comments permission on all four targets plus restricted-group membership. The proposed deltas were absent before posting. Source review qualified BuildPLRInProgress handling, retained the observed retarget/artifact-refresh gap, and removed unrelated setup details and aggregate test-count prose from the conductor comment. All 43 historical CVE PRs still reconcile to 23 merged/17 closed fix PRs plus three merged lint reverts; the bounded closure query again returns 259. The approved CVE comment was refreshed before posting to Shipyard 3b67af1a: checks still running, two current unresolved threads, a current-head changes-requested review and no approval. The contribution drafts now use the focused next-chunk evidence below and still require a fresh pre-post read; no fresh runtime qualification is inferred.
OPGM's draft stays on lifecycle publication scope. New-story/client/workflow choices and acceptance decisions remain execution gates;
read-only verification cannot establish that a future write or transition succeeds.

## Next contribution approval chunk

The focused October 7 audit refreshed full documents and complete comments for ACM-39738/39739/39740, ACM-39729 and CORENET-7155. All three contribution targets remain New, with comment totals 0/1/1. The parent is a Story with the same two Sub-task children. Original criteria, parent links, issue-level Browse/Add Comments permissions and restricted-group membership were checked. Proposed order: ACM-39739, ACM-39740, then ACM-39738; comments only, none posted. The 703-issue inventory above belongs to the preceding complete sweep.

Pinned Shipyard source at a88023ad already supports repository-registry configuration and native-command overrides. Child 39739 still requires project-level configuration, no hardcoded Submariner values and go-fix-cves merged into ai-helpers. Source PR #35 merged October 6 at 80c90e176244b6f84625778f7122e7a2c1993db3; its complete 11-file change and local source retain product-specific mappings, version references and Jira scope, including cve-jira-triage dependencies. Include those dependencies within child 39740's configuration review; preserve its own ai-helpers merge and non-Submariner CVE validation criteria.

The complete, untruncated ai-helpers main tree and source files pinned to a62717603bcf5cc13b744d123a7cef5ab02992f3 establish golang:fix-cve, golang:triage-fixed-cves, compliance:analyze-cve and node-cve tooling. Direct reads confirm merged [#470](https://github.com/openshift-eng/ai-helpers/pull/470), [#736](https://github.com/openshift-eng/ai-helpers/pull/736) and [#763](https://github.com/openshift-eng/ai-helpers/pull/763). Review overlapping module repair, reachability/analysis and triage capabilities with maintainers before choosing reuse, composition or extension. Their merges do not establish these children's acceptance. Author-scoped PR discovery does not prove absence of other contributions.

Parent 39738 covers all generally relevant skills. This candidate inventory needs owner classification, not automatic task creation:

| Candidate family | Existing scope / disposition |
| --- | --- |
| Maintained CVE-fix | ACM-39739; compare golang:fix-cve |
| CVE agent and cve-jira-triage dependencies | ACM-39740; compare analysis/triage tools; preserve cross-product validation |
| Release tooling | 18 current skill definitions; classify relevance and product coupling before selecting contribution scope |
| Kubernetes rebase | CORENET-7155; [#617](https://github.com/openshift-eng/ai-helpers/pull/617) remains open/draft at 7e1aa060f3167de8a66e5191bf8e8692666c3ad4; preserve existing tracking |

## Documentation validation

This contribution-chunk revision passes full `make -j4 test`, 136-file Markdown lint, 64 changed-document relative-link/anchor checks, exact 76-issue queue coverage and whitespace validation. Each target has one complete comment payload. Fresh target histories, original criteria and comment permissions were checked; unrelated creation/transition metadata remains the preceding audit's evidence and must be refreshed when needed.
No release/test implementation changed. Raw documents, metadata, comments and validation logs remain outside this public checkout.
