<!-- markdownlint-disable MD013 -->

# Comments for existing ACM-39728 stories and the epic (exact payloads)

Nothing here has been posted. All comments use visibility `{"type": "group", "value": "Red Hat Employee"}`, as the existing comments do.
Existing-story comments are independent of creating new stories; post only missing deltas after target-specific preflight.
The epic summary uses `<S1>` to `<S5>` and must wait for the reviewed stories and real keys.

Historical counts retain their September cutoff; current issues and PRs were re-read October 7. The retarget note is from October 1. Re-read the target stories and follow the plan's preflight before posting; replace placeholders and update dates with any refreshed counts.

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

make test reports over 1,100 shell assertions and Python test cases across its suite summaries (the epic description recorded 337 tests). Coverage includes failure injection for checkout and worktree restoration; this aggregate is not a count of unique test functions.
```

Optional second comment, after the Sep 30 to Oct 1 work (#114 was still open on Oct 6; refresh its state before posting):

```text
Fixes found while retargeting the 0.23.x release (0.23.2 never shipped; now 0.23.4):

* https://github.com/stolostron/submariner-release-management/pull/112 — release-status read only the checked-out branch and gave wrong next steps from any other branch; the FBC release gate rejected `BuildPLRInProgress`, which push snapshots keep after a passing run; Step 11 now checks the catalog on main
* https://github.com/stolostron/submariner-release-management/pull/113 — pre-commit `make test` from about 5 minutes to about 35 seconds (a test hit live GitHub on every call, and the hook now runs make in parallel)
* https://github.com/stolostron/submariner-release-management/pull/114 — open proposal as of 2026-10-07: do not redo CVE fixes or the upstream release once the upstream tag exists; Tekton task updates only when Enterprise Contract fails; update the status tool and conductor messages to match
* https://github.com/stolostron/submariner-operator-fbc/pull/83 and https://github.com/stolostron/submariner-operator-fbc/pull/84 — catalog update accepts `BuildPLRInProgress`; 0.23.2 replaced by 0.23.4
```

## ACM-39730 (Agentic downstream release tracking in Jira)

```text
Tracker fix since the last update: https://github.com/stolostron/submariner-release-management/pull/109 sets the Activity Type field on the tracker parent and its subtasks at creation, addressing the missing-Activity-Type warning. Other required fields and project automation still need verification when a tracker is created.

The tracker is in use for the current Z-streams: ACM-45070 (0.22.2) and ACM-44527 (0.23.4).

Retargeting a tracker (0.23.2 to 0.23.4) leaves step records and subtask statuses that disagree with each other and with the release; on 0.23.4 they were reconciled by hand against the cluster and GitHub. A retarget command that does this, and fills in the parent's key artifacts (no script updates them), is a follow-up.
```

## ACM-39736 (Release knowledge transfer to team)

No comments exist yet. Keep it factual; the story is still New and needs a second engineer.

```text
Prerequisites for another engineer to drive a release are now in place:

* https://github.com/stolostron/submariner-release-management/pull/110 (merged 2026-09-29): one-command setup for the RPM lockfile step's Red Hat entitlements and registry login, using the team's shared credentials, so a new releaser does not need a personal activation key. Relate the setup story if it has been created.
* https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): worktree and branch safety so a release run does not clobber a teammate's checkout, add-team-member hardening, and skills usable from Claude or Codex. Relate the discovery/compatibility story if it has been created.

Still needed for this story's acceptance criteria: at least one other engineer completing a full downstream release using the skills and docs, and the gaps they hit written down.
```

## ACM-39729 (Harden autonomous CVE remediation)

Existing comments: 2026-09-04. The Git Pull Request field already lists shipyard#2443, claude-skills#27 and shipyard#2582 (open).

```text
CVE remediation since the last update (2026-09-13 to 2026-09-30):

