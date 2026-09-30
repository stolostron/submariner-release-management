<!-- markdownlint-disable MD013 -->

# New child stories for ACM-39728 (exact payloads)

Nothing here has been created in Jira. Field values were read from the existing siblings on 2026-09-29/30:

* Project `ACM`, issue type `Story`, parent (Epic Link) `ACM-39728`, component id `33720` (Multicluster Networking[ext]).
* Assignee: the maintainer's own Jira account (look it up with `atlassianUserInfo`), same as the siblings.
* Activity Type is `customfield_10464`: siblings use `Future Sustainability` (option id `10606`) and the security-flavored ones use
  `Security & Compliance` (option id `10609`). It is set per story below. Do not use option `10608`, which the release-tracker script uses.
* Priority ids seen on siblings: Major `10002`, Normal `10003`, Minor `10004`.
* Sprint: `customfield_10020`. The only open sprint is "Submariner Sprint 2026-58" (id `85613`, board `9543`), which is past its end date (2026-09-27)
  but not closed, and there is no future sprint. Leave unset unless the maintainer wants it.
* Description format: markdown with `_Scope:_` and `_Acceptance criteria:_` italic headings, as on the siblings.
* Progress comments use visibility `{"type": "group", "value": "Red Hat Employee"}`, as on the siblings.
* Git Pull Request field is `customfield_10875` (see the main plan for the canary step before relying on it).

The order of creation is: story 4 first as a canary, then 1, 2, 3, 5.

## Story 4 (canary): One-command setup for RPM lockfile prerequisites

* Summary: `One-command setup for RPM lockfile prerequisites (shared team credentials)`
* Priority: Major (`10002`)
* Activity Type: Future Sustainability (`10606`)
* Target status after creation: Resolved (transition id `131`, needs a resolution), because the work is merged.
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/110`

Description:

```text
The RPM lockfile step of a downstream release (step 4b) needs Red Hat entitlements and a registry.redhat.io login. The upstream flow has each person create their own Red Hat activation key. That does not work for this team: the activation-key page fails or errors intermittently on very large internal Red Hat accounts, and Red Hat's guidance is one shared key per org or team rather than one per person. So the team uses one shared org ID and activation key, delivered as a sealed bundle with a one-command setup.

_Scope:_

* make setup-entitlements, check-entitlements and seal-entitlements; idempotent, backs up and restores the registration on failure, and verifies RHEL repository access instead of trusting the certificate
* rpm-lockfile-update fails fast, with the fix, when the setup is missing or the entitlement grants no repository access
* Decision, tradeoffs and limits recorded in secrets/README.md and CLAUDE.md so they are not re-litigated

_Acceptance criteria:_

* A teammate runs one command and can run the RPM lockfile step without creating a personal activation key
* Rotating the shared key needs nothing from teammates except a git pull
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

## Story 1: Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft)

* Summary: `Onboard FBC catalogs for OCP major-version transitions (OCP 5.0 draft)`
* Priority: Major (`10002`)
* Activity Type: Future Sustainability (`10606`)
* Target status: In Progress (transition id `71`); this is not finished.
* Link: `Related` (link type id `10077`) to ACM-45508 (dev/test consumption of ART 5.0 builds).
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
Status as of 2026-09-30:

* https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): onboarding CLI (scripts/fbc-onboard.py, 2,111 lines), 55 onboarding regression tests in make test, an end-to-end harness, plans with rollout evidence requirements, and the /add-fbc-ocp-version rewrite
* https://github.com/stolostron/submariner-operator-fbc/pull/81 (merged 2026-09-29): FBC workflow support for OCP major transitions and the OCP 5.0 catalog
* https://github.com/stolostron/submariner-operator-fbc/pull/82 (open): OCP 5.0 Konflux pipelines with lifecycle injection

Not done: the tenant and admission changes for konflux-release-data are prepared locally but not yet submitted as a merge request; real multi-platform Konflux builds, installation and releases for OCP 5 are unverified. The catalog inputs are provisional.
```

## Story 2: Detect Enterprise Contract deny rules during Tekton task updates

* Summary: `Detect Enterprise Contract deny rules during Tekton task updates`
* Priority: Major (`10002`)
* Activity Type: Security & Compliance (`10609`)
* Target status: Resolved (`131`)
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

* A task ref that EC denies is reported as denied, not as needing a version bump, and a run with an active denial fails
* Replacement of a moved catalog ref is automatic only when the policy message names the replacement
```

Progress comment (post after creation):

