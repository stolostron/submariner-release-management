<!-- markdownlint-disable MD013 -->

# Plan: bring the aSDLC epic (ACM-39728) up to date

Status: prepared, nothing has been changed in Jira. Prepared 2026-09-30 from a full read of the epic, its children, GitHub and the local repos.

The epic is ACM-39728, "Submariner Sustenance Automation", the Submariner part of the company-wide agentic SDLC effort. It was last updated
2026-09-16 (description) and 2026-09-13 (comments). Most of what has shipped since is not recorded on it.

The exact text to post is in [plans/asdlc-jira-update-payloads/](asdlc-jira-update-payloads/):

| File | Content |
| --- | --- |
| [new-stories.md](asdlc-jira-update-payloads/new-stories.md) | Five new child stories with fields, description, acceptance criteria, progress comment |
| [comments-existing.md](asdlc-jira-update-payloads/comments-existing.md) | Comments for ACM-39731, -39730, -39736, -39729 and an epic summary |
| [epic-description-edits.md](asdlc-jira-update-payloads/epic-description-edits.md) | Five independent old-to-new edits to the epic description |
| [shipyard-audit-prs.md](asdlc-jira-update-payloads/shipyard-audit-prs.md) | 113 PRs of the Glasswing shipyard-audit remediation, live state |
| [cve-fix-prs.md](asdlc-jira-update-payloads/cve-fix-prs.md) | 43 CVE-related PRs since 2026-09-13 |
| [ec-tekton-prs.md](asdlc-jira-update-payloads/ec-tekton-prs.md) | 33 Enterprise Contract and Tekton task PRs since 2026-09-13 |

Scope of this plan is the aSDLC epic and its children only. Release-tracker hygiene and other Jira items are listed at the end but not planned in detail.

## 1. Current state of the epic and its children (read 2026-09-29)

| Key | Summary | Status | Activity Type | Priority | Has PR links |
| --- | --- | --- | --- | --- | --- |
| ACM-39728 | Submariner Sustenance Automation (epic) | In Progress | Future Sustainability | Undefined | no |
| ACM-39729 | Harden autonomous CVE remediation | In Progress | Security & Compliance | Major | shipyard#2443, claude-skills#27, shipyard#2582 (open) |
| ACM-39730 | Agentic downstream release tracking in Jira | In Progress | Future Sustainability | Major | release-management#89 |
| ACM-39731 | Orchestrate existing release skills into autorelease | In Progress | Future Sustainability | Major | release-management#90-93 |
| ACM-39732 | Create FBC prod URL conversion skill | New | Future Sustainability | Normal | no |
| ACM-39733 | Integrate upstream release into agentic release workflow | In Progress | Future Sustainability | Normal | releases#1444 |
| ACM-39734 | Agentic upstream issue and PR triage | New | Future Sustainability | Normal | no |
| ACM-39735 | Evaluate AI-assisted bug fixing | New | Future Sustainability | Normal | no |
| ACM-39736 | Release knowledge transfer to team | New | Future Sustainability | Major | no |
| ACM-39737 | Start PIA approval for automated customer log analysis | New | Security & Compliance | Minor | no |
| ACM-39738 | Contribute Submariner skills to openshift/ai-helpers | New | Future Sustainability | Major | ai-helpers#617 |

Child stories carry the component "Multicluster Networking[ext]" (id 33720), assignee the maintainer unless noted, and the Epic Link field.

## 2. What is missing

All numbers are for 2026-09-13 to 2026-09-30 unless stated, and are reproducible with the commands in section 8.

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