* 40 CVE-fix PRs across admiral, cloud-prepare, lighthouse, shipyard, subctl, submariner and submariner-operator on release-0.22, release-0.23 and release-0.24: 23 merged, 17 closed without merging. Plus 3 merged reverts of lint-only changes. Full list: plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/cve-fix-prs.md in stolostron/submariner-release-management.
* 259 Vulnerability issues moved to Closed by the maintainer in the same period (Jira: status changed to Closed by the maintainer during September 13–30, currently assigned to the maintainer; rechecked 2026-10-06).
* The skill hardening for the ai-helpers contribution is still open in https://github.com/submariner-io/shipyard/pull/2582.
```

Optional additional ACM-39729 bullet, after checking for an existing update:

```text
* https://github.com/dfarrell07/claude-skills/pull/35 merged October 6: shipped-image applicability and provenance, source/version mapping, mixed triage outcomes and multi-architecture digest handling. The separate ai-helpers contribution remains ACM-39740 scope.
* https://github.com/submariner-io/shipyard/pull/2582 remains open at 56e7233ad0db33023378e85d0d42aba1129c5ff5. Returned checks pass/skip but review disposition remains changes requested. Two local follow-ups now end at 36afbd1eca881a326ae6b948a096b273bfab59cf in a clean checkout, including OpenShift branch/order-independent arguments. They remain outside the published PR; their reported checks were not repeated here.
```

Use the independent [contribution parent/child comments](../portfolio-comments.md) for ACM-39738/39739/39740.
Their source merges are prerequisites; both children still require ai-helpers merges, and ACM-39740 requires non-Submariner product validation.
Do not duplicate the same optional maintenance paragraphs on each issue.

## ACM-39732: optional progress on the existing URL-conversion story

This is not an additional story or part of the four required comments. Re-read the issue and candidate source before posting:

```text
A fork-only implementation candidate exists at 3cabf0e1f7526d3ef554571ffbb0a95db33bf013 (scripts/update-fbc-prod-urls.sh plus wiring/tests); no PR for its branch was found on October 7. It is not shipped on main and has not been executed by this planning audit.

Before preparing it for review, replace the all-OCP-success assumption, isolate the working tree and preserve unrelated/untracked work, distinguish prod URL conversion from selecting a newer bundle snapshot, and keep completion behind the existing verifier. Reconcile its deferred-next-release wording with the conductor's linear per-release closeout. Current assessment: plans/current-work.md in stolostron/submariner-release-management. Keep this existing story New or move it only after agreeing its actual work/status; no transition is implied here.
```

## ACM-39728 (epic): summary comment

```text
Update for 2026-08-04 to 2026-09-30 at 05:00 UTC, reconstructed and verified on 2026-10-06. The sweep recorded 335 PRs by the maintainer across 12 repositories (290 merged, 32 closed without merging, 13 open); the largest groups are the Glasswing shipyard-audit remediation (113), Enterprise Contract and Tekton fixes (74) and CVE fixes (about 68). Theme membership other than the audit series is classified by PR title and repository; the inventory records each assignment. Shipped and ongoing work is tracked in new child stories:

* <S1> Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft): stolostron/submariner-release-management#109 merged; stolostron/submariner-operator-fbc#81 merged and #82 open. Not finished: konflux-release-data changes and real builds and install are unverified.
* <S2> Detect Enterprise Contract deny rules during Tekton task updates: #109.
* <S3> Deliver shared Claude/Codex skill discovery and compatibility contract: #109. Five known konflux-ci-fix debt entries and installed-host validation remain.
* <S4> One-command setup for RPM lockfile prerequisites: #110 merged.
* <S5> Remediate Glasswing shipyard audit findings: September inventory of 113 PRs (105 merged); all eight FIND-006 drafts closed without merging on October 3. Their finding needs a disposition, and coordinated upgrade-test repair PRs shipyard#2654/subctl#1944 remain open.

Existing stories updated: ACM-39731 (autorelease hardening), ACM-39730 (tracker), ACM-39736 (ownership transfer prerequisites), ACM-39729 (CVE remediation, 40 PRs and 259 issues).
```