```text
Delivered in https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): 11 files, +1,310/-77.

Real-world motivation, 2026-09-13 onward: 33 Enterprise Contract and Tekton task PRs across the component repos (32 merged). They include replacing the denied rpms-signature-scan vanguard ref and removing the policy-denied show-sbom task on the release branches. Since the epic started on 2026-08-04 there have been about 73 such PRs (63 merged). Related policy work: release-engineering/rhtap-ec-policy#268 (merged 2026-08-31) added Submariner 0.24 to the network policy RBAC exceptions. The full list since 2026-09-13 is plans/asdlc-jira-update-payloads/ec-tekton-prs.md in stolostron/submariner-release-management.
```

## Story 3: Make release skills portable across Claude and Codex

* Summary: `Make release skills portable across Claude and Codex`
* Priority: Normal (`10003`)
* Activity Type: Future Sustainability (`10606`)
* Target status: Resolved (`131`)
* Git Pull Request: `https://github.com/stolostron/submariner-release-management/pull/109`

Description:

```text
The 18 release skills were Claude-only. The company-wide aSDLC effort uses several coding agents, so the same skills and docs should run under Claude and Codex without forks.

_Scope:_

* Shared discovery: AGENTS.md and an .agents/skills symlink to skills/
* A compatibility test with a debt ratchet (Claude-only argument handling, slash-only usage, host-specific tools, fixed roots) that may only shrink
* Release-root resolution independent of the caller's working directory; RELEASE_MANAGEMENT_REPO for installed copies
* Public examples use the plugin namespace

_Acceptance criteria:_

* Every skill is discoverable by both agents from the same directory
* The compatibility test passes and its debt counts cannot grow
```

Progress comment (post after creation):

```text
Delivered in https://github.com/stolostron/submariner-release-management/pull/109 (merged 2026-09-29): 21 files, +1,152/-693. scripts/lib/test-skills-compatibility.sh runs 19 checks in make test.
```

## Story 5: Remediate the Glasswing shipyard audit findings

* Summary: `Remediate Glasswing shipyard audit findings across shipyard and its consumer repos`
* Priority: Major (`10002`)
* Activity Type: Security & Compliance (`10609`)
* Target status: In Progress (`71`); eight FIND-006 draft PRs are still open, gated on prerequisites.
* Git Pull Request: leave empty and rely on the comment (113 PRs is too many for the field).

Description:

```text
A Glasswing AI-SAST audit of submariner-io/shipyard produced 22 findings (7 Medium, 10 Low, 5 Informational). Five are Won't Fix (accepted risk, including the architecturally-required e2e-framework behaviour) and 17 are fixable. They are grouped into 8 PRs in 3 waves and carried to every supported release branch and to the consumer repos that vendor the affected files. No Jira tracker existed for this audit when this story was created (searched by label and by text on 2026-09-30).

_Scope:_

* Wave 1: Dockerfile pinning and user, GitHub Actions interpolation and credentials, download integrity, security policy
* Wave 2: test-pod hardening, validated with full e2e
* Wave 3: subctl download integrity (blocked on subctl checksums and a dapper-base rebuild), eval to envsubst, image signing
* Follow-up: CI helper pod manifests fixed for OCP after the pod hardening broke admission under restricted SCC
* Backports to release-0.18 through release-0.24 and companion PRs in lighthouse, subctl, submariner and submariner-operator

_Acceptance criteria:_

* All fixable findings merged on devel and every supported release branch
* The FIND-006 drafts are merged once their prerequisites land, or the finding is re-triaged
* CI helper pod manifests work on OCP
```

Progress comment (post after creation): see `shipyard-audit-prs.md` in this directory for the full PR list, and use this summary:

```text
Status as of 2026-09-30, from the remediation tracker joined with live GitHub state:

* 113 PRs, all authored by the maintainer: shipyard 65, lighthouse 16, subctl 16, submariner 8, submariner-operator 8
* 105 merged between 2026-08-20 and 2026-09-14 (most on 2026-09-10); 8 open
* The 8 open PRs are the FIND-006 (subctl download integrity) draft series on devel and release-0.18 through release-0.24, gated on the subctl checksums PRs and a dapper-base rebuild
* Follow-up: 9 PRs fix the CI helper pod manifests for OCP (8 merged, release-0.18 through release-0.25; the devel PR shipyard#2618 is still open)

Related open issues (filed by the maintainer, cause not established): https://github.com/submariner-io/shipyard/issues/2633 (upgrade CI broken on release-0.22 after the dapper-base rebuild, 2026-09-24) and https://github.com/submariner-io/shipyard/issues/2635 (deploy-latest installs the wrong minor version for the upgrade test). The FIND-006 drafts are gated on the same dapper-base rebuild.

Full per-finding PR list: plans/asdlc-jira-update-payloads/shipyard-audit-prs.md in stolostron/submariner-release-management.
```
