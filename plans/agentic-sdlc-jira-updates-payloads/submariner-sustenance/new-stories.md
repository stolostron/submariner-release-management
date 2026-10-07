<!-- markdownlint-disable MD013 -->

# New child stories for ACM-39728 (exact payloads)

Nothing here has been created in Jira. Field values were read from siblings and verified against complete ACM Story create metadata on 2026-10-07.
Text blocks are Markdown for a converting client/UI; direct Jira Cloud REST writes need ADF. Verify create-field and transition metadata before writing.

* Project `ACM`, issue type `Story` (id `10009`), `parent` `ACM-39728`, component id `33720` (Multicluster Networking[ext]). Current metadata allows `parent` and legacy Epic Link; use one verified membership path. Reporter is required with a default; verify the approved reporter on read-back.
* Assignee: the maintainer's own Jira account, resolved through the authenticated client, same as the siblings.
* Activity Type is `customfield_10464`: siblings use `Future Sustainability` (option id `10606`) and the security-flavored ones use
  `Security & Compliance` (option id `10609`). It is set per story below. Do not use option `10608`, which the release-tracker script uses.
* Priority ids seen on siblings: Major `10002`, Normal `10003`, Minor `10004`.
* Sprint: `customfield_10020`. On 2026-10-06 the existing In Progress siblings include active "Submariner Sprint 2026-59" (id `87579`).
  The previously proposed Sprint 2026-58 (`85613`) is now closed. Leave unset unless the maintainer chooses a current active sprint.
* Description format: markdown with `_Scope:_` and `_Acceptance criteria:_` italic headings, as on the siblings.
* Progress comments use visibility `{"type": "group", "value": "Red Hat Employee"}`, as on the siblings.
* Git Pull Request field is `customfield_10875`, an ADF rich-text document (see Part A, section A5 of the plan, for the canary step).

The order of creation is: story 4 first as a canary, then 2, 3, 1, 5: delivered scopes before unfinished rollout/remediation. Approve the split and fields first; proposed resolution remains an acceptance review.

## Story 4 (canary): One-command setup for RPM lockfile prerequisites

* Summary: `One-command setup for RPM lockfile prerequisites (shared team credentials)`
* Priority: Major (`10002`)
* Activity Type: Future Sustainability (`10606`)
* Proposed status after acceptance-criteria review: Resolved; discover the issue's transition and required resolution fields before applying it.
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/110`

Description:

```text
The RPM lockfile step needs Red Hat entitlements and a registry.redhat.io login. The team chose shared credentials delivered as a sealed bundle with a one-command setup; its rationale and limitations are recorded in secrets/README.md. This story delivers that setup, while ACM-39736 tracks multiple team members completing releases and feeding back gaps.

_Scope:_

* make setup-entitlements, check-entitlements and seal-entitlements; idempotent, backs up and restores the registration on failure, and verifies RHEL repository access instead of trusting the certificate
* rpm-lockfile-update fails fast, with the fix, when the setup is missing or the entitlement grants no repository access
* Decision, tradeoffs and limits recorded in secrets/README.md and CLAUDE.md so they are not re-litigated

_Acceptance criteria:_

* The supported one-command setup lets a releaser run the RPM lockfile step without creating a personal activation key; multiple team members completing releases and feeding back gaps are tracked separately in ACM-39736
* Teammates receive a rotated bundle with git pull and re-run make setup-entitlements FORCE=1 when registration must use the new activation key; password changes are shared out of band
* Tests cover seal and open, wrong and stale passwords, rotation, tampering, and backup and restore on failed registration
```

Progress comment (post after creation):

```text
Delivered in https://github.com/stolostron/submariner-release-management/pull/110 (merged 2026-09-29): 12 files, +954/-10.

* scripts/setup-entitlements.sh, seal-entitlements.sh and lib/entitlement-bundle.sh; make targets setup-entitlements, check-entitlements, seal-entitlements
* scripts/lib/test-setup-entitlements.sh: 127 assertions with stubbed sudo, subscription-manager, podman and curl and a real gpg for the bundle. A flaky tamper check (a no-op about 1 run in 64) was found by CI and fixed.
* rpm-lockfile-update.sh now calls the check first and stops early with the fix
* Rationale and security limits: secrets/README.md; decision recorded in CLAUDE.md "Settled Decisions"

