<!-- markdownlint-disable MD013 -->

# Comments for existing ACM-39728 stories and the epic (exact payloads)

Nothing here has been posted. All comments use visibility `{"type": "group", "value": "Red Hat Employee"}`, as the existing comments do.
Existing-story comments are independent of creating new stories; post only missing deltas after target-specific preflight.
The epic summary uses `<S1>` to `<S5>` and must wait for the reviewed stories and real keys.

Historical counts retain their September cutoff; current issues and PRs were re-read October 7. The retarget note is from October 1. Re-read the target stories and follow the plan's preflight before posting; replace placeholders and update dates with any refreshed counts.

Style of the existing comments: a one-line intro, then bullet lines of `PR link — short description`. Use one comment per target, combining only the missing sections below.

## ACM-39731 (Orchestrate existing release skills into autorelease)

Existing comments cover the conductor/refactor PRs and September 13 fixes. Refresh the open proposal before posting one comment containing only the missing deltas; this is progress reporting, not a status transition.

```text
Autorelease updates since September 13:

* [release-management#109](https://github.com/stolostron/submariner-release-management/pull/109) (merged September 29): retry/reuse RPM lockfile PRs, serialize Tekton updates, harden checkout restoration and failure checks, strengthen release-note evidence/resume/apply, and add team-onboarding and OCP-major identity handling.
* [release-management#112](https://github.com/stolostron/submariner-release-management/pull/112) (merged): fix cross-branch release status, accept the retained BuildPLRInProgress marker after passing checks, and inspect the Step 11 catalog on main.
* [release-management#113](https://github.com/stolostron/submariner-release-management/pull/113) (merged): parallelize the test hook and remove a repeated live-GitHub lookup from the tests.
* [operator-fbc#83](https://github.com/stolostron/submariner-operator-fbc/pull/83) and [operator-fbc#84](https://github.com/stolostron/submariner-operator-fbc/pull/84) (merged): accept BuildPLRInProgress in catalog updates and retarget 0.23.2 to 0.23.4.
* [release-management#114](https://github.com/stolostron/submariner-release-management/pull/114) remains an open proposal: skip completed CVE/upstream-release work once the upstream tag exists, make Tekton updates conditional on EC failure, and align status/conductor messages. These changes are not on main.

The repository suite reports over 1,100 shell assertions and Python test cases, including checkout/worktree failure injection. This aggregate is not a count of unique test functions.
```

## ACM-39730 (Agentic downstream release tracking in Jira)

```text
Tracker fix since the last update: https://github.com/stolostron/submariner-release-management/pull/109 sets the Activity Type field on the tracker parent and its subtasks at creation, addressing the missing-Activity-Type warning. Other required fields and project automation still need verification when a tracker is created.

The tracker is in use for the current Z-streams: ACM-45070 (0.22.2) and ACM-44527 (0.23.4).

Retargeting a tracker (0.23.2 to 0.23.4) leaves step records and subtask statuses that disagree with each other and with the release; on 0.23.4 they were reconciled by hand against the cluster and GitHub. A retarget command that does this, and fills in the parent's key artifacts (no script updates them), is a follow-up.
```

## ACM-39736 (Release knowledge transfer to team)

No comments exist yet. Keep it factual; the story is still New and requires multiple team members to complete releases.

```text
Shared setup and checkout-safety prerequisites have improved:

* https://github.com/stolostron/submariner-release-management/pull/110 (merged 2026-09-29): one-command setup for the RPM lockfile step's Red Hat entitlements and registry login, using the team's shared credentials, so a new releaser does not need a personal activation key.
* https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): worktree and branch-safety hardening, add-team-member hardening, and shared Claude/Codex skill discovery. Installed-host execution remains separate qualification.

Still needed for this story's original acceptance criteria: multiple team members each complete a full downstream release using the skills and workflow docs, with the maintainer available for questions but not driving. Document their gaps and feed them back into skill/doc improvements. A first volunteer's release is a milestone, not completion of this story.
```

