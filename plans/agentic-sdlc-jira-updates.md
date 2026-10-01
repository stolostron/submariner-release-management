<!-- markdownlint-disable MD013 -->

# Plan: bring the agentic-SDLC Jira epics up to date

Status: prepared, nothing has been changed in Jira. Prepared 2026-09-30; refreshed later the same day (section A10).

This one plan covers two epics of the agentic-SDLC effort. The parts are independent: each has its own preflight, execution order and verification, and either can be
done without the other.

| Part | Epic | Project | What it tracks |
| --- | --- | --- | --- |
| A | ACM-39728 "Submariner Sustenance Automation" | ACM | Release, CVE and tooling automation for Submariner |
| B | CORENET-7155 "Create agents to automate the bump" | CORENET | The k8s-rebase plugin for Kubernetes minor-version rebases |

Rules that apply to both parts:

* Nothing here has been posted or edited in Jira; every payload is exact text to post after the preflight passes.
* Conventions differ by project. ACM and CORENET use different Activity Type choices, and CORENET automation requires story points and a sprint before a story can leave
  the To Do state; each part lists its own field ids.
* This is a public repository: no teammate names, no Product Security tracker details, no internal links. Jira keys appear in these files only; they must not appear in the
  titles, bodies or commit messages of pull requests (project rule). Jira comments may link to GitHub, not the reverse.
* Create one item first as a canary and read it back before creating the rest; there is no tool here to delete an issue.

Exact text to post, all under [agentic-sdlc-jira-updates-payloads/](agentic-sdlc-jira-updates-payloads/):

| Part | File | Content |
| --- | --- | --- |
| A | [new-stories.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/new-stories.md) | Five new child stories with fields, description, acceptance criteria, progress comment |
| A | [comments-existing.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/comments-existing.md) | Comments for four existing stories and an epic summary |
| A | [epic-description-edits.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/epic-description-edits.md) | Five independent old-to-new edits to the epic description |
| A | [shipyard-audit-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/shipyard-audit-prs.md) | 113 PRs of the Glasswing shipyard-audit remediation, live state |
| A | [cve-fix-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/cve-fix-prs.md) | 43 CVE-related PRs since 2026-09-13 |
| A | [ec-tekton-prs.md](agentic-sdlc-jira-updates-payloads/submariner-sustenance/ec-tekton-prs.md) | 33 Enterprise Contract and Tekton task PRs since 2026-09-13 |
| B | [epic-and-stories.md](agentic-sdlc-jira-updates-payloads/k8s-rebase/epic-and-stories.md) | The epic description (currently empty) and five child stories with fields and progress comments |
| B | [epic-comment.md](agentic-sdlc-jira-updates-payloads/k8s-rebase/epic-comment.md) | A summary comment for the epic |

## Part A: Submariner Sustenance Automation (ACM-39728)

The epic is ACM-39728, the Submariner part of the company-wide agentic SDLC effort. It was last updated 2026-09-16 (description) and 2026-09-13 (comments). Most of what has
shipped since is not recorded on it. Scope of Part A is this epic and its children; release-tracker hygiene and other Jira items are listed at the end but not planned in
detail.

### A1. Current state of the epic and its children (read 2026-09-29)

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

### A2. What is missing

All numbers are for 2026-09-13 to 2026-09-30 unless stated, and are reproducible with the commands in section A8.

1. **PRs #109 and #110 of this repo** (94 files +11,280/-2,115, and 12 files +954/-10) are not recorded anywhere. They contain four separate deliverables with no story:
   OCP major-version FBC onboarding, Enterprise Contract deny-rule detection, Claude/Codex portability, and one-command RPM lockfile setup. The autorelease
   hardening part belongs on ACM-39731.
2. **The Glasswing shipyard-audit remediation.** A Glasswing AI-SAST audit of shipyard produced 22 findings. The tracker lists 113 PRs, all by the maintainer:
   shipyard 65, lighthouse 16, subctl 16, submariner 8, submariner-operator 8. 105 are merged (2026-08-20 to 2026-09-14) and 8 are open FIND-006 drafts gated on
   prerequisites. A search of Jira by Glasswing label and by text for shipyard found no issue for this audit. (Separate, unrelated to this plan: Product Security
   has tracker issues for a Glasswing audit of the shipped product images; those belong to other engineers, are all closed, and are not touched here.)
3. **CVE remediation:** 40 CVE PRs across the seven submariner-io repos (23 merged, 17 superseded), 3 lint-only reverts, and 259 Vulnerability issues moved to
   Closed by the maintainer. ACM-39729 was last commented on 2026-09-04.
