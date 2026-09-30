<!-- markdownlint-disable MD013 -->

# Comments for existing ACM-39728 stories and the epic (exact payloads)

Nothing here has been posted. All comments use visibility `{"type": "group", "value": "Red Hat Employee"}`, as the existing comments do. Post them
after the new stories exist (they reference the new keys, shown as `<S1>` to `<S5>` and to be filled in with the created keys).

Style of the existing comments: a one-line intro, then bullet lines of `PR link — short description`. Each is a separate comment.

## ACM-39731 (Orchestrate existing release skills into autorelease)

Existing comments: 2026-09-04 (conductor and refactor PRs, verifier fixes) and 2026-09-13 (PRs 94, 102, 103, 104). This is the next batch.

```text
Autorelease hardening and script fixes since the Sep 13 update, found while using the conductor on real releases:

* https://github.com/stolostron/submariner-release-management/pull/109 — one squashed PR (94 files, +11,280/-2,115, merged 2026-09-29) that replaces the closed drafts #106, #107 and #108:
    * retry the RPM lockfile step when only some repos have a PR yet, and reuse existing release PRs
    * auto-push and open PRs at review stops, falling back to printed commands
    * serialize Tekton task updates
    * preserve and restore dirty worktrees and the original branch around every step; CI also caught a Git 2.43 case where a failed `git stash pop --index` exits 0, which is now detected
    * stricter release-notes review contract with per-issue evidence bundles, and safer resume and apply
    * add-team-member target checks; release root resolved independent of the caller's working directory
    * full OCP identities (4.x and 5.x) carried through release scope, status, snapshot checks and prod-index verification

make test now runs over 1,100 test cases (337 when the epic description was written), including fail-injection cases for every script that touches a user's checkout.
```

## ACM-39730 (Agentic downstream release tracking in Jira)

```text
Tracker fix since the last update: https://github.com/stolostron/submariner-release-management/pull/109 sets the Activity Type field on the tracker parent and its subtasks at creation, so creating a tracker no longer triggers the required-field bot email.

The tracker is in use for the current Z-streams: ACM-45070 (0.22.2) and ACM-44527 (0.23.4).
```

## ACM-39736 (Release knowledge transfer to team)

No comments exist yet. Keep it factual; the story is still New and needs a second engineer.

```text
Prerequisites for another engineer to drive a release are now in place:

* https://github.com/stolostron/submariner-release-management/pull/110 (merged 2026-09-29): one-command setup for the RPM lockfile step's Red Hat entitlements and registry login, using the team's shared credentials, so a new releaser does not need a personal activation key. See <S4>.
* https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): worktree and branch safety so a release run does not clobber a teammate's checkout, add-team-member hardening, and skills usable from Claude or Codex. See <S3>.

Still needed for this story's acceptance criteria: at least one other engineer completing a full downstream release using the skills and docs, and the gaps they hit written down.
```

## ACM-39729 (Harden autonomous CVE remediation)

Existing comments: 2026-09-04. The Git Pull Request field already lists shipyard#2443, claude-skills#27 and shipyard#2582 (open).

```text
CVE remediation since the last update (2026-09-13 to 2026-09-30):

* 40 CVE-fix PRs across admiral, cloud-prepare, lighthouse, shipyard, subctl, submariner and submariner-operator on release-0.22, release-0.23 and release-0.24: 23 merged, 17 closed as superseded by a later PR. Plus 3 merged reverts of lint-only changes. Full list: plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/cve-fix-prs.md in stolostron/submariner-release-management.
* 259 Vulnerability issues moved to Closed by the maintainer in the same period (Jira: status changed to Closed after 2026-09-13, assignee the maintainer).
* The skill hardening for the ai-helpers contribution is still open in https://github.com/submariner-io/shipyard/pull/2582.
```

Optional extra bullet for this comment. The five cve-agent commits were validated and opened as <https://github.com/dfarrell07/claude-skills/pull/35> on
2026-09-30; include the bullet once that PR is merged, linking it:

```text
* cve-agent improvements, 2026-09-22 to 2026-09-25 (https://github.com/dfarrell07/claude-skills/pull/35): verify shipped applicability and image provenance; fix the subctl source repo and the RHACM 2.13 CoreDNS shipped version; allow fixed, scan_limitation and source_fix together in validate-triage check 4b; fix a multi-arch digest false positive in the verify and closure-gate prompts; update the Go version table.
```

## ACM-39728 (epic): summary comment

```text
Update since 2026-09-13. Since the epic was created on 2026-08-04 the maintainer has opened 335 PRs across 12 repositories (290 merged, 32 closed, mostly superseded, 13 open); the largest groups are the Glasswing shipyard-audit remediation (113), Enterprise Contract and Tekton fixes (about 73) and CVE fixes (about 68). Theme counts other than the audit series are by PR title and approximate. Work shipped under this epic since the last update, tracked in new child stories:

* <S1> Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft): stolostron/submariner-release-management#109 merged; stolostron/submariner-operator-fbc#81 merged and #82 open. Not finished: konflux-release-data changes and real builds and install are unverified.
* <S2> Detect Enterprise Contract deny rules during Tekton task updates: #109.
* <S3> Make release skills portable across Claude and Codex: #109.
* <S4> One-command setup for RPM lockfile prerequisites: #110 merged.
* <S5> Remediate Glasswing shipyard audit findings: 113 PRs (105 merged, 8 FIND-006 drafts open).

Existing stories updated: ACM-39731 (autorelease hardening), ACM-39730 (tracker), ACM-39736 (ownership transfer prerequisites), ACM-39729 (CVE remediation, 40 PRs and 259 issues).
```