6. **cve-agent work is unrecorded and not pushed.** The maintainer's claude-skills repository (public) has 5 commits on main, all after 2026-09-13
   (2026-09-22 to 2026-09-25), that improve cve-agent: verify shipped applicability and image provenance; fix the subctl source repo and the RHACM 2.13 CoreDNS
   shipped version; allow fixed, scan_limitation and source_fix together in validate-triage check 4b; fix a multi-arch digest false positive in the verify and
   closure-gate prompts; update the Go version table. They are ahead of origin by 5 commits, so they exist only on this machine and cannot be linked from Jira
   yet. ACM-39729 has no mention of them (its last update was 2026-09-04 and its PR links stop at claude-skills#27 from July).
7. **Enterprise Contract policy work outside the component repos.** release-engineering/rhtap-ec-policy#268 (created 2026-08-27, merged 2026-08-31, "Add Submariner 0.24 to network
   policy RBAC exceptions") and submariner-operator#4222 (opened and closed on 2026-08-27, NetworkPolicy RBAC for an EC rule, apparently replaced by the policy exception) are part of the 0.24.1 EC compliance effort and are not on
   any story. They fit the evidence for new story S2.
8. **Not worth new stories, already covered by release trackers:** 4 release-YAML PRs in this repo (#95, #100, #101, #105), 12 FBC-repo PRs (Tekton bumps,
   bundle additions for 0.24.1 and 0.23.2, a docs fix), and the upstream "Advancing release" PRs. No action.

### Epic-period totals (2026-08-04, the day the epic was created, to 2026-09-30)

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

Beyond PRs, the period also has direct commits: 5 to cve-agent in claude-skills (unpushed, see item 6) and, earlier in the period, the cve-fix skill refactor in
shipyard (2026-08-13).

Nothing else from the 107 PRs opened in the period needs a new home: version-label updates (10), RPM lockfile updates (4) and bundle SHAs (1) are steps of the
release trackers, which already track them.

## 3. Decisions to make before executing

1. **Story split.** Recommended: five separate stories (payloads provided), because each is a distinct deliverable with its own status. Fewer stories is possible;
   merge S2 and S3 into one first.
2. **Status of finished stories.** Recommended: Resolved (transition id 131), matching the release-tracker subtasks the tooling already resolves. Closed (61) is the alternative.
   Both transitions show a screen and need a resolution.
3. **Activity Type.** Copied from siblings: Future Sustainability for S1, S3, S4; Security & Compliance for S2 and S5.
4. **0.23.2 (decided 2026-09-30).** It will not ship downstream; it is superseded by 0.23.4, which is in progress. Edit 3 of the epic description drops it, and no 0.23.2 release tracker is needed.
5. **Sprint.** Leave unset (the only open sprint is past its end date), or add the stories to Submariner Sprint 2026-58 (id 85613).

## 4. Preflight (do all of these, and stop on any surprise)

1. Re-read ACM-39728 and its ten children. Confirm the table in section 1 still holds, especially statuses, and that no child was created or changed since 2026-09-30.
2. Confirm the description snippets in epic-description-edits.md still match exactly once each.
3. Re-run the section 8 commands and confirm the counts in the payloads (105/8, 113, 40, 33, 107) still hold; update the payload text if not.
4. Confirm #109 and #110 are still merged and 0ed2981 is on main.
5. Confirm the maintainer's answers to section 3 (the 0.23.2 question is already answered).

## 5. Execution order

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

## 6. Verification and rollback

* After each write, read the issue back and compare to the payload. Do not batch writes without reading back.
* New issues and comments can be corrected or removed in Jira afterwards (comments can be edited by id with `addCommentToJiraIssue` and `commentId`).
  There is no tool here to delete an issue, so a mistaken story would need to be closed manually. That is why one story is created first as a canary.
* The epic description has an issue history in Jira that can restore the previous text; keep a copy of the original before editing.
* Do not put Jira keys in the titles or bodies of upstream GitHub PRs (project rule); Jira comments may link to GitHub, not the reverse.

## 7. Deliberately out of scope for this pass

These came up while exploring and are not part of the aSDLC update. They may be worth doing separately.

* **At risk of loss (do first):** the 5 unpushed cve-agent commits in the claude-skills repository (section 2, item 6). Pushing them is the maintainer's call; once
  pushed they can be linked from the ACM-39729 comment (an optional bullet for that is in comments-existing.md).
* Related Jira items found while searching, not part of this epic: ACM-26999 (older story "Implement plugin/workflow/tools for CVEs management", New, under
  ACM-26990) overlaps ACM-39729 and could be linked as Related or closed as superseded; ACM-45318 (migrate to ART golang builders, due 2026-10-15) will touch the
  same Dockerfiles and Tekton pipelines.
* Release-tracker hygiene: ACM-40644 (0.24.1) has all 15 subtasks Resolved or Closed and the release is finished, but the parent is still In Progress;
  ACM-45077 (0.22.2 bundle SHAs) is still In Progress although its PR merged 2026-09-24; ACM-44532 (0.23.4 EC compliance) is In Progress after the fixes merged
  2026-09-29 and needs an EC status check; ACM-34592 is stale under the closed 0.21.3 release.
* ACM-45470 and ACM-45476 (containers to grade B, deadline 2026-09-30): the Tekton, EC and RPM lockfile PRs are relevant evidence.
* Unpushed local work worth backing up: three commits in the konflux-release-data clone with the OCP 5.0 tenant and admission changes (no merge request yet),
  and the local Glasswing tracker repository under go/src/submariner-io (no remote).
* Open PRs to decide on: shipyard#2618 (devel fix for the CI helper pods; the backports merged) and the eight FIND-006 drafts.

## 8. How the numbers were produced

```bash
# PRs by the maintainer since the epic's last update (107)
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

## 9. Corrections made while preparing this plan

Recorded so nobody repeats them.

* An earlier count of "100 Glasswing PRs, 91 merged and 9 open, Aug 19 to Sep 17" came from a fuzzy text search and was wrong. The tracker-based count is 113 PRs,
  105 merged and 8 open, created Aug 19-20 and merged Aug 20 to Sep 14.
* The eight open FIND-006 PRs are intentional drafts gated on prerequisites, not stale duplicates.
* ai-helpers#617 and shipyard#2582 are already linked on ACM-39738 and ACM-39729; they do not need a new home.
* The Activity Type for these stories is Future Sustainability or Security & Compliance, not the option the release-tracker script uses.