4. **Enterprise Contract and Tekton task fixes:** 33 PRs (32 merged), which motivated the deny-rule detection.
5. **Stale numbers in the epic description:** 56 scripts and 337 tests versus 51 scripts, 29 test files and over 1,100 tests today.

6. **cve-agent work was unrecorded and unpushed (now a PR).** The maintainer's claude-skills repository (public) had 5 commits on main, all after 2026-09-13
   (2026-09-22 to 2026-09-25), that improve cve-agent: verify shipped applicability and image provenance; fix the subctl source repo and the RHACM 2.13 CoreDNS
   shipped version; allow fixed, scan_limitation and source_fix together in validate-triage check 4b; fix a multi-arch digest false positive in the verify and
   closure-gate prompts; update the Go version table. They were ahead of origin by 5 commits, so they existed only on one machine. They have since been validated against the shipped images and opened as
   <https://github.com/dfarrell07/claude-skills/pull/35> (2026-09-30). ACM-39729 has no mention of them (its last update was 2026-09-04 and its PR links stop at claude-skills#27 from July).
7. **Enterprise Contract policy work outside the component repos.** release-engineering/rhtap-ec-policy#268 (created 2026-08-27, merged 2026-08-31, "Add Submariner 0.24 to network
   policy RBAC exceptions") and submariner-operator#4222 (opened and closed on 2026-08-27, NetworkPolicy RBAC for an EC rule, apparently replaced by the policy exception) are part of the 0.24.1 EC compliance effort and are not on
   any story. They fit the evidence for new story S2.
8. **Not worth new stories, already covered by release trackers:** 4 release-YAML PRs in this repo (#95, #100, #101, #105), 12 FBC-repo PRs (Tekton bumps,
   bundle additions for 0.24.1 and 0.23.2, a docs fix), and the upstream "Advancing release" PRs. No action.

#### Epic-period totals (2026-08-04, the day the epic was created, to 2026-09-30)

335 PRs by the maintainer across 12 repositories: 290 merged, 32 closed (mostly superseded by a later PR) and 13 open. Theme counts are by PR title and
approximate; the audit-series count is exact (from the tracker).

