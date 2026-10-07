<!-- markdownlint-disable MD013 -->

# Epic description edits for ACM-39728 (exact old and new text)

Nothing here has been applied. The baseline description was read on 2026-09-29 and its original snippets rechecked on 2026-10-07. Every "old" snippet below must match the live
rendered description exactly once; re-read the epic immediately before editing and stop if any snippet has changed. All four old snippets and
the insertion heading still matched once at the 2026-10-07 read. Jira Cloud stores the description as ADF: save the full original document, update
the relevant nodes with a supported client/UI and preserve everything else. The Markdown below is text for that client, not a raw REST field value.
Save a fresh baseline before each independent edit. Before writing, confirm it is unchanged; restore it only while the field still equals that edit’s written result. If later edits exist, reconcile them first. Issue history is not an automatic restore operation.

Each edit is independent. Review in order 4 (adoption), 3 (release evidence), 5 (deliverables), then optional stale-count cleanup 1/2. Keep these edit numbers stable; no new story keys are needed.

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

Omit this insertion if the block is already present. Otherwise insert it immediately before the line `#### Broader ecosystem impact`:

```text
#### Portable, security-aware release tooling

Release skills share Claude/Codex discovery and a tested compatibility contract from one source; konflux-ci-fix retains five known debt entries, and installed-host execution remains a follow-up. Tekton task updates and log diagnosis report Enterprise Contract deny reasons; a qualifying bump can fix a minimum-version denial, while catalog replacement must follow policy. A resumable onboarding CLI prepares FBC catalogs and the tenant and admission changes for OCP major-version transitions (OCP 5.0 is a provisional draft; builds and installation are not yet verified). RPM lockfile prerequisites are set up with one command.

#### Glasswing shipyard audit remediation

A Glasswing AI-SAST audit of shipyard produced 22 findings; its initial report classified 17 as fixable. The September inventory records 113 PRs across release branches and consumer repos, with 105 merged. The eight FIND-006 drafts closed without merging on October 3 and still need a remediation or re-triage decision. Coordinated upgrade-test repairs and the open devel helper-pod repair remain separate evidence gates.
```

## Edit 1: replace stale size metrics with supported scope

Old:

```text
* 18 skills backed by 56 scripts (15,700 LOC) covering component setup, bundle builds, FBC catalogs, release notes, and verification
```

New:

```text
* Release skills backed by deterministic scripts and tests cover component setup, bundle builds, FBC catalogs, release notes, RPM lockfiles, OCP onboarding and verification
```

Basis: replace dated file/line totals with the supported operations. Current scripts and checks are listed in the [autorelease roadmap](../../autorelease-step-automation.md); historical counts remain in the audit history.

## Edit 2: replace the stale test count with validation scope

Old (nested under the Autorelease conductor bullet, indented four spaces):

```text
    * 337 tests across the conductor and step libraries
```

New:

```text
    * Automated shell/Python checks cover the conductor, step libraries, worktree safety, EC deny-rule handling and OCP onboarding
```

Basis: the full `make test` target covers these areas. Naming them avoids maintaining a mixed total of shell assertions and Python test cases.

## After editing: verification

1. Re-read the epic and confirm only the approved changes, nothing else, and that headings, bullets and nested bullets still render.
2. Confirm the description's other sections (Current Automation, CVE Remediation, Upstream Release, Agent Context Layer) are unchanged.
3. If conversion altered formatting, stop and apply the baseline/rollback rule above. Read back any correction before retrying through a supported Jira UI.
