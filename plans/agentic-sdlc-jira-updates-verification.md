<!-- markdownlint-disable MD013 -->

# Jira planning verification

Evidence audit: October 6–7, 2026; includes the complete assignment population, issue documents, public work and retained tenant artifacts.
[current-work.md](current-work.md) owns current engineering observations, [jira-update-queue.md](jira-update-queue.md) owns issue dispositions,
and [agentic-sdlc-jira-updates.md](agentic-sdlc-jira-updates.md) owns epic execution. Planning commits are published through [WIP PR #111](https://github.com/stolostron/submariner-release-management/pull/111), as requested. Four approved existing-story comments were posted and verified October 7 at 18:23 UTC. No Jira field edit, transition, PR comment, cluster change or release was performed.
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
The preceding 44 unique direct PR reads include the five legacy-closeout PRs, the OLMv1 reference and all six June Kubernetes qualification PRs. The June results remain one merged and five closed without merging; the K2 draft now links all six. Published heads/states are unchanged against the preceding pass apart from this planning PR. EVPN #6 verify passes at 629d9e67; tide remains pending and the import is still open. The focused first-chunk audit subsequently read all nine relevant PRs and their complete changed-file pages; Shipyard advanced during the successive focused audits; its dated posted comment retains the 3b67af1a snapshot.
The earlier next-chunk read pins Shipyard to a88023ad, with hosted checks still running, one unresolved current YAML thread and four unresolved outdated threads. No review or approval is on that head; aggregate changes requested comes from earlier heads. Historical inventories retain their explicit cutoff and are separate from today's work.

| Deeper check | Result affecting the plan |
| --- | --- |
| Latest GitHub review-thread pagination | Shipyard #2582: 39 threads, three unresolved/current and four unresolved/outdated; current-head changes requested and no approval on a88023ad. #2618: two threads, zero current/unresolved and an approval on current head despite older changes-requested aggregate |
| Exact local source inspection | Shipyard HEAD matches published a88023ad; the final local read finds five dirty skill/script/test files (+108/-9), superseding the earlier clean-checkout observation. Published checks all pass or skip; they do not qualify those local edits. Author-reported 1,455 regression checks, 83 review-focused checks, six probes and client-go evidence were not repeated. Plugin a477bced and its two dirty court-permission test files were rechecked and remain unchanged |
| EVPN repo-wide PR/source reads, beyond author search | #4/#5 merged; #3/#6/#7 imports open, #7 verify failing. Current verification covers planning/public safety; the later focused audit below adds substantive merge-discussion evidence |
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

The latest authenticated namespace read returns zero PipelineRuns and 741 snapshots, down from the earlier 746. Six retained FBC snapshots match the pinned
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

## Prepared contribution approval chunk

The focused October 7 audit refreshed full documents and complete comments for ACM-39738/39739/39740, ACM-39729 and CORENET-7155. All three contribution targets remain New, with comment totals 0/1/1. The parent is a Story with the same two Sub-task children. Original criteria, parent links, issue-level Browse/Add Comments permissions and restricted-group membership were checked. Current group-2 order: ACM-39740, ACM-39739, then ACM-39738; comments only, none posted. The 703-issue inventory above belongs to the preceding complete sweep.

Pinned Shipyard source at a88023ad already supports repository-registry configuration and native-command overrides. Child 39739 still requires project-level configuration, no hardcoded Submariner values and go-fix-cves merged into ai-helpers. Source PR #35 merged October 6 at 80c90e176244b6f84625778f7122e7a2c1993db3; its complete 11-file change and local source retain product-specific mappings, version references and Jira scope, including cve-jira-triage dependencies. Include those dependencies within child 39740's configuration review; preserve its own ai-helpers merge and non-Submariner CVE validation criteria.

The maintainer challenged the marketplace-overlap inference. A deeper static comparison read the loaded source contracts and deterministic scripts plus eight pinned marketplace implementation/dependency files. It establishes distinct workflow contracts:

| Marketplace workflow at a6271760 | Maintained workflow | Material distinction |
| --- | --- | --- |
| [golang:fix-cve](https://github.com/openshift-eng/ai-helpers/blob/a62717603bcf5cc13b744d123a7cef5ab02992f3/plugins/golang/skills/fix-cve/SKILL.md) | Shipyard cve-fix at a88023ad | Supplied module/fix/CVE/ticket and compatibility-selected patching versus scanner-discovered findings, scripted per-location remediation/rollback, builder-aware stdlib handling and final build/rescan/PR gates |
| [compliance:analyze-cve](https://github.com/openshift-eng/ai-helpers/blob/a62717603bcf5cc13b744d123a7cef5ab02992f3/plugins/compliance/skills/analyze-cve/references/implementation.md) | CVE agent at 80c90e17 | One CVE/ticket per invocation, source govulncheck/call-graph report and optional fix versus recurring portfolio survey, shipped-image/provenance evidence, independent verification, prior-triage auditing and closure gating |
| [node-cve](https://github.com/openshift-eng/ai-helpers/blob/a62717603bcf5cc13b744d123a7cef5ab02992f3/plugins/node-cve/skills/analyze-cve-repos/SKILL.md) | CVE agent | Latest Node-team OCP version, downstream-branch reachability and Jira/Slack reporting versus all active product versions, shipped-image triage and gated issue actions |
| [golang:triage-fixed-cves](https://github.com/openshift-eng/ai-helpers/blob/a62717603bcf5cc13b744d123a7cef5ab02992f3/plugins/golang/skills/triage-fixed-cves/SKILL.md) | CVE agent | OCP release-payload Go-stdlib/toolchain cross-reference report versus product issue lifecycle and broader applicability/provenance verification |

Shared security vocabulary and basic operations do not establish interchangeable workflows or a contribution conflict. No demonstrated duplication justifies a reuse/composition gate. Removed that inferred prerequisite and the unrelated marketplace paragraphs from the three Jira drafts. This comparison inspected source; it did not execute either set of tools.

Parent 39738 covers all generally relevant skills. This candidate inventory needs owner classification, not automatic task creation:

| Candidate family | Existing scope / disposition |
| --- | --- |
| Maintained CVE-fix | ACM-39739; preserve project-level configuration and merge criteria |
| CVE agent and cve-jira-triage dependencies | ACM-39740; preserve per-product configuration and cross-product validation |
| Release tooling | 18 current skill definitions; classify relevance and product coupling before selecting contribution scope |
| Kubernetes rebase | CORENET-7155; [#617](https://github.com/openshift-eng/ai-helpers/pull/617) remains open/draft at 7e1aa060f3167de8a66e5191bf8e8692666c3ad4; preserve existing tracking |

## Prepared CI approval chunk

The October 7 focused audit read 35 full issue documents: CORENET-7086/7171, all 27 implementation subtasks, Prow scope 7083, plugin epic 7155 and supporting 7067/7081/7087/7089. Complete histories on the first 31 targets reconcile with reported totals. The proposed targets have 0/2 comments, Browse/Add Comments permission and confirmed restricted-group membership. Parent 7086 is To Do with exactly 28 children (research plus implementation); research 7171 is In Progress; all 27 implementation subtasks are To Do with no comments. The enclosing epic's Closed status does not establish child acceptance.

The research proposal already linked in the May comments was read directly at notes-source commit 723f6f4f683bc19cb72b0cb7c13c7821e501c3f1. It documents the five original research categories, rationale/adoption phases, goheader, CRD/Go compatibility checks and post-merge AI workflows. No tool health/version claims were revalidated or promoted to current recommendations. Corrected the drafts to treat header/API coverage as implementation handoffs, not missing research or new research acceptance criteria. Dependency licenses (7195) and API conventions (7174) do not substitute for those parent criteria; the 7173 curated-linter scope can accommodate header enforcement but does not explicitly confirm it.

The proposed GHA/Prow split is not settled by the research note: 7083 explicitly covers Prow presubmit/postsubmit/periodic jobs, and 7087 covers Prow image builds. Removed the exclusive cloud-E2E attribution; retained 7196/7197/7198's explicit post-merge boundary. No new subtask or scope reassignment is proposed. No implementation PR is linked in the 29 research/implementation issue documents. A direct openshift/mcn lookup returned 404 and an upstream organization listing identified no MCN-named target; those bounded reads do not prove repository or implementation absence. No published CI/runtime result is claimed.

The two comments add the created-task and handoff deltas without repeating the May survey or its existing research link. Proposed order is research 7171, then parent 7086. No comments or fields were written; contribution comments remain pending separately. The broader assigned-issue inventory retains its preceding audit date.

## Prepared EVPN approval chunk

The focused October 7 audit refreshed CORENET-7615 and the three named conflict issues (7501/7504/7505), including complete histories: all four are To Do with zero comments. Original criteria, issue-level comment permissions and restricted-group membership were checked. Six direct PR reads and complete changed-file pages confirm #2/#4/#5 merged and #3/#6/#7 open; #6 verify passes with tide pending, #7 verify fails. These implementation statuses are omitted from the planning comment.

A substantive [October 1 merge discussion](https://github.com/openshift/evpn-gateway-appliance/pull/2#issuecomment-5936707328) was missing from the preceding draft. It records preliminary artifact-graph feedback, the OpenShift FRR/frr-metrics choice with standalone/EVPN-metrics fixes, and a transit-VIF resolution for 7501. It links 7504/7505 to the payload decision and identifies a follow-up actor for still-pending product-home/cluster/AMI decisions. Responsibilities were explicitly deferred; the discussion does not clearly confirm release gates. PR #2 has no formal reviews or inline review comments, but that does not erase its substantive discussion or prove a lack of review.

Six published source files were read at main 306b8fe8a68cd878a9b8272b5329e5a6b8ac1e92, including the decision index, delivery/pipeline plans and Makefile. The decision index retains September 29 proposals; it has not incorporated the October 1 discussion. The three Jira descriptions also retain their old wording and are unassigned. Treat the discussion as existing decision evidence to reconcile with owner attribution, not a reason to declare all original criteria accepted or remake those decisions. No new requirement to settle every pending decision is introduced.

The public main source differs from the newer local checkout. A local ci-source.md is absent at the pinned published main; it was not used as published evidence. No appliance build, AWS qualification, release or repository change was executed. The shortened comment links PR #2 and the exact discussion, preserves To Do, and leaves related-issue/decision-index edits outside this approval chunk. All earlier pending chunks remain pending.

## Grouped approval order

The October 7 organization pass reviewed the assigned queue, all 14 portfolio targets, the optional URL-conversion draft, four posted comment records, five ACM epic edits, ten proposed stories, both epic summaries and their supporting work/evidence plans. The [queue](jira-update-queue.md#approval-order) now owns one order, starting with established comments and ending with new tracking and acceptance reviews. Portfolio sections follow that order; duplicate chunk tables were removed from the execution plan.

Existing comment and description payloads retain their text and criteria. Only organization/instructions changed. The merged CVE-agent update precedes the mutable CVE-fix update; the parent remains last. New ACM tracking keeps S4 as canary, then S2/S3 before unfinished S1/S5. Epic descriptions need no new keys, while summaries still do. Optional metric edits follow substantive edits; verification checks only the edits actually approved.

All 76 active non-Vulnerability dispositions and posted ids remain intact. This pass used the preceding audited Jira/PR records; it did not perform a new live sweep, approve writes, post comments, create tasks or transition issues. Target evidence and permissions still require refresh immediately before an approved action.

## Final plan review

The final October 7 read repeated the unrestricted 703-issue inventory and fetched 228 full non-Vulnerability documents (all 220 assigned, plus eight related), complete comment histories on 27 targets (315 comments, including all 159 on ACM-40644), both projects’ complete Story create metadata and 20 targets’ edit/transition metadata. Assigned keys/statuses and compared scope fields remain unchanged. The four posted comments match their recorded text, clickable links and restricted visibility. Epic membership/duplicate searches remain unchanged; restricted-group membership was verified through the authenticated account’s groups. This pass performed no Jira writes or private vulnerability triage.

Twenty-two direct PR reads and complete Shipyard review-thread pagination supersede the earlier running-check/no-current-review observations: #2582 at a88023ad has 46 successful/three skipped checks, current-head changes requested and three current unresolved threads. Fresh tenant reads retain all six documented failed FBC associations, both nine-component candidate verdicts and the successful component-stage Release. The registry link and OCP 5 resources are still absent; GitLab DNS remains unavailable. No credential usability, archived task diagnosis, installation, QE or new release was established.

The execution plan now separates creation from terminal acceptance, handles uncertain write results before retrying and checks changed baselines before edits/rollback. Posted payloads remain fixed historical records. The epic deny-rule wording now distinguishes minimum-version repair from catalog replacement. Independent recomputation confirms the 335-entry historical totals and all three PR-list memberships; runtime claims retain their original evidence limits.

## Second plan review

The repeated October 7 read again returned 703 assigned issues, 228 full non-Vulnerability documents and all 315 comments across 27 complete histories.
Compared issue scope/status fields, histories, epic membership and duplicate-search totals are unchanged. Authenticated restricted-group membership remains confirmed.
Direct FBC main/PR reads confirm the recovery source and #82 head/checks remain unchanged; the PR's reported base object is not used as current-main evidence.

A read-only synthetic probe of `fbc_tests_passed` accepts just the two required `BuildPLRInProgress` markers without completion evidence (exit 0).
The existing focused suite also passes all 16 checks. This demonstrates helper acceptance, not an end-to-end verifier or live release failure.
Source review confirms the verifier omits snapshot aggregate conditions and chooses the latest matching snapshot, even with a source pin;
stage generation repeats that selection. The recovery plan now requires fresh finished/successful verdicts, returned scope/name comparison and generated-YAML identity review.
No script, snapshot, release or posted comment changed.

The pending lifecycle-status comment now retains the original prohibition on new OpenShift 5 compatibility statements, distinguishes the release reference
from package-publication proof and preserves the permitted team IIB/catalog alternative. S1 explicitly keeps that existing publication acceptance separate
from its broader runtime scope. The queue's refresh count now matches the latest 220 assigned plus eight related documents;
private vulnerability inspection remains attributed to the earlier comprehensive sweep.

## Payload usefulness review

The review compared pending existing-issue comments with their original criteria and complete histories. Nineteen fresh full issue reads and all 27 complete
comment histories are unchanged. Group 1 is now one short correction on CORENET-7171: the implementation tasks exist and the AI scope is post-merge.
The parent CI comment, CVE contribution-parent rollup and older CVE progress draft are deferred because they repeat visible tracking or existing updates.
Their coverage, inventory and scope decisions remain in the queue. Execution guidance now requires a distinct missing fact or requested answer before posting;
audit checklists and acceptance instructions belong in the plan. No Jira write or acceptance change is performed.

The fresh contribution read also finds Shipyard #2582 advanced to 4fa703b3, matching clean local HEAD. The previously dirty five-file delta is now published.
The final refresh returns 45 successful and three skipped checks, a changes-requested review on this head, and four current/four outdated unresolved threads
out of 41; no current-head approval is recorded. Pending text and the work map now reflect this source change; qualification was not rerun.

The remaining review shortens 23 pending payload blocks from 2,664 to 1,324 words. Release comments retain newly recovered identities
and unreconciled evidence; builder/lifecycle comments retain their concrete inventory or requested status. New-story comments keep delivery PRs and relevant
qualification limits; epic summaries introduce the new keys instead of copying child inventories. Audit/duplicate checks move outside posted descriptions,
and S1's done/not-done annotations move from acceptance criteria to progress. Acceptance requirements remain unchanged. The exact four posted blocks and
historical inventories are preserved. Fresh EVPN main/decision-index reads confirm the unreconciled proposals; plugin source still has the same HEAD and two dirty tests.

Optional epic edits 1/2 now replace stale file/line/test totals with verified operation and validation scope. K1's scope likewise names tests instead of
using a dated test-function count. Historical counting methods remain recorded; no tracking creation or acceptance criterion is removed.

## Duplicate epic-summary review

Fresh October 7 reads confirm both epics remain In Progress, their descriptions and complete histories are unchanged (one/six comments),
and their child searches still return ten/zero stories. The pass removes both automatic epic-summary drafts and their execution steps. They repeat the new child keys, delivery PRs
and qualification limits already carried by the children. A separate missing decision, delivery or blocker can justify a later epic comment;
creating tracking alone does not. The new-story baseline comments, all acceptance requirements, four posted records and historical inventories remain intact.
The queue, portfolio instructions and payload index now agree; no placeholder-key summary is left to post. Earlier preparation records above describe superseded drafts.

## Action-scoped preflight review

The execution plan now reconciles completed epic edits before story creation: a description written in group 6 must not fail the later empty-description audit check. ACM edits check only their approved pending snippet/heading and preserve earlier writes.
Preflight is limited to the approved Jira group's targets, mutable claims and field prerequisites. Verified historical populations
retain their source/cutoff; their counting recipes remain available for a correction or expanded audit. Creating plugin tracking no longer requires
backing up unrelated working-tree changes first. Source preservation remains required before authorized engineering changes/publication, and frozen-source,
loaded-runtime and retained-budget checks remain required before fresh qualification. Story descriptions, baseline comments and acceptance criteria are unchanged.
No plugin backup, push, test or qualification was performed by this documentation review.

## Canary completion and PR-field review

The creation sequences previously created the remaining stories before posting the canary's restricted baseline comment, and later PR-field steps
unconditionally resumed writes after a comment-only fallback. Both sequences now finish canary field/comment read-backs before further creations;
then finish each story's approved field/comment writes before the next. Unsupported PR fields retain their links in restricted comments;
failed or mismatched writes still stop for reconciliation. Field edits preserve existing rich text and links, and mandatory CORENET points remain required.

Fresh October 7 create metadata again returns 81 ACM and 21 CORENET fields; CORENET's PR and Original story points fields remain absent at creation.
Both sampled Story edit-metadata reads expose the PR field with `set` only. The installed CLI still offers default comment visibility without a restriction flag.
New issues require their own metadata and actual canary read-backs; this review performed no create, comment, field edit or transition.
All story/epic payload blocks, posted records and historical inventories remain unchanged.

## First-batch readiness audit

The focused October 7 audit re-reads 34 full issue documents and complete histories (three comments total), including the research, all 27 implementation
subtasks, parent epic and adjacent Prow/image/release scope. CORENET-7171 remains In Progress with the same two May comments and ten changelog events;
its Browse/Add Comments permissions and restricted-group membership are confirmed. The two existing comments use the required group visibility.
CORENET-7086 still has exactly the research plus 27 implementation subtasks; all implementation issues remain To Do with no comments.

All 27 were created May 20 after the research comments; the draft now dates that fact instead of implying recent implementation work.
CORENET-7196/7197/7198 and the unchanged linked proposal at `723f6f4f683bc19cb72b0cb7c13c7821e501c3f1` explicitly specify post-merge workflows on push to main.
The comment describes their scope and release-note suggestions without claiming a new approval, implemented workflows or research completion.
Prepared ADF matches the exact draft, links six issue references, sets the required initial visibility and validates against the [published Atlassian schema](https://go.atlassian.com/adf-json-schema).
One restricted comment is ready for review; parent comments, fields, status transitions and new issues remain outside this batch. No Jira write was performed.

## Documentation validation

The grouping, final review and second review pass full `make test` and commit lint. Current validation covers full repository checks, 148 relative links/anchors across all 25 Markdown files changed by the PR, exact 76-issue queue coverage, historical inventory totals, posted text/links/visibility and whitespace. Pending payloads are revised independently of the four fixed posted blocks; original acceptance criteria and dated evidence limits are retained. Dated Jira/PR/permission evidence still requires target-specific refresh before a write.
No release/test implementation changed. Raw Jira exports remain outside this checkout; local validation logs are untracked.