Per the PR description, a full rpm-lockfile-update run on release-0.24 regenerated the gateway, globalnet, route-agent and nettest lockfiles using this setup.
```

## Story 2: Detect Enterprise Contract deny rules during Tekton task updates

* Summary: `Detect Enterprise Contract deny rules during Tekton task updates`
* Priority: Major (`10002`)
* Activity Type: Security & Compliance (`10609`)
* Proposed status after acceptance-criteria review: Resolved, using the issue's available transition and resolution fields.
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/109`

Description:

```text
Refreshing Tekton task references could pass the trusted-list check while Enterprise Contract still denied a task (moved or deprecated catalogs), and parse-ec-log told operators to bump versions for failures a bump cannot fix. In practice this showed up as denied rpms-signature-scan vanguard refs and a policy-denied show-sbom task across the release branches. This scans the patched refs against the EC deny rules and reports the real reason.

_Scope:_

* scripts/lib/deny-rules.sh: active denials fail the run, future-dated ones warn, and only quay.io/konflux-ci/<catalog> replacements named by the policy message are followed
* Pinned pipeline-patcher bumped to match; bump commit messages explain replaced refs and component bump PRs are labelled ready-to-test
* parse-ec-log reports deny reasons instead of advising a version bump, and recovers violations from truncated Konflux UI JSON
* Tests: deny rules, Tekton version bump, task refs, parse-ec-log

_Acceptance criteria:_

* An EC-denied task ref includes its deny reason, and an active denial fails the update run. The parser does not promise that a plain refresh fixes it; a minimum-version denial may be fixable by a qualifying bump
* Replacement of a moved catalog ref is automatic only when the policy message names the replacement
```

Progress comment (post after creation):

```text
Delivered in https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): EC deny-rule detection and Tekton task update fixes.

Real-world motivation, 2026-09-13 onward: 33 Enterprise Contract and Tekton task PRs across the component repos (32 merged). They include replacing the denied rpms-signature-scan vanguard ref and removing the policy-denied show-sbom task on the release branches. Since the epic started on 2026-08-04 there have been 74 such PRs (64 merged) in the initial 2026-09-30 sweep (05:00 UTC cutoff). Related policy work: [rhtap-ec-policy#268](https://github.com/release-engineering/rhtap-ec-policy/pull/268) (merged 2026-08-31) added Submariner 0.24 to the network policy RBAC exceptions. [Full PR list since 2026-09-13](https://github.com/stolostron/submariner-release-management/blob/d094bf36994f5d938f41d4fc305feb93bd896977/plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/ec-tekton-prs.md).
```

## Story 3: Deliver shared Claude/Codex skill discovery and compatibility contract

* Summary: `Deliver shared Claude/Codex skill discovery and compatibility contract`
* Priority: Normal (`10003`)
* Activity Type: Future Sustainability (`10606`)
* Proposed status after acceptance-criteria review: Resolved, using the issue's available transition and resolution fields.
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/109`

Description:

```text
The 18 release skills were Claude-only. Deliver shared discovery and a tested compatibility contract so both agents use the same source. Complete execution portability is a separate remaining task: konflux-ci-fix still has five overlapping debt entries, and the installed-host matrix remains to be completed.

_Scope:_

* Shared discovery: AGENTS.md and an .agents/skills symlink to skills/
* A compatibility test with a debt ratchet (Claude-only argument handling, slash-only usage, host-specific tools, fixed roots) that may only shrink
* Release-root resolution independent of the caller's working directory; RELEASE_MANAGEMENT_REPO for installed copies
* Public examples use the plugin namespace

_Acceptance criteria:_

