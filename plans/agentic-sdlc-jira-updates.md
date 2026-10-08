<!-- markdownlint-disable MD013 -->

# Plan: bring the agentic-SDLC Jira epics up to date

**Release priority:** [recover the failing FBC integration tests](fbc-failure-recovery.md). Planning and independent deadline work can proceed while recovery prerequisites are resolved.

Status: first four approved existing-story comments posted and verified October 7 at 18:23 UTC; group 1 CI correction posted and verified at 22:59 UTC; lifecycle status comment posted and verified October 8 at 09:37 UTC; release recovery-map comment posted and verified at 10:43 UTC. Epic edits, new stories and remaining comments are pending. Prepared 2026-09-30; broad evidence refreshed 2026-10-07, lifecycle target/receipt and release-evidence batch refreshed 2026-10-08.
The [current work map](current-work.md) records the latest Jira, PR and local-work checks, corrections and next actions.
In particular, the eight FIND-006 drafts are now closed without merging, and real local Kubernetes 1.37 qualification work exists.

The tables, counts, sprint choices and local-work observations are dated snapshots, not a live release-status report. Jira was re-read on
2026-10-07. October 7 tenant reads succeeded during the earlier audit; they confirm missing prerequisites but not credential usability or release success. Re-read state before executing the plan. The release-tracker changes described
in A11 were a separate operation; they did not apply these payloads.

The [verification record](agentic-sdlc-jira-updates-verification.md) lists the source checks, corrected claims and remaining execution gates.

The [assigned-issue update queue](jira-update-queue.md) covers all assigned work and identifies which issues need comments, edits, closure review or no action. This execution plan covers two epics of the agentic-SDLC effort. The parts are independent: each has its own preflight, execution order and verification, and either can be
done without the other.

| Part | Epic | Project | What it tracks |
| --- | --- | --- | --- |
| A | ACM-39728 "Submariner Sustenance Automation" | ACM | Release, CVE and tooling automation for Submariner |
| B | CORENET-7155 "Create agents to automate the bump" | CORENET | The k8s-rebase plugin for Kubernetes minor-version rebases |

Rules that apply to both parts:

* The first four existing-story comments, group 1 CI correction, lifecycle status comment and release recovery-map comment are posted, with verified ids in A5. Other payloads remain pending; post only newly approved missing deltas.
* An existing-issue comment must add a missing delivery, blocker/evidence, specific correction or answer to an explicit request. Keep audit instructions and repeated criteria in the plan; omit parent rollups that only repeat children. New-story comments establish their evidence baseline. Creating child tracking does not itself warrant an epic comment; propose one only for a separate missing decision, delivery or blocker.
* Link each relevant delivery or blocker PR directly in the comment, with its merged/open/draft state. Use a linked PR inventory for large batches. Convert URLs to clickable ADF link nodes and verify rendered text and links on read-back; PR-field edits remain a separate action. Append only missing approved links to PR fields, preserving existing text and links.
* The proposed ACM and CORENET stories use different Activity Type values. CORENET automation warns about original story points before In Progress/Code Review
  and a sprint before In Progress/Code Review/Closed; each part lists its own field ids.
* These are proposed text payloads, not raw Jira REST requests. Jira Cloud descriptions, comments and the Git Pull Request field use Atlassian Document Format (ADF).
  Use a client that converts Markdown to ADF, or construct valid ADF explicitly; never send a bare Markdown string where an ADF document is required.
* Read [project/Story create metadata](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/) with `GET /rest/api/3/issue/createmeta/{projectIdOrKey}/issuetypes/{issueTypeId}` (paginate), and target transitions with `GET /rest/api/3/issue/{issueIdOrKey}/transitions?expand=transitions.fields`. Confirm writable fields, allowed values and required resolution fields. The October 7 action audit read both projects' complete Story create metadata, permissions and 21 existing targets' edit/transition metadata. Re-read new canaries after creation; existing issue metadata does not establish a new issue's workflow. See the [field verification](agentic-sdlc-jira-updates-verification.md#field-and-infrastructure-evidence).
* This is a public repository: no teammate names, no Product Security tracker details, no internal links. Jira keys appear in these files only; they must not appear in the
  titles, bodies or commit messages of pull requests (project rule). Jira comments may link to GitHub, not the reverse.
