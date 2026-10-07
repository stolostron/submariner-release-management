<!-- markdownlint-disable MD013 -->

# Epic description edits for ACM-39728 (exact old and new text)

Nothing here has been applied. The baseline description was read on 2026-09-29 and its original snippets rechecked on 2026-10-07. Every "old" snippet below must match the live
rendered description exactly once; re-read the epic immediately before editing and stop if any snippet has changed. All four old snippets and
the insertion heading still matched once at the 2026-10-07 read. Jira Cloud stores the description as ADF: save the full original document, update
the relevant nodes with a supported client/UI and preserve everything else. The Markdown below is text for that client, not a raw REST field value.
Rollback means writing back the saved original ADF document and verifying it; issue history alone is not an automatic restore operation.

Each edit is independent. Review in order 4 (adoption), 3 (release evidence), 5 (deliverables), then optional metrics edits 1/2. Keep these edit numbers stable; no new story keys are needed.

## Edit 4: release ownership transfer

Old (replace this paragraph under "Release ownership transfer"):

```text
Currently only one engineer can execute downstream releases. The goal is for any team member to be able to pick up a release branch and drive the full downstream release process. The skills and context docs encode the knowledge, but this hasn't been validated yet.
```

New:

```text
The goal is for any team member to be able to pick up a release branch and drive the full downstream release process. Another team member has begun using the CVE and autorelease tooling. Full ownership-transfer validation still requires multiple team members each to complete a downstream release, with the maintainer available for questions but not driving, and gaps documented and fed back into improvements. Setup for the RPM lockfile step is now a single command (make setup-entitlements), so a new releaser no longer needs a personal Red Hat activation key.
```

## Edit 3: releases in progress

Decided by the maintainer on 2026-09-30: 0.23.2 will not ship downstream (superseded by 0.23.4, which is in progress), so it is dropped from the line.

Old:

```text
* **Production validation**: 0.24.1 released end-to-end via autorelease (Sep 2026) across 7 OCP versions (4.16–4.22); 0.23.2 in progress
```

New:

```text
* **Release evidence**: 0.24.1 production bundle publication is verified; recorded FBC scope is OCP 4.16–4.22, with production-index membership and release/QE evidence still to recover before tracker closeout. 0.22.2 and 0.23.4 remain in progress
```

Basis: the October 7 exact production bundle tag resolves with version v0.24.1. All seven index extraction probes timed out, and the recorded historical component Release CRs are NotFound. Those reads support bundle publication, not an end-to-end validation claim or an absence verdict. See [current artifact evidence](../../current-work.md#release-recovery-and-time-sensitive-work).

## Edit 5: new deliverables (insert before the "Broader ecosystem impact" heading)

Insert this block immediately before the line `#### Broader ecosystem impact`:

```text
#### Portable, security-aware release tooling

Release skills share Claude/Codex discovery and a tested compatibility contract from one source; konflux-ci-fix retains five known debt entries, and installed-host execution remains a follow-up. Tekton task updates detect Enterprise Contract deny rules instead of advising futile version bumps. A resumable onboarding CLI prepares FBC catalogs and the tenant and admission changes for OCP major-version transitions (OCP 5.0 is a provisional draft; builds and installation are not yet verified). RPM lockfile prerequisites are set up with one command.

#### Glasswing shipyard audit remediation

A Glasswing AI-SAST audit of shipyard produced 22 findings; its initial report classified 17 as fixable. The September inventory records 113 PRs across release branches and consumer repos, with 105 merged. The eight FIND-006 drafts closed without merging on October 3 and still need a remediation or re-triage decision. Coordinated upgrade-test repairs and the open devel helper-pod repair remain separate evidence gates.
```

## Edit 1: script, file and line counts

Old:

```text
* 18 skills backed by 56 scripts (15,700 LOC) covering component setup, bundle builds, FBC catalogs, release notes, and verification
```

New:

```text
* At the 2026-09-29 baseline, 18 skills were backed by 51 scripts, 29 test files and one test helper (81 shell/Python files, about 30k lines including tests), covering component setup, bundle builds, FBC catalogs, release notes, RPM lockfiles, OCP onboarding, and verification
```

Basis (origin/main at 0ed2981, 2026-09-29): 18 directories under skills/; 81 .sh/.py files under scripts/, of which 29 are test files (test-\*, test\_\*, e2e\_\*), 1 is a
test helper (isolate_git.py) and 51 are scripts; 30,164 lines across them. The old "56 scripts (15,700 LOC)" used a counting rule I could not reproduce,
so the new line states its own definition.

## Edit 2: test count

Old (nested under the Autorelease conductor bullet, indented four spaces):

```text
    * 337 tests across the conductor and step libraries
```

New:

```text
    * Over 1,100 shell assertions and Python test cases across the conductor, step libraries, worktree safety, EC deny-rule checks and OCP onboarding
```

Basis: the October 6 full `make test` reports more than 1,100 checks and test cases across its suite summaries, including 127 entitlements
assertions and 55 Python onboarding tests. This is an aggregate of shell assertions and Python test cases, not a count of unique test functions;
the conservative wording avoids presenting them as one uniform metric.

## After editing: verification

1. Re-read the epic and confirm only the approved changes, nothing else, and that headings, bullets and nested bullets still render.
2. Confirm the description's other sections (Current Automation, CVE Remediation, Upstream Release, Agent Context Layer) are unchanged.
3. If conversion altered formatting anywhere, explicitly restore the saved original ADF description, read it back, and retry the edits through the Jira UI.
