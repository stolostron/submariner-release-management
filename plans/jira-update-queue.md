<!-- markdownlint-disable MD013 -->

# Assigned Jira work: update queue

Read-only sweep, October 7, 2026. This is the disposition of the maintainer's assigned issues, not a bulk-posting list.
The [work map](current-work.md) owns current engineering evidence; the [epic plan](agentic-sdlc-jira-updates.md) owns story creation and execution.
Exact additional text is in [portfolio-comments.md](agentic-sdlc-jira-updates-payloads/portfolio-comments.md).
Four approved comments were posted and verified on ACM-39731/39730/39736/39729 on October 7 at 18:23 UTC; their ids are in the epic plan. Remaining actions are pending. Re-read each target and omit anything already recorded before posting.

## Coverage and priority

The unrestricted, paginated `assignee = currentUser()` search returned **703 unique issues across nine projects**:
80 active, 623 terminal. Of these, 483 are Vulnerability issues: four active and 479 terminal.
All 220 other assigned issues were fully re-read, alongside nine related non-Vulnerability issues and the four active private vulnerabilities. The pre-post audit found assigned keys/statuses and inspected full-view update fields unchanged.
The tables below account for **all 76 active non-Vulnerability issues**. Terminal issues default to no update.
The September 13 onward non-Vulnerability update search returned 118 issues, including 53 terminal ones;
an `updated` timestamp alone does not establish new engineering work.

1. Recover existing FBC tests and privately triage the four active vulnerabilities. Neither requires creating the proposed epic children first.
2. Prepare October 15 builder work independently; answer the existing lifecycle-publication status request.
3. Record delivered automation, open contributions and qualification limits on existing issues; review the proposed S/K story split separately.
4. Reconcile older open items and release closeout with artifact evidence; record MCN/EVPN decisions once, on their existing parents.

Private vulnerability keys, issue contents, personal research exports and teammate identities remain outside this public repository.
Full views of the four active vulnerabilities were re-read privately. Per-image/version applicability, fix and closure evidence remain in their existing private workflow.
Neither the historical 259 closures nor a merged tooling PR authorizes closing them. The other 479 need no new bulk comment or transition.

## Submariner automation and contribution issues — 10

| Issue | Proposed update | Completion/status boundary |
| --- | --- | --- |
| ACM-39728 | Apply reviewed description edits independently; post the summary after S stories exist | Keep In Progress; preserve original ADF, verify edits and use real keys in the summary |
| ACM-39729 | Posted comment 18820449: September remediation, merged CVE-agent work, open CVE-fix work and initial teammate adoption | Do not equate tooling merges or issue counts with complete remediation |
| ACM-39730 | Posted comment 18820431: Activity Type fix and observed retarget/artifact gaps | Parent artifact refresh/retarget automation remains a follow-up |
| ACM-39731 | Posted comment 18820423: merged hardening, open #114 and initial teammate adoption | #114 is pending, not shipped |
| ACM-39732 | Record the existing fork-only URL-conversion candidate if useful | New; source/scope reconciliation before a review PR; no additional story |
| ACM-39734 | Defer | No new triage implementation evidence found; avoid an empty progress post |
| ACM-39736 | Posted comment 18820438: initial teammate adoption and shared setup prerequisites | New; multiple team members must each complete a release, with the maintainer not driving; document gaps and feed them into improvements |
| ACM-39738 | Next proposed chunk: parent rollup after the two existing CVE subtask comments, with the broader contribution inventory | New; original acceptance covers all generally relevant skills. Reconcile that inventory; neither two CVE children nor an open plugin PR establishes parent completion |
| ACM-39739 | Next proposed chunk: refresh open shipyard#2582 and configuration progress | New; published a88023ad has running checks, one unresolved current thread and no review/approval on that head. Project-level configuration, no hardcoded Submariner values and its own ai-helpers merge remain required |
| ACM-39740 | Next proposed chunk: source #35 merge, agent/triage configuration gaps | New; per-product configuration, ai-helpers merge and validation on another product’s CVE issues remain. Initial team adoption does not satisfy these criteria |