* Read complete comment histories with pagination; an issue view can contain only the first 100 comments. Preserve exact ADF and link targets alongside rendered text.
* Run the preflight checks relevant to the approved group, refreshing its targets, mutable claims and field prerequisites. Preserve pinned historical evidence at its recorded cutoff.
* Approval covers only the named actions in the approved group. Story creation, field edits and status transitions need their own explicit scope; creation does not authorize later resolution.
* If a write times out or its result is uncertain, stop and reconcile Jira before retrying. Check returned ids, complete comments, or matching stories under the intended parent; do not assume a failed response means no write occurred.
* Before each field edit, save its current value and compare it again immediately before writing. Stop on a changed baseline. Roll back only if the field still equals this operation’s written value; otherwise reconcile later edits before restoring anything.
* Before creating the rest, read back one canary story per project, including its approved field setup and restricted progress comment. Confirm PR-field support before writing; if unsupported, retain its PR links in the comment and omit that field edit. A failed or mismatched write stops the batch for reconciliation. Existing-issue comments and independent description edits need their own target preflight, not a new story. Issue deletion is outside this plan.
* Set comment visibility to group `Red Hat Employee` in the create request and verify it on read-back. Current `acli jira workitem comment create` exposes only project-default visibility and no restriction flag; use REST or a supported UI that sets the group in the initial request. If the client cannot set that visibility at creation,
  stop and use a supported client/UI; do not publish an unrestricted comment and restrict it afterward.

Exact text to post, all under [agentic-sdlc-jira-updates-payloads/](agentic-sdlc-jira-updates-payloads/):

| Part | File | Content |
| --- | --- | --- |
| A | [new-stories.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/new-stories.md) | Five new child stories with fields, description, acceptance criteria, progress comment |
| A | [comments-existing.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/comments-existing.md) | Four posted existing-story comments and an optional URL-conversion draft |
| A | [epic-description-edits.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/epic-description-edits.md) | Five independent old-to-new edits to the epic description |
| A | [shipyard-audit-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/shipyard-audit-prs.md) | 113 PRs of the Glasswing shipyard-audit remediation, state read 2026-09-30 |
| A | [cve-fix-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/cve-fix-prs.md) | 43 CVE-related PRs since 2026-09-13 |
| A | [ec-tekton-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/ec-tekton-prs.md) | 33 Enterprise Contract and Tekton task PRs since 2026-09-13 |
| B | [epic-and-stories.md](agentic-sdlc-jira-updates-payloads/k8s-rebase/epic-and-stories.md) | The epic description (currently empty) and five child stories with fields and progress comments |

## Part A: Submariner Sustenance Automation (ACM-39728)

The epic is ACM-39728, the Submariner part of the company-wide agentic SDLC effort. It was last updated 2026-09-16 (description) and 2026-09-13 (comments). Most of what has
shipped since is not recorded on it. Part A covers this epic and its children; the [assigned-issue queue](jira-update-queue.md)
covers release-tracker hygiene and other assigned work.

### A1. Current state of the epic and its children (rechecked 2026-10-07)

| Key | Summary | Status | Activity Type | Priority | Has PR links |
| --- | --- | --- | --- | --- | --- |
| ACM-39728 | Submariner Sustenance Automation (epic) | In Progress | Future Sustainability | Undefined | no |
| ACM-39729 | Harden autonomous CVE remediation | In Progress | Security & Compliance | Major | shipyard#2443, claude-skills#27, shipyard#2582 (open) |
| ACM-39730 | Agentic downstream release tracking in Jira | In Progress | Future Sustainability | Major | release-management#89 |
| ACM-39731 | Orchestrate existing release skills into autorelease | In Progress | Future Sustainability | Major | release-management#90-93 |
| ACM-39732 | Create FBC prod URL conversion skill | New | Future Sustainability | Normal | no |
| ACM-39733 | Integrate upstream release into agentic release workflow (assignee: a teammate, not the maintainer) | In Progress | Future Sustainability | Normal | releases#1444 |
| ACM-39734 | Agentic upstream issue and PR triage | New | Future Sustainability | Normal | no |
| ACM-39735 | Evaluate AI-assisted bug fixing | New | Future Sustainability | Normal | no |
| ACM-39736 | Release knowledge transfer to team | New | Future Sustainability | Major | no |
| ACM-39737 | Start PIA approval for automated customer log analysis | New | Security & Compliance | Minor | no |
| ACM-39738 | Contribute Submariner skills to openshift/ai-helpers | New | Future Sustainability | Major | ai-helpers#617 |