## ACM-39729 (Harden autonomous CVE remediation)

Existing comments: 2026-09-04. The Git Pull Request field already lists shipyard#2443, claude-skills#27 and shipyard#2582 (open).

```text
CVE remediation since the last update (2026-09-13 to 2026-09-30):

* 40 CVE-fix PRs across admiral, cloud-prepare, lighthouse, shipyard, subctl, submariner and submariner-operator on release-0.22, release-0.23 and release-0.24: 23 merged, 17 closed without merging. Plus 3 merged reverts of lint-only changes. [Full PR list](https://github.com/stolostron/submariner-release-management/blob/d094bf36994f5d938f41d4fc305feb93bd896977/plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/cve-fix-prs.md).
* 259 Vulnerability issues moved to Closed by the maintainer in the same period (Jira: status changed to Closed by the maintainer during September 13–30, currently assigned to the maintainer; rechecked 2026-10-06).
* The skill hardening for the ai-helpers contribution is still open in https://github.com/submariner-io/shipyard/pull/2582.
```

Optional additional ACM-39729 bullet, after checking for an existing update:

```text
* https://github.com/dfarrell07/claude-skills/pull/35 merged October 6: shipped-image applicability and provenance, source/version mapping, mixed triage outcomes and multi-architecture digest handling. The separate ai-helpers contribution remains ACM-39740 scope.
* https://github.com/submariner-io/shipyard/pull/2582 is now published at 0777e63c3a429d86624c9302b4f4f01276115ad8, with a clean matching local checkout. Returned hosted checks pass or skip, but the new current-head review requests changes on four current threads; no current-head approval is recorded. The PR reports 1,372 regression checks and focused/live OpenShift validation with explicit limits; those runs were not repeated here.
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

Before posting, replace all keys and reconcile every status/count with the refreshed evidence. Retain the final existing-story update line only for updates confirmed by recorded write ids/read-back or already present in Jira; omit any unperformed update.

```text
Update for 2026-08-04 to 2026-09-30 at 05:00 UTC, reconstructed and verified on 2026-10-06. The sweep recorded 335 PRs by the maintainer across 12 repositories (290 merged, 32 closed without merging, 13 open); the largest groups are the Glasswing shipyard-audit remediation (113), Enterprise Contract and Tekton fixes (74) and CVE fixes (about 68). Theme membership other than the audit series is classified by PR title and repository; the inventory records each assignment. Shipped and ongoing work is tracked in new child stories:

* <S1> Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft): [release-management#109](https://github.com/stolostron/submariner-release-management/pull/109) merged; [operator-fbc#81](https://github.com/stolostron/submariner-operator-fbc/pull/81) merged and [operator-fbc#82](https://github.com/stolostron/submariner-operator-fbc/pull/82) open. Not finished: konflux-release-data changes and real builds and install are unverified.
* <S2> Detect Enterprise Contract deny rules during Tekton task updates: [release-management#109](https://github.com/stolostron/submariner-release-management/pull/109) merged.
* <S3> Deliver shared Claude/Codex skill discovery and compatibility contract: [release-management#109](https://github.com/stolostron/submariner-release-management/pull/109) merged. Five known konflux-ci-fix debt entries and installed-host validation remain.
* <S4> One-command setup for RPM lockfile prerequisites: [release-management#110](https://github.com/stolostron/submariner-release-management/pull/110) merged.
* <S5> Remediate Glasswing shipyard audit findings: September inventory of 113 PRs (105 merged); all eight FIND-006 drafts closed without merging on October 3. Their finding needs a disposition, and coordinated upgrade-test repair PRs [shipyard#2654](https://github.com/submariner-io/shipyard/pull/2654) and [subctl#1944](https://github.com/submariner-io/subctl/pull/1944) remain open.

Existing stories updated: ACM-39731 (autorelease hardening), ACM-39730 (tracker), ACM-39736 (ownership transfer prerequisites), ACM-39729 (CVE remediation, 40 PRs and 259 issues).
```