The first four posted existing-story updates and pending epic text are recorded in
[comments-existing.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/comments-existing.md).
The contribution parent/child comments below are independent of S-story creation. Keep ACM-39733 with its existing owner;
ACM-39735 is unassigned and ACM-39737 belongs to another owner. No status or comment is proposed for those three here.

## Releases — 17

| Assigned issues | Proposed treatment | Evidence needed before changing status |
| --- | --- | --- |
| ACM-40644 | Closure review; all 15 children terminal, parent In Progress | Exact production bundle is verified. Seven 4.16–4.22 index probes timed out and historical Release CRs are NotFound; recover catalog/QE proof and compare all 159 comments before closeout. Neither failure proves absence |
| ACM-44527; ACM-44537, ACM-44538, ACM-44540, ACM-44541, ACM-44542 | One parent blocker/update, then change individual steps only as recovery progresses | Catalog In Progress; stage/prod/URL steps New. Six exact FBC snapshot/scenario associations are recovered, all aggregate Failed; use the recovery map and verify credentials/content before reruns |
| ACM-45070; ACM-45075, ACM-45077, ACM-45078, ACM-45079, ACM-45080, ACM-45081, ACM-45083, ACM-45084, ACM-45085 | Reconcile candidate source/operand identity before accepting EC/bundle and filling parent artifacts | Retained nine-component candidate passes integration with warnings and contains a 0.22.2 bundle. Seven embedded operand digests differ from snapshot operands; registry/content identity remains unverified. EC/bundle stay In Progress; stage onward New |

QE subtasks retain their existing owners and are dependencies, not assigned work in these totals.
ACM-45087/45088 are two extra test subtasks under the 0.22.2 parent; their disposition is separate from release completion.
Do not use broad closeout to resolve them as release deliverables. A tracker close command can change Jira and needs explicit write authorization.

## Deadline, lifecycle and older open work — 8

| Issue | Proposed update | Gate or reason to defer |
| --- | --- | --- |
| ACM-45318 | Brief inventory/progress comment; retain October 15 deadline | Use [builder inventory](art-builder-migration.md); migrate verified Brew/OSBS consumers on approved streams and prove the applicable builds; UBI Go Toolset alone is not evidence of an affected ART builder |
| ACM-41119 | Defer completion; reconcile image coverage with builder work | Addon 5.0 PQC base selection is partial source evidence; main/5.1 differ and shipped-image policy remains unverified |
| ACM-37426 | Coordinated title/description timeline correction using the prepared draft after owner confirmation | Description says ACM 5.0; July comment says 5.1. Prototype manifests exist, with incomplete least-privilege RBAC; preserve that preparation without claiming implementation |
| OPGM-364 | Answer the existing status request with blockers and remaining proof | Lifecycle injection and publication are existing scope. It explicitly forbids adding OCP 5 compatibility statements; a valid catalog/IIB proof is an allowed alternative to public-index membership |
| ACM-25779 | Replace the stale console-specific description with the actual Submariner pipeline scope | Existing May comment already explains ownership-dependent deferral. Do not repost it or treat inline pipelines as an unrecorded failure |
| ACM-26999 | Reconcile older CVE scope/links with ACM-39729/39739/39740 | Existing May comment already says production tooling exists. Link remaining upstream contribution rather than repeat the original delivery; closure/supersession needs a scope decision |
| ACM-34592 | Closure review with existing five PRs | All five directly read PRs merged May 28. Parent ACM-34591 is Closed and the comment asks for closure; review issue criteria and current transition/resolution before resolving |
| ACM-34593 | Closure review of the original build failure | October 2 route-agent push build succeeds at 82adbacd; retained snapshot exists, while its EC scenario fails. Confirm the original DNF/RPM criteria and fix attribution before resolving; EC failure is a separate investigation |

ACM-45508 is a related addon-consumption task owned by another person, not an assigned issue.
Link it from S1 where useful; it does not prove FBC runtime compatibility. OPGM-364 also predates S1:
reconcile/link its lifecycle scope instead of creating another publication story.