ACM-39735 is unassigned and ACM-39737 belongs to a teammate. ACM-39738 has two children not listed above: ACM-39739 (go-fix-cves) and ACM-39740 (generalized CVE agent), both New, last touched 2026-09-17; the cve-agent PR (claude-skills#35) is relevant to ACM-39740.

Child stories carry the component "Multicluster Networking[ext]" (id 33720), assignee the maintainer unless noted, and the Epic Link field.

### A2. Work to record

| Destination | Evidence and acceptance boundary |
| --- | --- |
| Existing ACM-39729/39730/39731/39736 | CVE tooling and September remediation; tracker fixes; merged conductor hardening and open #114; shared prerequisites; multiple releasers and feedback remain required for knowledge transfer |
| Existing ACM-39738/39739/39740 | Parent covers all generally relevant skills; reconcile that inventory. Open shipyard#2582 and merged cve-agent#35 do not meet either child's ai-helpers merge criterion; ACM-39740 also requires another product's validation |
| S1 | OCP-major FBC onboarding: release-management#109 and FBC#81 merged; pipeline #82 and configuration/build/install/release gates remain. Relate existing OPGM-364 lifecycle work and ACM-45508 addon consumption without claiming their acceptance criteria |
| S2 | Delivered EC deny-rule detection, supported by #109 and the EC/Tekton inventory |
| S3 | Delivered Claude/Codex discovery and compatibility contract; five known overlapping konflux-ci-fix debt entries and installed-host execution remain |
| S4 | Delivered RPM prerequisite setup in #110; multiple team members completing releases and feeding back gaps remain ACM-39736 work |
| S5 | Glasswing shipyard audit: September inventory of 113 PRs, 105 merged. Eight FIND-006 drafts closed unmerged October 3; finding disposition and open OCP helper/upgrade repairs remain |

The September inventories retain their original periods: 40 CVE-fix PRs (23 merged, 17 closed unmerged), three lint-only reverts,
33 EC/Tekton PRs (32 merged), and 259 Vulnerability closures by the maintainer during September 13–30.
The reconstructed epic-period inventory stops at **September 30, 05:00 UTC**: 335 PRs across 12 repositories,
290 merged, 32 closed unmerged and 13 open at that cutoff. Categories are heuristic, recorded per entry in
[epic-period-prs.json](agentic-sdlc-jira-updates-payloads/submariner-sustenance/epic-period-prs.json).
These are historical populations, not today's PR or assigned-issue totals. The [verification record](agentic-sdlc-jira-updates-verification.md)
keeps the source pins and discovery limits; [current work](current-work.md) owns current PR, local-work and release observations.

Routine releases, version labels, bundle updates and release notes stay on existing release trackers.
The [update queue](jira-update-queue.md) handles deadline work, older open items, MCN/EVPN work and terminal issues;
no new umbrella story is proposed for them. Full OCP rollout evidence remains in [ocp-5-0-fbc-rollout.md](ocp-5-0-fbc-rollout.md).

### A3. Decisions to make before executing

1. **Story split.** Recommended: five separate stories (payloads provided), because each is a distinct deliverable with its own status. Fewer stories is possible;
   merge S2 and S3 into one first.
2. **Status of finished stories.** Recommended: Resolved, matching the release-tracker subtasks the tooling already resolves. Closed is the alternative.
   Confirm acceptance criteria and the issue's available transition and resolution fields before deciding; merging a PR alone does not establish every acceptance criterion.
   S3 covers the delivered discovery/compatibility contract; five known `konflux-ci-fix` debt entries and the installed-host matrix remain. Do not report every skill as execution-portable.
3. **Activity Type.** Copied from siblings: Future Sustainability for S1, S3, S4; Security & Compliance for S2 and S5.
4. **0.23.2 (decided 2026-09-30).** It will not ship downstream; it is superseded by 0.23.4, which is in progress. Edit 3 of the epic description drops it, and no 0.23.2 release tracker is needed.
5. **Sprint.** Leave unset, or use an active sprint chosen by the maintainer. On 2026-10-06 the existing In Progress siblings include active
   Submariner Sprint 2026-59 (id 87579); Sprint 2026-58 (id 85613) is now closed and must not be used as the active sprint.

### A4. Preflight for approved actions (stop on any surprise)

Use the October 7 [work map](current-work.md) when refreshing payloads: distinguish the closed FIND-006 drafts, open upgrade-test PRs,
known portability debt and time-sensitive builder migration from the September historical counts.

1. Re-read ACM-39728 and its ten children. Compare the table in section A1, especially statuses, child membership, comments and PR links;
   stop and reconcile any new work instead of creating duplicates. Include the two CVE contribution subtasks and search for each proposed deliverable beyond this epic before creation. A sprint update by itself is not evidence that a payload was applied.
2. Before each approved pending epic-description edit, confirm its old snippet or insertion heading occurs exactly once. Reconcile completed edits and omit them; stop on an unexplained difference. Save the current full ADF and update the corresponding nodes, preserving other content and earlier edits.
3. Use section A8 to refresh mutable claims in the approved payload. Retain the verified September inventories and their cutoff; recompute historical totals only to correct or expand that population. If reporting current state, update dates, states and totals together. The 107, 110 and 335 figures are different discovery snapshots, not expected totals for a new search.
4. Confirm #109 and #110 are still merged and 0ed2981 is on main. Also check #112, #113 and #114 (section A11) and claude-skills#35 ([current work](current-work.md#release-tooling-and-jira-payloads)):
   preserve the four posted payloads as historical records. Prepare any newly approved missing delta separately, identifying open work explicitly.
5. Confirm the maintainer's answers to section A3 (the 0.23.2 question is already answered).
6. Reconcile ACM-39738's generally relevant skill inventory with its existing CVE children and CORENET-7155 contribution tracking. Reuse existing issues; propose a subtask only for an uncovered contribution scope.
7. Re-read project create-field metadata and each issue's transition metadata. Confirm the component, Activity Type, priority, assignee, sprint,
   resolution and link type against the current workflow; the read-only review did not exercise any create or transition operation.

### A5. Execution order

Completed first approved chunk: one comment on each existing story, using the [four recorded comments](agentic-sdlc-jira-updates-payloads/submariner-sustenance/comments-existing.md). October 7 full reads found these deltas absent before posting.

| Order | Target | Posted update | Verified status / comment id |
| --- | --- | --- | --- |
| 1 | ACM-39731 | Merged conductor/status hardening, initial teammate adoption and the separate open #114 proposal | In Progress / 18820423 |
| 2 | ACM-39730 | Tracker Activity Type fix, current releases, and the observed retarget/artifact gap | In Progress / 18820431 |
| 3 | ACM-39736 | Teammate adoption of CVE/autorelease tooling and shared prerequisites; full releases and feedback still required | New / 18820438 |
| 4 | ACM-39729 | Verified September counts, initial teammate adoption, merged CVE-agent improvements and open CVE-fix work | In Progress / 18820449 |

All four comments were created on October 7 at 18:23 UTC with restricted visibility set in the initial request; exact ADF text, clickable links, group visibility and unchanged issue statuses were verified after each write. No issue fields or statuses were changed, and no new issues were created. The CVE comment uses refreshed Shipyard head 3b67af1a and its current changes-requested review. For later updates, re-read complete comments and refresh mutable evidence; if a write has an uncertain result, inspect Jira before retrying.

The remaining approval sequence is owned by the [grouped queue](jira-update-queue.md#approval-order); [portfolio drafts](agentic-sdlc-jira-updates-payloads/portfolio-comments.md) follow it. Group 1 is complete: CORENET-7171 comment `18824859`, created October 7 at 22:59 UTC with initial restricted visibility; approved text, rendered links and unchanged In Progress status were verified. OPGM-364 lifecycle comment `18829498` was created October 8 at 09:37 UTC with initial restricted visibility; exact ADF/rendered text, both PR links, unchanged In Progress status and earlier comments were verified. Group 4 is partial; do not repost its lifecycle record. The Release Submariner 0.23.4 recovery-map comment `18830594` was created October 8 at 10:43 UTC with initial restricted visibility; exact ADF/rendered text, its link, unchanged In Progress status and all 90 prior comments were verified. Group 5 is partial; do not repost the recovery map.

Start the remaining sequence with group 2, the two CVE contribution children, then the group 4 builder comment. Group 5’s recovery map is posted; its 0.22.2 candidate comment remains on hold until release relevance is confirmed. Group 3 EVPN is deferred to the end at the maintainer’s request: another planning PR iteration is WIP and CI PRs will start soon. Parent rollups and the older CVE progress comment remain deferred pending a distinct decision or delivery. Engineering priorities proceed in parallel.

Each group requires its own approval and fresh target/evidence read; set restricted visibility at creation and verify text/links/visibility before the next write. Earlier audits and preparation do not authorize posting.

Independent epic descriptions come before new tracking. Ownership/adoption and release-evidence corrections precede optional stale-count cleanup. Preserve original ADF and all links; scope-dependent pipeline/OLMv1 corrections remain gated. When approved, the S-story creation sequence is S4 → S2 → S3 → S1 → S5, keeping the canary first and delivered scopes ahead of unfinished work. K-story creation remains separate. No automatic epic summary is proposed; closure reviews remain separate from progress reporting.

Each creation or field write is read back before the next. Skip completed deltas.

1. **Canary: create story S4** (RPM lockfile setup) using the fields in new-stories.md: ACM Story, the maintainer's account, parent ACM-39728,
   component 33720, priority 10002 and Activity Type 10606. Story create metadata marks reporter required with a default; preserve the approved reporter and verify it on read-back. Use the approved Jira client/UI and its supported description format.
   Read it back and check the parent, fields, italic headings and bullets. If the workflow requires legacy Epic Link instead of `parent`, use
   `customfield_10014` only after create-field metadata confirms that field is writable.
2. **Canary: Git Pull Request field.** Confirm S4's edit metadata and client support before appending the #110 link to `customfield_10875` as ADF.
   Read back the full field and confirm its links and formatting. If unsupported, use the comment-only route; omit subsequent PR-field edits.
3. **Canary: restricted progress comment.** Post S4's progress comment with restricted visibility set at creation. Verify text, clickable links and visibility before creating another story.
4. Create S2, S3, S1, S5 using each story's own fields in new-stories.md. S2 and S5 use Security & Compliance (10609); S3 uses Normal priority (10003).
   Read back each creation and record its key. Complete that story's approved field/comment writes and read-backs before creating the next.
   Append its proposed PR links only if step 2 passed and its own edit metadata confirms support; read back each field. S5 proposes no PR-field edit.
5. Move S1/S5 to In Progress only if those transitions were included in the approved group, using each new issue’s metadata and read-back. Keep S2/S3/S4 in their created status until the separate group-9 acceptance review approves a terminal transition and its resolution; do not resolve them as part of story creation.
6. Add related-issue links from S1 to ACM-45508 (addon consumption) and OPGM-364 (lifecycle publication), using the link type confirmed in preflight. Check for an existing link first and read back each new relationship.
7. The four existing-story updates are already posted (ids above); reconcile their read-backs and post only newly approved missing deltas. Optionally append the #109 link to the
   Git Pull Request field of ACM-39731 and ACM-39730 only after step 2 passes. Re-read the original ADF, add only missing link nodes and set the combined document; the field exposes `set`, not an `add` operation. Verify that every original link survives and stop if the baseline changed.
8. Apply only approved epic description edits not already performed in group 6, verifying each by read-back; omit completed deltas.

### A6. Verification and rollback

* After each write, read the issue back and compare to the payload. Do not batch writes without reading back.
* A supported Jira client/UI can edit or delete comments if the account has permission. Save each created comment id; REST comment updates use the
  [update-comment operation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comments/#api-rest-api-3-issue-issueidorkey-comment-id-put), not add-comment.
  No issue-deletion operation is authorized by this plan; a mistaken story needs a separate disposition decision. That is why one story is created first as a canary.
* Save the full current ADF before each independent description edit. Apply the shared baseline/rollback rule above so earlier approved edits and later changes survive; issue history provides no automatic restore operation.
* Do not put Jira keys in the titles or bodies of upstream GitHub PRs (project rule); Jira comments may link to GitHub, not the reverse.

### A7. Work outside these epic payloads

Use the [assigned-issue queue](jira-update-queue.md) for release closeout, lifecycle publication, builder/PQC/OLMv1 work,
older onboarding/CVE/release items, MCN CI research and EVPN acceptance. It distinguishes review-ready text from blocked status changes.
The addon's configured CVE-agent binary path still needs separate verification: the previous shipped-image audit found `/submariner`,
while component-modules.json configured `/usr/local/bin/submariner`. This finding was not part of merged cve-agent#35;
do not infer complete addon scan coverage from that merge.

### A8. How the numbers were produced

```bash
# Discover PRs created in the September reporting window.
# Review repository and theme membership before counting; this is an author-wide search.
gh search prs --author dfarrell07 --created '2026-09-13..2026-09-30' --limit 1000 --json repository,number,title,state,url

# Discover PRs created since the epic began, up to the same cutoff.
gh search prs --author dfarrell07 --created '2026-08-04..2026-09-30' --limit 1000 --json repository,number,title,state,url

# Glasswing shipyard-audit PRs: the stored list has 113 URLs; state of each from the API.
rg -o 'https://github.com/[^ )]+/pull/[0-9]+' plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/shipyard-audit-prs.md | sort -u
# Substitute owner, repo and n from each URL before running this template.
gh api 'repos/<owner>/<repo>/pulls/<n>' --jq '[.merged, .state, .created_at, .base.ref]'

# Historical repo-size audit baseline (not today's main).
git ls-tree -d --name-only 0ed2981 skills/ | wc -l
git ls-tree -r --name-only 0ed2981 scripts | rg '\.(sh|py)$' | wc -l
```

Jira discovery query for Vulnerability issues the maintainer closed during the reporting window:

```jql
project = ACM AND issuetype = Vulnerability AND status changed TO Closed BY currentUser() DURING ("2026-09-13 00:00", "2026-09-30 23:59") AND assignee = currentUser()
```

GitHub search returns current states; a closed result does not distinguish merged from closed without merging. Read each pull request's `merged` field
with the API before classifying it. The 107 and 110 searches were taken at different times on September 30; a date-bounded query now can include PRs
created later that day. The 335-PR inventory is now included, with an explicit 05:00 UTC cutoff. A full September 30 query also finds later PRs, so filter
creation and lifecycle timestamps to that cutoff before comparing totals. The bounded JQL above returned 259 issues on 2026-10-06,
matching the original unbounded `AFTER` query; no private issue export is included. Run it as the maintainer, or substitute that account for `currentUser()`.

Do not use a full-text `gh search prs "FIND-"` to count the audit PRs: it is a fuzzy search and matches unrelated PRs from years earlier.

### A11. Release retarget and current handoff

The 0.23.2 release was superseded by 0.23.4. On September 30/October 1 a separate operation reconciled ACM-44527's stale
step records, subtask statuses and artifact descriptions against cluster/GitHub evidence. Those tracker writes did not apply these epic payloads.
Merged release-management#112/#113 and FBC#83/#84 are evidence for the existing ACM-39731 comment;
release-management#114 remains an open proposal and is absent from main.

The October 7 issue sweep still finds the two epics In Progress, ten direct ACM children and no CORENET children/description.
Current release blockers and separate local configuration drafts are in [current work](current-work.md),
with registry repair in [fbc-failure-recovery.md](fbc-failure-recovery.md).
The earlier successful tenant read confirms an unlinked registry Secret and missing OCP 5 Application/Component/build account;
no retained PipelineRuns were returned. It does not establish credential validity, installation, QE or publishing.
The October 8 read retains all six failed FBC [snapshot/scenario associations](fbc-failure-recovery.md#retained-snapshot-and-scenario-identities). The recorded component-stage Release is now NotFound; its archived October 7 successful verdict remains evidence. Verify intended catalog content/credentials before any authorized rerun; component-stage success does not complete FBC. GitLab fresh-base access remains unverified after the earlier DNS failure.

## Part B: k8s-rebase automation (CORENET-7155)

The epic is CORENET-7155, "Create agents to automate the bump". It covers the k8s-rebase plugin built for the openshift-eng/ai-helpers marketplace. Prepared from a read of
the epic, related CORENET issues, the GitHub pull request, the maintainer's downstream PRs and the local clone of the plugin. Payloads are in
[agentic-sdlc-jira-updates-payloads/k8s-rebase/](agentic-sdlc-jira-updates-payloads/k8s-rebase/).

### B1. What the epic looks like today (rechecked 2026-10-07)

* CORENET-7155, Epic, In Progress, assigned to the maintainer, reporter a CoreNet teammate. Created 2026-05-19, updated 2026-09-29. Priority Normal, Activity Type
  Product / Portfolio Work, no components.
* **Description: empty. Child issues: none.** It is in the active sprint "CORENET Sprint 295" and earlier sprints 289 to 294.
* Six comments, all between 2026-06-04 and 2026-06-12: a link to the work-in-progress branch and its results, progress on other repos, links to the first automated PRs, and a
  discussion of one dependency issue with a teammate.
* Git Pull Request field: openshift-eng/ai-helpers#617.
* Linked (link type "Account") to CORENET-6983, the Kubernetes 1.36 rebase epic for the CoreNet repos (Release Pending), most of whose stories are assigned to CoreNet teammates. CORENET-7062
  under it, the ovn-kubernetes-mcp bump, was assigned to the maintainer and closed on 2026-07-24 because the agent's PR merged.

### B2. What has happened since, and is not recorded

The [payload evidence](agentic-sdlc-jira-updates-payloads/k8s-rebase/epic-and-stories.md) and [verification record](agentic-sdlc-jira-updates-verification.md#kubernetes-rebase-evidence)
retain the pinned bak42 development counts and historical PR inventory. Current work is newer and remains outside upstream PR #617.

| Destination | Evidence and remaining acceptance |
| --- | --- |
| K1 | Five-step plugin with gates, hooks and retained-evidence contracts; current source and dirty test changes require qualification |
| K2 | Six June 1.36.2 PRs and 108 July draft PRs; legacy matrix summaries exist, but current per-run archives are missing. Review failure dispositions before closure |
| K3 | Sixteen eval cases and a metrics runner; valid measurements, judge outcomes and an answer to the reviewer's measurement/shared-harness question remain |
| K4 | Real CNCC/Multus/MCP 1.37.1 trials with explicit limits; repaired source and installed runtime need fresh qualification |
| K5 | #617 remains draft with invalid-OWNERS/needs-ok-to-test labels; review the full delta, resolve blockers, obtain approval and merge |

### B3. Things to know before touching Jira

* **Local work:** on October 7 the clone HEAD is at `a477bced687c3385311bafddbf2ae1a3b0228ed0`,
  82 commits after the PR head and 13 after bak42. The fork's `k8s-rebase-skill` ref still points at the PR head; bak42 is backed up, but neither ref includes these 13 newer commits.
  Two test files also have uncommitted court-permission changes. This does not rule out another backup. Preserve and verify both before updating the PR; no plugin files were changed by this audit.
* **The PR is stale:** bak42 contains 69 commits after its head; newer local work exists beyond that verified backup. The October 6 remote read confirms
  that the fork's bak42 ref still points to `febb7974696e870f933e8ad3741605d31ead0b5c`.
* **The 108 July draft PRs:** they were opened against upstream `openshift/*` and `ovn-kubernetes/*` repositories (bots such as CodeRabbit commented on them, one reported its
  review limit was reached) and closed. This is a factual note, not a judgement; consider whether future qualification runs should target the fork instead.
* **CORENET automation** warns about original story points before In Progress/Code Review and a sprint before In Progress/Code Review/Closed (see the payload file for field ids).
* **Project rule:** no Jira keys in the titles, bodies or commit messages of PRs in the public repositories. Jira comments may link to GitHub, not the reverse.

### B4. Decisions to make first

1. **Story split.** Recommended: five stories (plugin, qualification runs, evals, Kubernetes 1.37, upstreaming). Fewer is possible; merge K3 into K1 first.
2. **Story points** for each story (the automation needs a value; CORENET-7062, a one-repo bump, used 1). Placeholders in the payload file.
3. **Sprint:** add the stories to the active "CORENET Sprint 295" (recommended, the epic is already in it), or another.
4. **Status of K2:** In Progress pending its own 1.36.2 acceptance review. Recover per-target qualification and failure dispositions, or agree explicit limits; the July PR inventory and legacy PASS summaries do not justify closure. K4's 1.37 work has separate criteria.
5. **July inventory:** report 108 closed draft PRs. Do not equate one PR with one independently qualified run; source/gate/result evidence is separate.
6. **K4 acceptance boundary.** Real local CNCC, Multus and initial MCP 1.37.1 candidates now have recorded workflow evidence, with explicit limits.
   CNCC needs fresh qualification after a helper attribution correction; Multus has two inconclusive gates and unchanged vulnerability findings.
   MCP records three FAIL/two INCONCLUSIVE gates, incomplete lint and live CI selecting 1.36.4; its lessons commit needs separate fresh qualification.
   Keep K4 In Progress until its agreed acceptance criteria pass; the September assertion that no real rebase exists is superseded.

### B5. Preflight for approved actions (stop on any surprise)

1. Re-read CORENET-7155 and its children. Reconcile any description or stories with recorded approved writes; omit completed actions and stop on unexplained differences. The empty-description/no-child audit baseline may have changed through an earlier approved group.
2. Refresh current PR/run claims used by the approved payload. Section B8 records the historical counting method; retain the verified bak42 snapshot and its dates. Refresh dates and counts together when reporting current work; do not expect mutable HEAD or review totals to equal the historical snapshot.
3. Confirm the maintainer's answers to section B4. Refresh local source/backup observations used by the approved payload and record unfinished qualification or backup gaps as blockers.
4. Confirm the story-point scale and the sprint id with the team.
5. Re-read Story create metadata and available transitions. The October 7 metadata exposes `parent`, not legacy Epic Link, on CORENET creation; Original story points and Git Pull Request require later edits. `Related` is currently link type 10077. Confirm the new canary's edit metadata and rich-text handling before continuing.
6. Reconcile K2/K4 qualification scope with existing delivery epics CORENET-6983 and CORENET-7450 and their children. K stories qualify the plugin; they do not recreate repository bumps or change those other-owned delivery issues.

Before authorized plugin changes or publication, preserve and verify committed and dirty work. Before fresh qualification, freeze the intended source, compare loaded skill/hook bytes and retain the original trial budgets/reports. These engineering actions require their own scope; Jira tracking can record the unfinished work.

### B6. Execution order

The epic description is an independent group-6 edit after its own scope/ADF review; it needs no new story keys. The sequence below handles approved K-story creation. Omit an already-applied description delta.

1. Create K1 as a canary with writable create fields: `parent` CORENET-7155, its own Activity Type/priority, approved Story Points and sprint, assignee and description. Verify the default/approved reporter on read-back. CORENET create metadata does not expose legacy Epic Link, Original story points or Git Pull Request; do not send those fields in the create request. Read back membership and rendered content.
   Fetch K1 edit metadata, then set approved Original story points and read it back. Existing Story edit metadata supports that field, but the new canary must confirm it. Do not transition to In Progress until it is set and verified; do not silently omit the automation prerequisite.
2. Append K1's PR link only after its edit metadata confirms support; use an ADF-capable client and read back the full field. If the field/client is unsupported, use the comment-only route and omit subsequent PR-field edits.
3. Post K1's progress comment with restricted visibility set at creation. Verify text, clickable links and visibility before creating K2–K5.
   Create each remaining story with its own writable fields; inspect its edit metadata, set Original story points and verify both point fields and sprint. Complete its approved field/comment writes and read-backs before creating the next.
   Append proposed PR links only if K1's field canary passed and that issue's edit metadata confirms support; read back each field. K3/K4 propose no PR-field edit.
4. Add the related-issue link from K2 to CORENET-7062 using the link type confirmed in preflight, and read it back.
5. Transition K1–K5 to In Progress only if included in the approved group, after the approved field setup. A separate K2 closeout requires its own qualification/failure-disposition evidence and the appropriate resolution.
   Read each issue's available transitions, verify points and sprint first, and read each transition back; do not reuse ACM transition ids.
6. Set the approved epic description if still missing (payload: epic-and-stories.md, "Epic CORENET-7155") and read it back.

### B7. Verification and rollback

* Read each issue back after writing and compare with the payload before continuing.
* Comments can be edited by id with a supported client/UI; issue deletion is outside this plan, which is why one story is created first as a canary.
* Save the current description value (empty at this audit). Apply the shared baseline/rollback rule before restoring it, then read it back.

### B8. How the numbers were produced

```bash
# in the plugin clone (openshift-eng/ai-helpers, branch k8s-rebase-skill)
git rev-list --count 7e1aa060..k8s-rebase-skill-bak42     # 69 commits after the PR head
git diff --shortstat 7e1aa060 k8s-rebase-skill-bak42      # 90 files, +7,799/-2,641
git for-each-ref 'refs/heads/k8s-rebase-skill-bak*' | wc -l          # 43
git branch -r | grep -c 'dfarrell_ai/k8s-rebase-skill-bak'           # 29 on the fork
git ls-tree -r --name-only k8s-rebase-skill-bak42 plugins/k8s-rebase | wc -l  # 134 tracked files
git status --porcelain | wc -l                              # current dirty files; 2 at the latest October 7 read

# the upstream PR
gh pr view 617 --repo openshift-eng/ai-helpers --json additions,deletions,changedFiles,reviews,labels
gh api --paginate repos/openshift-eng/ai-helpers/pulls/617/reviews --jq '.[].user.login' | sort | uniq -c

# Discover the maintainer's downstream PRs; include both owners and avoid the default 30-result limit.
gh search prs --owner openshift --owner ovn-kubernetes --author dfarrell07 --created '2026-06-09..2026-07-23' --limit 1000 --json repository,number,title,state,createdAt,url
```

For the 108-PR count, filter the discovery results to July 16–23 and the five repositories in the K2 payload; check each PR's draft and merge history
before calling it a closed qualification draft. Local counts require the original plugin clone and its refs. The October 7 clone HEAD is at `a477bced`; current and historical source must be reported separately. API reads give current PR state,
so the September 30 review count is a dated observation rather than a value guaranteed by a later run.

### B9. Corrections made while preparing this plan

* An early reading suggested the 69 bak42 commits were unpushed. The fork's bak42 ref was verified on October 6. More recent local commits and dirty files require their own backup check.
* The epic was expected to have child issues and a description; it has neither, so the plan creates the children and writes the description.