| Theme | PRs | Merged | Open | Closed |
| --- | --- | --- | --- | --- |
| Glasswing shipyard-audit remediation | 113 | 105 | 8 | 0 |
| Enterprise Contract and Tekton | 73 | 63 | 1 | 9 |
| CVE fixes | 68 | 49 | 0 | 19 |
| Release steps (version labels, bundle SHAs) | 27 | 26 | 0 | 1 |
| Release tooling (this repository) | 21 | 18 | 0 | 3 |
| Glasswing follow-up (CI helper pods) | 9 | 8 | 1 | 0 |
| RPM lockfile updates | 8 | 8 | 0 | 0 |
| FBC catalog and pipelines | 6 | 5 | 1 | 0 |
| Upstream release PRs | 4 | 4 | 0 | 0 |
| Other (open shipyard#2582 and submariner#4191; merged rhtap-ec-policy#268) | 3 | 1 | 2 | 0 |
| Reverts of lint-only changes | 3 | 3 | 0 | 0 |

Other sources checked: the konflux-release-data clone has no commits by the maintainer on origin/main since 2026-08-04 (as of the last successful fetch, head
2026-09-18; GitLab merge-request state cannot be queried from here), so the three local-only OCP 5.0 commits are the only work there. Two open GitHub issues
filed by the maintainer relate to the audit's prerequisites: shipyard#2633 (upgrade CI broken on release-0.22 after the dapper-base rebuild) and shipyard#2635
(deploy-latest installs the wrong minor version for the upgrade test); they are mentioned in the S5 progress comment.

Beyond PRs, the period also has direct commits: 5 to cve-agent in claude-skills (now PR claude-skills#35, see item 6) and, earlier in the period, the cve-fix skill refactor in
shipyard (2026-08-13).

Nothing else from the 107 PRs opened in the period needs a new home: version-label updates (10), RPM lockfile updates (4) and bundle SHAs (1) are steps of the
release trackers, which already track them.

### A3. Decisions to make before executing

1. **Story split.** Recommended: five separate stories (payloads provided), because each is a distinct deliverable with its own status. Fewer stories is possible;
   merge S2 and S3 into one first.
2. **Status of finished stories.** Recommended: Resolved (transition id 131), matching the release-tracker subtasks the tooling already resolves. Closed (61) is the alternative.
   Both transitions show a screen and need a resolution.
3. **Activity Type.** Copied from siblings: Future Sustainability for S1, S3, S4; Security & Compliance for S2 and S5.
4. **0.23.2 (decided 2026-09-30).** It will not ship downstream; it is superseded by 0.23.4, which is in progress. Edit 3 of the epic description drops it, and no 0.23.2 release tracker is needed.
5. **Sprint.** Leave unset (the only open sprint is past its end date), or add the stories to Submariner Sprint 2026-58 (id 85613).

### A4. Preflight (do all of these, and stop on any surprise)

1. Re-read ACM-39728 and its ten children. Confirm the table in section A1 still holds, especially statuses, and that no child was created or changed since 2026-09-30.
2. Confirm the description snippets in epic-description-edits.md still match exactly once each.
3. Re-run the section A8 commands and confirm the counts in the payloads (105/8, 113, 40, 33, and 110 since 2026-09-13) still hold; update the payload text if not.
4. Confirm #109 and #110 are still merged and 0ed2981 is on main. Also check #112, #113 and #114 (section A11): update the comments-existing.md payload if #114 has merged or changed.
5. Confirm the maintainer's answers to section A3 (the 0.23.2 question is already answered).

### A5. Execution order

Order matters: create stories first, then comments that reference them, then the epic edits last. Each step is verified before the next.

1. **Canary: create story S4** (RPM lockfile setup) using the exact fields in new-stories.md. Suggested call shape:
   `createJiraIssue` with `projectKey: ACM`, `issueTypeName: Story`, `summary`, `description` (markdown), `contentFormat: markdown`, `assignee_account_id`,
   `parent: ACM-39728`, and `additional_fields: {components: [{id: "33720"}], priority: {id: "10002"}, customfield_10464: {id: "10606"}}`.
   Read it back with `getJiraIssue` (fields `*all`) and check: parent/Epic Link is ACM-39728, component 33720, Activity Type, priority, the description renders with its
   italic headings and bullets. If `parent` is rejected for an epic child, set `customfield_10014: "ACM-39728"` instead.
2. **Canary: Git Pull Request field.** Set `customfield_10875` on S4 to the #110 URL and read it back. The existing values are Jira smart links, so confirm the format
   round-trips before touching any existing story. If it does not, use comments only.
3. Create S1, S2, S3, S5 with the same shape. Record the new keys.
4. Post each new story's progress comment (visibility group "Red Hat Employee"). Then set the Git Pull Request fields as in new-stories.md.
5. Transition finished stories (S2, S3, S4) to Resolved with resolution Done; leave S1 and S5 In Progress (transition 71).
6. Add the `Related` link (link type id 10077) from S1 to ACM-45508.
7. Post the four existing-story comments in comments-existing.md, replacing `<S1>` to `<S5>` with the real keys. Optionally append the #109 link to the
   Git Pull Request field of ACM-39731 and ACM-39730 (append, never replace, and only after step 2 passes).
8. Apply the epic description edits, verifying by re-reading after each.
9. Post the epic summary comment.

### A6. Verification and rollback

* After each write, read the issue back and compare to the payload. Do not batch writes without reading back.
* New issues and comments can be corrected or removed in Jira afterwards (comments can be edited by id with `addCommentToJiraIssue` and `commentId`).
  There is no tool here to delete an issue, so a mistaken story would need to be closed manually. That is why one story is created first as a canary.
* The epic description has an issue history in Jira that can restore the previous text; keep a copy of the original before editing.
* Do not put Jira keys in the titles or bodies of upstream GitHub PRs (project rule); Jira comments may link to GitHub, not the reverse.

### A7. Deliberately out of scope for this pass

These came up while exploring and are not part of the aSDLC update. They may be worth doing separately.

* **cve-agent commits:** now PR dfarrell07/claude-skills#35 (section A2, item 6). Once it is merged, link it from the ACM-39729 comment (an optional bullet for that is in
  comments-existing.md). One finding from validating it is not in that PR: the addon's configured binary path in component-modules.json (`/usr/local/bin/submariner`) does not
  exist in the image; the binary is at `/submariner`, so the govulncheck step silently skips the addon.
* Related Jira items found while searching, not part of this epic: ACM-26999 (older story "Implement plugin/workflow/tools for CVEs management", New, under
  ACM-26990) overlaps ACM-39729 and could be linked as Related or closed as superseded; ACM-45318 (migrate to ART golang builders, due 2026-10-15) will touch the
  same Dockerfiles and Tekton pipelines.
* Release-tracker hygiene: ACM-40644 (0.24.1) has all 15 subtasks Resolved or Closed and the release is finished, but the parent is still In Progress;
  ACM-45077 (0.22.2 bundle SHAs) is still In Progress although its PR merged 2026-09-24 (its parent 0.22.2 tracker ACM-45070 and EC subtask ACM-45075 are also still In Progress); ACM-44532 (0.23.4 EC compliance) was In Progress after the fixes merged
  2026-09-29; EC was verified passing on 2026-09-30 and it is now Resolved (section A11); ACM-34592 is stale under the closed 0.21.3 release.
* ACM-45470 and ACM-45476 (containers to grade B, deadline 2026-09-30): the Tekton, EC and RPM lockfile PRs are relevant evidence.
* Unpushed local work worth backing up: three commits in the konflux-release-data clone with the OCP 5.0 tenant and admission changes (no merge request yet),
  and the local Glasswing tracker repository under go/src/submariner-io (no remote).
* Open PRs to decide on: shipyard#2618 (devel fix for the CI helper pods; the backports merged) and the eight FIND-006 drafts.

### A8. How the numbers were produced

```bash
# PRs by the maintainer since the epic's last update (107 when first written, 110 at the refresh)
gh search prs --author dfarrell07 --created ">=2026-09-13" --limit 1000 --json repository,number,title,state,url

# Glasswing shipyard-audit PRs: the tracker lists 113 URLs; state of each from the API
grep -oE 'https://github.com/[^ ]+/pull/[0-9]+' glasswing-pr-links.txt | sort -u
gh api repos/<owner>/<repo>/pulls/<n> --jq '[.merged, .state, .created_at, .base.ref]'

# Jira: Vulnerability issues the maintainer closed since 2026-09-13
project = ACM AND issuetype = Vulnerability AND status changed TO Closed AFTER "2026-09-13" AND assignee = currentUser()

# Repo size on main
git ls-tree -d --name-only origin/main skills/ | wc -l
git ls-tree -r --name-only origin/main scripts | grep -E '\.(sh|py)$' | wc -l
```

Do not use a full-text `gh search prs "FIND-"` to count the audit PRs: it is a fuzzy search and matches unrelated PRs from years earlier.

### A9. Corrections made while preparing this plan

Recorded so nobody repeats them.

* An earlier count of "100 Glasswing PRs, 91 merged and 9 open, Aug 19 to Sep 17" came from a fuzzy text search and was wrong. The tracker-based count is 113 PRs,
  105 merged and 8 open, created Aug 19-20 and merged Aug 20 to Sep 14.
* The eight open FIND-006 PRs are intentional drafts gated on prerequisites, not stale duplicates.
* ai-helpers#617 and shipyard#2582 are already linked on ACM-39738 and ACM-39729; they do not need a new home.
* The Activity Type for these stories is Future Sustainability or Security & Compliance, not the option the release-tracker script uses.
* A `/retest` comment on a commit retriggers the build pipelines, not only the integration tests. To re-run just the tests, label the snapshot `test.appstudio.openshift.io/run=<scenario name>`
  (a label, not an annotation). Both are in the Konflux docs; the first attempt at this used the wrong one.

### A10. Refresh (2026-09-30, later the same day)

Re-read Jira and GitHub after the plan was written. The payloads and the execution order are unchanged; these are the differences and additions.

**Numbers.** The maintainer's PRs since 2026-09-13 are now 110, not 107 (added: claude-skills#35, this plan's PR #111, and submariner-operator#4284). The epic still has
exactly the ten children of section A1, and neither epic ACM-39728 (last updated 2026-09-16) nor ACM-39729 (2026-09-17) has been touched since, so preflight step A4.1 should still
pass. The count of 259 closed Vulnerability issues is unchanged.

New since the plan was written:

* submariner-operator#4284 ("Update bundle SHAs for 0.23.4") merged 2026-09-30. The 0.23.4 tracker (ACM-44527) has version labels, RPM lockfiles, CVE fixes and Tekton
  updates Resolved; EC compliance (ACM-44532) is In Progress; bundle SHAs (ACM-44534) is still New although its PR merged, and QE testing (ACM-44539, a teammate) is In Progress.
  This is the same hygiene pattern as ACM-45077 and is worth one line in the tracker cleanup, not a story.
  (Superseded on 2026-10-01: those 0.23.4 statuses were reconciled against live state; see section A11.)
* stolostron/submariner-operator-fbc#82 (OCP 5.0 Konflux pipelines) is open, rebased on merged #81, with every GitHub check passing except the Konflux
  `submariner-fbc-5-0-on-pull-request` PipelineRun, which failed. The run was not found on the cluster this session logs in to, so the cause is unknown. It matters for S1: its progress
  comment lists #82 as open, and S1 should stay In Progress until that pipeline passes (this is already the plan's recommendation).
* submariner-io/releases#1444 (the ACM-39733 upstream agentic release PR, owned by a teammate) is active again: CodeRabbit requested changes on 2026-09-10, 09-21 and 09-24
  (the stale bot also marked it stale twice), and the owner re-requested a review on 2026-09-30. It is not the maintainer's work; the ACM-39733 line in section A1 should not
  claim progress for it.
* claude-skills#35 (cve-agent) is still open with no reviews. This plan's own PR #111 has no reviews yet and only self-approval from the bot; nothing in it is blocked by checks.

Improvements to make when executing:

1. **Do not describe ACM-39733 as the maintainer's work.** Its comment, if any, belongs to the assignee; leave it out of comments-existing.md (it already is) and mention it only in the epic summary as
   in-progress upstream work.
2. **Link the two ai-helpers children.** A one-line comment on ACM-39740 pointing at claude-skills#35 once merged is cheaper and more accurate than adding it to ACM-39729 alone; ACM-39729
   keeps the hardening narrative. Add both to the optional bullet in comments-existing.md.
3. **Fold tracker hygiene into one pass.** Six tracker items need a status decision (ACM-40644, ACM-45077, ACM-45075/45070, ACM-44534, ACM-44532, ACM-34592). Do it with
   `/autorelease <version> --close` for finished releases rather than by hand, after S1 to S5 exist.
4. **Timing.** The grade-B deadline stories (ACM-45470, ACM-45476, owned by teammates) end today. Their evidence is the Tekton, EC and RPM lockfile PRs in section A2; post that evidence as a comment
   on ACM-45476 today if the maintainer wants it counted, since it is independent of everything else in Part A.
5. **Preflight A4.3 counts** should read 110 PRs (not 107) when re-run.

### A11. Refresh (2026-10-01): the 0.23.4 retarget, release-tooling fixes, and an open blocker

Written after running the 0.23.4 release for two days. Payloads and execution order are unchanged except the two additions to comments-existing.md noted below. Nothing here has been posted to Jira beyond status
comments and subtask updates on the 0.23.4 release tracker (ACM-44527).

**New PRs, after the A10 refresh.** Not in the PR counts above; GitHub's search API was rate limited when this was written, so the total was not recomputed (re-run the A8 command; expect at least five more).

| PR | State | What |
| --- | --- | --- |
| stolostron/submariner-release-management#112 | merged 2026-09-30 | `release-status` reads release YAMLs from origin/main as well as the working tree (it said "No stage release YAML" and listed the wrong next steps from another branch); the FBC release gate counts `BuildPLRInProgress` as passing; Step 11 checks the catalog on main, not the previous release's snapshot |
| stolostron/submariner-release-management#113 | merged 2026-09-30 | pre-commit `make test` about 290 s to about 35 s: one test left `gh` unstubbed (about 9 s of live GitHub lookups per call, 181 s total, result dependent on GitHub state), and the hook now runs make in parallel via `MAKEFLAGS` |
| stolostron/submariner-release-management#114 | open, CI green | "do not redo upstream work that is already done": once the upstream tag exists, CVE fixes and the upstream release are not repeated on a retarget, re-release or retry; Tekton task updates only when Enterprise Contract fails. Docs, skills, and `release-status`/`autorelease` messages (no more "rescan" or `--refresh` hints for CVE fixes after the tag) |
| stolostron/submariner-operator-fbc#83 | merged 2026-09-30 | `update-bundle.sh` accepts `BuildPLRInProgress` as passing, as the release gate now does |
| stolostron/submariner-operator-fbc#84 | merged 2026-09-30 | replaces bundle 0.23.2 with 0.23.4 in the catalogs (OCP 4.14 to 4.21; 0.23.x is not in 4.22 or 5.0) |

**0.23.4 tracker (ACM-44527) reconciled against live state.** The A10 note on bundle SHAs, EC and QE is out of date. After the 0.23.2 to 0.23.4 retarget the subtask statuses and the newest step records
disagreed with each other and with reality. Checked against the cluster and GitHub and fixed: component stage release (the release succeeded), release notes (present in the applied release), bundle SHAs, EC
and version labels are now Resolved with matching step records; QE testing was reset to New (nothing has gone to QE for 0.23.4; the In Progress status was left over from the 0.23.2 round); the parent's key
artifacts and the stage, notes and FBC subtask descriptions no longer say "pending". FBC catalog update stays In Progress. Worth a follow-up in the tooling: a retarget leaves stale step records, and the
parent description's key artifacts are never updated by any script.

**Open: 0.23.4 FBC stage releases are blocked.** The component stage release succeeded and the catalog change is merged, but the FBC operator integration test fails on all six push snapshots (OCP 4.16 to
4.21), so the release gate correctly refuses them and step 12 cannot run.

* **What fails.** The `get-unreleased-bundle` step cannot pull `registry.redhat.io/redhat/redhat-operator-index:v4.21` (`failed to fetch anonymous token ... 401 Unauthorized`, then "Make sure you have
  ImagePullCredentials for registry.redhat.io"). The bundle is never installed, so this is not a bundle or catalog defect. Re-running the 4-21 test the documented way (label the snapshot) fails
  identically 29 hours later, so it is persistent.
* **Why.** The tests run as the `konflux-integration-runner` service account. Per the Konflux docs, only component-image registry secrets are linked to it automatically; credentials for any other registry
  must be linked by hand. The live pod mounts 18 pull secrets and none has a `registry.redhat.io` entry. The tenant already has a valid one (`submariner-konflux-registry-redhat-io`), linked to all 72 build-pipeline
  service accounts, and the builds that use it succeeded; it is simply not linked to the integration runner.
* **What this test actually does (new, from reading the pipeline and helper code).** The passing push runs took 126 to 325 seconds (PR-event runs take about 21 seconds, a real cluster install would take far longer),
  i.e. they ran `get-unreleased-bundle` to completion and stopped. Every later task (cluster provisioning, operator install) only runs when that step returns a bundle. It returns none for this tenant: the
  scenario passes `CHANNEL_NAME=stable`, no catalog has a channel with that name (they are `stable-0.22`, `stable-0.23`, `stable-0.24`), so the helper finds no matching bundle and the step exits as a
  no-op. So the "operator" scenario has only ever verified that the fragment parses and that the production index can be rendered; it has not installed anything. Restoring registry access should make it
  pass again in about two to three minutes; it will not add install coverage. (The OCP 5.0 onboarding doc already says new overlays use the package default channel so the install actually runs, and those need
  the OpenShift CI cluster profile as well.)
* **Platform history (integration-service, local clone and GitHub).** `konflux-integration-runner` was introduced for integration pipelines in July 2025; since June 2026 the controller also creates it if missing,
  with one default pull secret (`components-namespace-pull`, component-image registry only). Nothing in that code links any other registry's credentials, matching the docs (manual link required). No commit
  from 2026-09-01 to 2026-10-01 touches this; the nearby changes are nudging, new component API groups and e2e hardening. A search of issues in `tekton-integration-catalog`, `konflux-test`,
  `integration-service` and `build-definitions` for this error found nothing, and `konflux-test` (pinned v1.4.48) has no baked-in registry credentials.
* **Ruled out.** All nine operator scenarios (4-14 to 4-22) are identical, with the same pipeline (`deploy-fbc-operator/0.1` via a git resolver on `main`) and params; 4-22 only looks healthy because it has had
  no push since 2026-09-24, so there is no new result for it. `registry.redhat.io` has always required authentication (anonymous token requests return 401 for every repository), so there is no policy change to
  blame. Upstream has not changed in a relevant way (the step action not since February; the pipeline's only recent change, 2026-09-23, was Slack task references, before the last pass on 2026-09-24).
  No tenant secrets were created or deleted after 2026-09-15, the service account has no dangling secret references, and the tenant config in konflux-release-data has no commit touching it after 2026-09-04
  (the local clone is from 2026-09-18; the fetch needs VPN).
* **Unexplained.** Every push test through 2026-09-24 rendered the production index successfully (that is what the 126 to 325 second runs show) without credentials on that account, yet an anonymous render
  fails now and `registry.redhat.io` has always required authentication. Candidates, none verified: (a) a platform-level credential (cluster-wide pull secret, or secret linking by a platform controller)
  that was applied to these pods before and no longer is; (b) registry access that depended on where the cluster's traffic came from and no longer does. Nothing found in this tenant, in
  `konflux-release-data` (stale local clone), or upstream shows which, or when it changed. The old passing runs are in the cluster archive, reachable only through the Konflux UI with a browser session; a log of a
  passing run (for example the 2026-09-24 operator test) would settle it.
* **Options, none applied.** (1) `oc secrets link konflux-integration-runner submariner-konflux-registry-redhat-io` (the documented manual step), then re-label the snapshots; a live change, reversible with
  `oc secrets unlink`. (2) Make it permanent in konflux-release-data: other tenants there declare `ServiceAccount` manifests with `secrets:` lists, but this account is created and also edited by the
  integration-service controller, so how the GitOps apply merges the two must be checked first. (3) Ask the Konflux platform team why the account lost access, with the log lines above.
  Not applicable: an auth parameter on the scenario; no version of `deploy-fbc-operator` has one, and all 41 scenarios in konflux-release-data use the same pipeline.
* **Related, not yet explained:** the open OCP 5.0 pipelines PR (stolostron/submariner-operator-fbc#82, A10) has a failing Konflux PR pipeline; it may or may not share a cause, since PR-event runs skip the
  cluster install that fails here.

**Payload additions.** Two optional bullets in comments-existing.md: the #112 to #114 and FBC PRs on ACM-39731, and a one-line retarget-hygiene note on ACM-39730.

## Part B: k8s-rebase automation (CORENET-7155)

The epic is CORENET-7155, "Create agents to automate the bump". It covers the k8s-rebase plugin built for the openshift-eng/ai-helpers marketplace. Prepared from a read of
the epic, related CORENET issues, the GitHub pull request, the maintainer's downstream PRs and the local clone of the plugin. Payloads are in
[agentic-sdlc-jira-updates-payloads/k8s-rebase/](agentic-sdlc-jira-updates-payloads/k8s-rebase/).

### B1. What the epic looks like today (read 2026-09-30)

* CORENET-7155, Epic, In Progress, assigned to the maintainer, reporter a CoreNet teammate. Created 2026-05-19, updated 2026-09-29. Priority Normal, Activity Type
  Product / Portfolio Work, no components.
* **Description: empty. Child issues: none.** It is in the active sprint "CORENET Sprint 295" and earlier sprints 289 to 294.
* Six comments, all between 2026-06-04 and 2026-06-12: a link to the work-in-progress branch and its results, progress on other repos, links to the first automated PRs, and a
  discussion of one dependency issue with a teammate.
* Git Pull Request field: openshift-eng/ai-helpers#617.
* Linked (link type "Account") to CORENET-6983, the Kubernetes 1.36 rebase epic for the CoreNet repos (Release Pending), most of whose stories are assigned to CoreNet teammates. CORENET-7062
  under it, the ovn-kubernetes-mcp bump, was assigned to the maintainer and closed on 2026-07-24 because the agent's PR merged.

### B2. What has happened since, and is not recorded

All figures were checked on 2026-09-30; commands are in section B8.

1. **The plugin grew into a full workflow.** At plugins/k8s-rebase in openshift-eng/ai-helpers: 134 tracked files and about 20.9k lines. The README describes a state machine
   above the agent: scripts do repeatable work, the agent repairs, and 32 verification gates decide when a step may advance. Five steps plus rules, 13 scripts, hooks, four docs
   (design, compatibility, repair patterns, Kubernetes 1.37), 240 test functions in about 5.0k lines of tests, and 16 evaluation cases.
2. **Development history:** 43 local backup branches, `k8s-rebase-skill-bak0` (2026-05-31) to `bak42` (2026-09-25); 29 are pushed to the maintainer's fork, including bak41 and bak42.
3. **The upstream PR:** openshift-eng/ai-helpers#617, opened 2026-07-13, draft, 127 files, +15,774/-17, a single squashed commit (the bak41 state, 2026-09-18), 175 reviews
   (85 by CodeRabbit, 83 by the author, 7 by a teammate), labels `do-not-merge/work-in-progress`, `do-not-merge/invalid-owners-file` and `needs-ok-to-test`.
4. **A week of newer work that is not on the PR:** 69 commits from 2026-09-22 to 2026-09-25 (10, 35, 23 and 1 per day), 90 files, +7,799/-2,641. By area: gates
   (32 files), tests (13 files, +4,181), scripts (12 files), evals (11 files), docs, skills, plus removal of obsolete plans. Themes from the commit messages: never pass or skip a
   gate that did not run; retain complete verification evidence; isolate eval runs and keep interrupted-run evidence; verify vulnerability coverage against resolved module graphs;
   resolve every OpenShift module at the target minor; and Kubernetes 1.37 preparation and validation against the published 1.37.1 patch.
5. **Real-world runs:** 6 "Automated rebase to K8s 1.36.2" PRs on 2026-06-09/10 (ovn-kubernetes-mcp#57 merged, five closed), and 108 draft PRs from the maintainer's fork against
   five upstream repositories on 2026-07-16 to 2026-07-23, all closed: cloud-network-config-controller 26, ingress-node-firewall 23, multus-cni 22, ovn-kubernetes-mcp 22,
   cluster-network-operator 15.
6. **A reviewer question:** on 2026-09-08 a reviewer on the PR asked whether the plugin has any eval, cost estimation or model measurement, and pointed at a shared eval harness that
   other marketplace plugins use. It has not been answered on the PR.

### B3. Things to know before touching Jira

* **Work only on this machine:** 7 uncommitted files in the plugin clone (`git status` shows modified gates, scripts, a step doc and two test files; +113/-17). Nothing else is at
  risk: the 69 newer commits are backed up on the fork as bak42.
* **The PR is stale:** its head is 69 commits behind the maintainer's latest work.
* **The 108 July draft PRs:** they were opened against upstream `openshift/*` and `ovn-kubernetes/*` repositories (bots such as CodeRabbit commented on them, one reported its
  review limit was reached) and closed. This is a factual note, not a judgement; consider whether future qualification runs should target the fork instead.
* **CORENET automation** requires original story points and a sprint before a story can move to In Progress, Code Review or Closed (see the payload file for field ids).
* **Project rule:** no Jira keys in the titles, bodies or commit messages of PRs in the public repositories. Jira comments may link to GitHub, not the reverse.

### B4. Decisions to make first

1. **Story split.** Recommended: five stories (plugin, qualification runs, evals, Kubernetes 1.37, upstreaming). Fewer is possible; merge K3 into K1 first.
2. **Story points** for each story (the automation needs a value; CORENET-7062, a one-repo bump, used 1). Placeholders in the payload file.
3. **Sprint:** add the stories to the active "CORENET Sprint 295" (recommended, the epic is already in it), or another.
4. **Status of the qualification story (K2):** Closed with resolution Done (recommended: the 1.36.2 runs are complete), or leave open while 1.37 runs continue.
5. **How to describe the 108 July PRs.** The payload calls them qualification runs; adjust if that is not how you want them presented.
6. **Whether K4 should wait for a real 1.37 rebase** before being created.

### B5. Preflight (stop on any surprise)

1. Re-read CORENET-7155 and confirm it still has no description and no children, and that nobody added stories since 2026-09-30.
2. Re-run the section B8 commands and confirm the counts (69 commits, 108 draft PRs, 43 backup branches, 175 reviews).
3. Confirm the maintainer's answers to section B4, and commit or back up the 7 uncommitted files so the numbers in comments stay true.
4. Confirm the story-point scale and the sprint id with the team.

### B6. Execution order

1. Set the epic description (payload: epic-and-stories.md, "Epic CORENET-7155"). Read it back.
2. Create story K1 first as a canary, with the exact fields. Read it back and check parent and Epic Link, Activity Type, priority, story points, sprint, and that the description
   renders with its italic headings. If the parent field is rejected for an epic child, set `customfield_10014` instead.
3. Create K2 to K5. Post each progress comment. Set Git Pull Request where given.
4. Add a `Related` link (link type id `10077`) from K2 to CORENET-7062.
5. Transition: K1, K3, K4, K5 to In Progress (transition `71`); K2 to Closed with resolution Done. The automation needs points and a sprint first.
6. Post the epic summary comment (epic-comment.md) with the real story keys.

### B7. Verification and rollback

* Read each issue back after writing and compare with the payload before continuing.
* Comments can be edited afterwards by id; there is no tool here to delete an issue, which is why one story is created first as a canary.
* The empty epic description has nothing to restore; if the new text is wrong, edit it again.

### B8. How the numbers were produced

```bash
# in the plugin clone (openshift-eng/ai-helpers, branch k8s-rebase-skill)
git rev-list --count 7e1aa060..HEAD                      # 69 commits after the PR head
git diff --shortstat 7e1aa060 HEAD                       # 90 files, +7,799/-2,641
git for-each-ref 'refs/heads/k8s-rebase-skill-bak*' | wc -l          # 43
git branch -r | grep -c 'dfarrell_ai/k8s-rebase-skill-bak'           # 29 on the fork
git ls-files plugins/k8s-rebase | wc -l                              # 134 tracked files
git status --porcelain | wc -l                                       # 7 uncommitted files

# the upstream PR
gh pr view 617 --repo openshift-eng/ai-helpers --json additions,deletions,changedFiles,reviews,labels
gh api --paginate repos/openshift-eng/ai-helpers/pulls/617/reviews --jq '.[].user.login' | sort | uniq -c

# the maintainer's downstream PRs
gh search prs --owner openshift --author <me> --created ">=2026-05-01" --json repository,number,title,state,createdAt
```

### B9. Corrections made while preparing this plan

* An early reading suggested the 69 newer commits were unpushed. They are on the maintainer's fork as bak42; only the 7 uncommitted files exist solely on the local machine.
* The epic was expected to have child issues and a description; it has neither, so the plan creates the children and writes the description.