## Kubernetes and MCN/EVPN work — 41

| Assigned issues | Proposed update | Gate or reason to defer |
| --- | --- | --- |
| CORENET-7155 | Reviewed description, K-story split and one summary | In Progress, description empty, no children. Recorded 1.37 trials have limits; MCP repair/fresh qualification and upstream PR refresh remain |
| CORENET-7086 | One parent comment linking existing research and implementation subtasks | To Do; the original May draft's "will split into subtasks" is obsolete. It is separate from the Kubernetes plugin |
| CORENET-7171 | Research/recommendation update, then acceptance review | In Progress. Review May recommendations against the original research/rationale deliverable; do not add implementation/ownership requirements to its acceptance. Existing AI subtasks specify post-merge; correct the older PR-review wording |
| CORENET-7173–7199 | Defer individual comments; retain one disposition per existing subtask | All 27 To Do. Existing descriptions cover lint, security, test, coverage, context and AI workflows. Require repository change and meaningful CI evidence for each criterion before any completion claim |
| CORENET-7078, CORENET-7079, CORENET-7080, CORENET-7081, CORENET-7082, CORENET-7083, CORENET-7084, CORENET-7085, CORENET-7087, CORENET-7089 | Defer until repository/build/registry/CI ownership and prerequisites are agreed | All ten To Do under existing MCN scope; source bootstrap, Prow/cloud E2E, image publishing and release automation are distinct deliverables |
| CORENET-7615 | Link merged EVPN planning PR #2 and list unfinished criteria | To Do. Planning #2 and infrastructure #4/#5 merged; source imports remain open. Record decision owners/dates when decisions are made; pending decisions need not all be settled. Conflicts 7501/7504/7505 still lack recorded resolution; source/check work is separate from planning acceptance |

Do not duplicate the 27 CI subtasks from the May research drafts or post the same research list on each one.
Do not close CORENET-7171 solely because the subtasks exist. Do not reuse EVPN or plugin qualification as MCN implementation evidence.
CORENET-7085 and CORENET-7089 have empty descriptions: scope test reuse and release/versioning after repository ownership is agreed.
The parent also requires license-header verification and API compatibility; dependency-license scanning in CORENET-7195
does not satisfy the header criterion, and no named API-compatibility task was found in the 27 descriptions. Reconcile those gaps before parent acceptance.

## Recent work and terminal issues

The author-wide GitHub sweep returned 23 PRs updated since September 30 and 16 currently open PRs, plus five recently updated issues.
Direct reads distinguish merge/closure, current heads, review state and checks. These populations overlap and are not additive.
The important active work is already mapped above or in [current work](current-work.md): release recovery, OCP 5 #82,
conductor #114, CVE #2582, upgrade #2654/#1944, helper pod #2618, addon #2792 and plugin #617.
Open release-management #111 is this planning work, not a shipped automation deliverable.

Older threat-model PR #186 and six personal documentation PRs also remain open. The corresponding assigned threat-model issues are terminal;
no new assigned-issue completion/update is inferred from these stale PRs. Review their remaining purpose separately before any closure action.
The terminal assigned history across ACM, CORENET and seven other projects needs no retrospective progress spam or reopening.
Resolved recent release steps stay as evidence on their parents; routine timestamp changes do not justify reposting the inventory.

## Apply a reviewed update

Re-read the target's description, complete comments, PR field, parent and available transitions; preserve the original rich text.
Post only a missing factual delta, with comment visibility `Red Hat Employee` set at creation and verified on read-back.
Descriptions/PR fields need ADF or a converting client. Read back each write and record its issue/comment id before continuing.
Status reviews are separate from comments and require acceptance evidence, resolution metadata and any project points/sprint requirements. Live metadata confirms required resolution on terminal transitions; the existing closure candidates remain reviews, not approved transitions. CORENET Original story points/PR fields need post-create edits; see the epic plan.
No branch push, PR update, Jira write, cluster change or release is authorized by this planning document.
