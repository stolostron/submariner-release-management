<!-- markdownlint-disable MD013 -->

# Epic description edits for ACM-39728 (exact old and new text)

Nothing here has been applied. The description was read on 2026-09-29 (last updated in Jira 2026-09-16). Every "old" snippet below must match the live
description exactly once; re-read the epic immediately before editing and stop if any snippet has changed. Edit with `editJiraIssue`,
field `description`, content format markdown. Jira keeps the prior version in the issue history, which is the rollback path; the maintainer should also
keep a copy of the original description before editing.

Each edit is independent, so any of them can be skipped.

## Edit 1: script, file and line counts

Old:

```text
* 18 skills backed by 56 scripts (15,700 LOC) covering component setup, bundle builds, FBC catalogs, release notes, and verification
```

New:

```text
* 18 skills backed by 51 scripts and 29 test files (81 shell/Python files, about 30k lines including tests) covering component setup, bundle builds, FBC catalogs, release notes, RPM lockfiles, OCP onboarding, and verification
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
    * Over 1,100 tests across the conductor, step libraries, worktree safety, EC deny-rule checks and OCP onboarding
```

Basis: the per-suite pass counts in a full `make test` of the merged tree sum to 1,008 before the entitlements suite (127 assertions, merged in the
last PR), so about 1,135. The old figure counted the same kind of per-suite assertion lines, so the comparison is fair but approximate, hence "over 1,100".

## Edit 3: releases in progress

Decided by the maintainer on 2026-09-30: 0.23.2 will not ship downstream (superseded by 0.23.4, which is in progress), so it is dropped from the line.

Old:

```text
* **Production validation**: 0.24.1 released end-to-end via autorelease (Sep 2026) across 7 OCP versions (4.16–4.22); 0.23.2 in progress
```

New:

```text
* **Production validation**: 0.24.1 released end-to-end via autorelease (Sep 2026) across 7 OCP versions (4.16–4.22); 0.22.2 and 0.23.4 in progress
```

## Edit 4: release ownership transfer

Old (append to the end of the paragraph under "Release ownership transfer"):

```text
Currently only one engineer can execute downstream releases. The goal is for any team member to be able to pick up a release branch and drive the full downstream release process. The skills and context docs encode the knowledge, but this hasn't been validated yet.
```

New:

```text
Currently only one engineer can execute downstream releases. The goal is for any team member to be able to pick up a release branch and drive the full downstream release process. The skills and context docs encode the knowledge, but this hasn't been validated yet. Setup for the RPM lockfile step is now a single command (make setup-entitlements), so a new releaser no longer needs a personal Red Hat activation key.
```

## Edit 5: new deliverables (insert before the "Broader ecosystem impact" heading)

Insert this block immediately before the line `#### Broader ecosystem impact`:

```text
#### Portable, security-aware release tooling

Release skills run under both Claude and Codex from one source. Tekton task updates detect Enterprise Contract deny rules instead of advising futile version bumps. A resumable onboarding CLI prepares FBC catalogs and the tenant and admission changes for OCP major-version transitions (OCP 5.0 is a provisional draft; builds and installation are not yet verified). RPM lockfile prerequisites are set up with one command.

#### Glasswing shipyard audit remediation

A Glasswing AI-SAST audit of shipyard produced 22 findings, of which 17 are fixable. The fixes were carried to every supported release branch and the consumer repos (113 PRs, 105 merged; the FIND-006 drafts are gated on prerequisites).
```

## After editing: verification

1. Re-read the epic and confirm exactly these five changes, nothing else, and that headings, bullets and nested bullets still render.
2. Confirm the description's other sections (Current Automation, CVE Remediation, Upstream Release, Agent Context Layer) are unchanged.
3. If markdown conversion altered formatting anywhere, restore from the issue history and apply the edits through the Jira UI instead.