* The repository exposes one skill source through shared discovery paths and agent instructions; installed-host execution remains separate qualification
* The compatibility test passes and its debt counts cannot grow
```

Progress comment (post after creation):

```text
Delivered in https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): shared skill discovery and the compatibility contract. On October 7, make test-skills passes all 19 checks with five known debt entries, all in konflux-ci-fix. Passing the debt ratchet does not establish zero debt or complete installed-host execution. Keep that follow-up explicit in plans/claude-codex-skill-compatibility.md.
```

## Story 1: Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft)

* Summary: `Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft)`
* Priority: Major (`10002`)
* Activity Type: Future Sustainability (`10606`)
* Target status: In Progress; discover the issue's available transition. This is not finished.
* Links: related-issue links to ACM-45508 (dev/test consumption of ART 5.0 builds) and OPGM-364 (existing lifecycle publication), using the currently available link type; check existing links and read back each addition.
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/109`, `https://github.com/stolostron/submariner-operator-fbc/pull/81`, `https://github.com/stolostron/submariner-operator-fbc/pull/82`

Description:

```text
Adding an OCP version to the Submariner FBC and Konflux tenant configuration was a manual, error-prone process that only handled 4.x. OCP 5.0 is the first major-version transition. This adds a resumable onboarding CLI that prepares isolated catalog, tenant and admission changes, validates their contracts, builds and serves the target catalog image, and checks live build provenance separately, without touching unrelated work.

Dev and test consumption of ART 5.0 builds is tracked separately in ACM-45508; this story covers the release and FBC side.

_Scope:_

* scripts/fbc-onboard.py with phases plan, prepare-config, prepare-catalog, prepare and test-image, plus tests, fixtures and an end-to-end harness
* Full OCP identities (4.x and 5.x) carried through release scope, generation, status, snapshot checks and prod-index verification
* /add-fbc-ocp-version skill and FBC workflow rewrite, with rollout evidence requirements
* OCP 5.0 catalog and pipelines in submariner-operator-fbc, and tenant and admission configuration in konflux-release-data

_Acceptance criteria:_

* Onboarding is reproducible for OCP 4.23, 5.0 and 5.1 (done in an end-to-end run with real Kustomize, OPM and Podman)
* OCP 5.0 catalog and pipelines merged, and Konflux builds pass on all four platforms
* Tenant and admission changes merged in konflux-release-data, and the live release plans match the admissions
* Installation verified on a real OCP 5 cluster (not done yet; the catalog inputs, minimum Submariner stream 0.24 and channel head 0.24.1, are provisional)
```

Progress comment (post after creation):

```text
October 7 read:

* https://github.com/stolostron/submariner-release-management/pull/109 and https://github.com/stolostron/submariner-operator-fbc/pull/81 are merged: onboarding CLI, regression coverage, OCP-major workflow support and a provisional OCP 5.0 catalog.
* https://github.com/stolostron/submariner-operator-fbc/pull/82 remains open; its published build fails before tasks start because the build account is missing. The tenant read also found the Application and Component absent.
* Registry repair, tenant and managed-admission drafts exist locally and require fresh-base review. Tenant reconciliation provisions the build account; admissions gate later releases.

Still required: registry credential usability, merged configuration/pipelines, actual four-platform build/provenance, release matching, catalog proof and applicable real-cluster installation. Task trust expires October 30/31 at the pinned audit; re-read current allow/deny policy before execution and replace expired or denied refs when required. Existing OPGM-364 tracks lifecycle publication; ACM-45508 tracks addon consumption. Neither establishes OCP 5 runtime support.
```

Rollout evidence and remaining gates: [OCP 5.0 FBC rollout plan](../../ocp-5-0-fbc-rollout.md).
Before posting, refresh the progress comment from that plan, including registry access, target-index membership and task-trust expiry.

## Story 5: Remediate the Glasswing shipyard audit findings

* Summary: `Remediate Glasswing shipyard audit findings across shipyard and its consumer repos`
* Priority: Major (`10002`)
* Activity Type: Security & Compliance (`10609`)
* Target status: In Progress, using the issue's available transition; all eight FIND-006 drafts closed without merging; remediation/re-triage and the open helper/upgrade repairs remain.
* Git Pull Request: leave empty and rely on the comment (113 PRs is too many for the field).

Description:

```text
A Glasswing AI-SAST audit of submariner-io/shipyard produced 22 findings (7 Medium, 10 Low, 5 Informational). The initial report classifies five as Won't Fix (including architectural e2e-framework behaviour) and 17 as fixable; those labels alone do not establish owner acceptance of the risk dispositions. They are grouped into 8 PRs in 3 waves and carried to every supported release branch and to the consumer repos that vendor the affected files. The October 7 duplicate check found the broader closed Glasswing epic ACM-36285 with no children, plus related incident issues, but no matching shipyard-audit remediation story in the searched results. Reconcile that scope before creating this story; do not reopen or duplicate the broader epic.

_Scope:_

* Wave 1: Dockerfile pinning and user, GitHub Actions interpolation and credentials, download integrity, security policy
* Wave 2: test-pod hardening and consuming-repository E2E validation; verify the actual run scope rather than implying complete OCP coverage
* Wave 3: subctl download integrity (blocked on subctl checksums and a dapper-base rebuild), eval to envsubst, image signing
* Follow-up: CI helper pod manifest repair for OCP after the pod hardening broke admission under restricted SCC; devel repair remains open
* Backports to release-0.18 through release-0.24 and companion PRs in lighthouse, subctl, submariner and submariner-operator

_Acceptance criteria:_

* Each finding has a recorded disposition and supported-branch scope. Findings retained as fixable have their fixes merged on devel and every applicable supported release branch; any accepted risk/re-triage has explicit evidence and acceptance
* FIND-006 remains open until replacement/refreshed fixes merge on the applicable supported branches or its re-triage is explicitly accepted with evidence. Closing unmerged drafts is not a disposition
* CI helper pod manifests work on OCP
```

Progress comment (post after creation): see `shipyard-audit-prs.md` in this directory for the full PR list, and use this summary:

```text
Status as of 2026-09-30, from the remediation tracker joined with live GitHub state:

* 113 PRs, all authored by the maintainer: shipyard 65, lighthouse 16, subctl 16, submariner 8, submariner-operator 8
* 105 merged between 2026-08-20 and 2026-09-14 (most on 2026-09-10); 8 open
* The 8 open PRs are the FIND-006 (subctl download integrity) draft series on devel and release-0.18 through release-0.24, gated on the subctl checksums PRs and a dapper-base rebuild
* Follow-up: 9 PRs fix the CI helper pod manifests for OCP (8 merged, release-0.18 through release-0.25; the devel PR [shipyard#2618](https://github.com/submariner-io/shipyard/pull/2618) is still open)

Current refresh, October 7: all eight FIND-006 drafts closed without merging on October 3. They need an explicit disposition and refreshed prerequisite checks; closure is not remediation. The September counts above remain historical. [shipyard#2618](https://github.com/submariner-io/shipyard/pull/2618) remains open with passing/skipped returned checks and an approval on current head 682127c8424d8f6a1614e0bf789bb7d17ea10af9. Its aggregate changes-requested state originates in an older review; zero current unresolved threads were returned. Current-head OCP admission/install evidence still needs review, and the PR body incorrectly retains a hostUsers claim removed from the actual manifests.

https://github.com/submariner-io/shipyard/issues/2633 is closed; https://github.com/submariner-io/shipyard/issues/2635 remains open. Coordinated fixes are https://github.com/submariner-io/shipyard/pull/2654 (open, published checks pass or skip) and https://github.com/submariner-io/subctl/pull/1944 (draft, dependency/upgrade/Go/vulnerability checks fail). The Go check specifically reports gofumpt formatting at cmd/subctl/upgrade_test.go:135; the scan reports high-severity gRPC/x/crypto module findings. Prepare the formatting fix and reconcile existing CVE work now. Both upgrade jobs complete baseline deployment but fail the subsequent isolated-baseline executable guard before the upgrade stage. Merge and publish the Shipyard runtime, verify the consumer at its exact head, and complete applicable maintained-stream backports before closing #2635. Do not infer download-integrity remediation from upgrade-test success.

[Full per-finding PR list](https://github.com/stolostron/submariner-release-management/blob/d094bf36994f5d938f41d4fc305feb93bd896977/plans/agentic-sdlc-jira-updates-payloads/submariner-sustenance/shipyard-audit-prs.md).
```
