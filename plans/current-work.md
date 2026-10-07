<!-- markdownlint-disable MD013 -->

# Current work and planning handoffs

Refreshed October 7, 2026. The comprehensive sweep covered all 220 assigned non-Vulnerability full views, four active private vulnerabilities and related dependencies; the latest follow-up rechecked the unrestricted inventory, active/payload targets and tenant state.
Current tenant/snapshot reads are distinguished below from earlier registry/index probes and reported validation.
The [assigned-issue queue](jira-update-queue.md) accounts for all 76 active non-Vulnerability issues and private security follow-up,
with [additional comment drafts](agentic-sdlc-jira-updates-payloads/portfolio-comments.md).
This is the engineering evidence entry point for the [Jira update plan](agentic-sdlc-jira-updates.md),
[FBC recovery](fbc-failure-recovery.md) and [OCP 5 rollout](ocp-5-0-fbc-rollout.md).
Historical counts retain their stated cutoff. Planning changes are published through [WIP PR #111](https://github.com/stolostron/submariner-release-management/pull/111).
Four approved existing-story comments were posted and verified October 7 at 18:23 UTC; ids are recorded in the Jira update plan. Other payloads remain pending; no PR comment, cluster mutation or release was performed.

## Release recovery and time-sensitive work

| Work | Observed reality | Next action and completion evidence |
| --- | --- | --- |
| 0.23.4, ACM-44527 | Parent In Progress; component stage and all prerequisites through release notes Resolved; FBC catalog In Progress; FBC stage, QE and production steps New | Authentication now works; verify registry credential usability/field ownership, then carry out the separately authorized recovery. Require successful intended-snapshot tests and release verification before stage/QE |
| FBC 4.16–4.21 | Each retained snapshot matches `2e6b489e65620738d68504d9158418fe463e2073`; aggregate tests Failed and operator scenarios TestFail, finished September 30/October 1 | Exact [snapshot/scenario map](fbc-failure-recovery.md#retained-snapshot-and-scenario-identities) is recovered. Verify catalog content/credential usability before an authorized rerun; no fresh task logs exist in the returned PipelineRun list |
| ART Go builder migration, ACM-45318 | New; description requests migration by October 15 and lists addon, lighthouse, submariner and operator source repos | Use the [pinned source inventory](art-builder-migration.md): downstream component streams use UBI Go Toolset, addon branches use older Brew builders, and branch Go floors differ. Prepare reviewed changes for verified Brew/OSBS consumers with applicable compiler/crypto/build evidence; UBI Go Toolset alone is not an affected ART builder. This deadline can proceed independently of FBC credentials and Jira story creation |
| 0.24.1, ACM-40644 | Parent In Progress; all 15 subtasks terminal. Exact production bundle tag resolves with version v0.24.1; seven index probes time out and recorded component Release CRs are NotFound | Bundle publication is confirmed. Recover catalog/QE/release evidence for actual 4.16–4.22 scope before authorized closeout; missing retained CRs and timed-out probes are not proof of absence |
| 0.22.2, ACM-45070 | Retained candidate snapshot passes aggregate integration with warnings; its bundle CSV/version is 0.22.2, but embedded operand identity remains unreconciled. EC and bundle SHAs remain In Progress; stage onward New | Verify source/operand mapping before accepting this candidate or updating parent artifacts. Give the two additional test items their own disposition |
| Task trust maintenance | The October 6 immutable allowlist audit records three #82 pins expiring October 30 and lifecycle injection October 31 | Re-read current allowlist and deny rules; keep any repo-wide refresh separate. Expiry is not the demonstrated cause of today's FBC failures |

The latest authenticated `submariner-tenant` read again finds the registry secret unlinked from both runner credential lists and OCP 5 Application, Component and build account absent.
The namespace returns zero PipelineRuns and 746 retained snapshots; six of those recover the exact FBC failure associations.
This establishes snapshot verdicts/identities, not fresh task diagnosis or credential usability. GitLab fresh-base access remains unverified since the earlier DNS failure.

0.24.1 artifact read: `registry.redhat.io/rhacm2/submariner-operator-bundle:v0.24.1` resolves to
`sha256:a8bb318b8afa37daf2ce9394d80c46224e872b593934fbb68fd89e20e6665f84` with label `version=v0.24.1`.
Local FBC production records enumerate OCP 4.16–4.22. Each direct index extraction timed out at 100 seconds;
index membership remains unknown. All three recorded September component production Release names are NotFound in the authenticated tenant.
Their repository YAMLs are retained intent, not a current success verdict. No install, QE or release execution was repeated.

The inspected 0.22.2 candidate is `submariner-0-22-20261002-125823-000-lz`, with nine components and aggregate TestSucceeded=True.
Its completed EC/standard scenarios report warnings, despite retained `BuildPLRInProgress` labels. The bundle digest
`sha256:cdbc25da3eb5bea32ee537a2fee2a943f7cd8a16507fb9dbfdc9d7f4e0d2a9d3` has version label v0.22.2 and CSV version 0.22.2;
the bundle source is `da81d438c0456f367bc5e83e671362181a47ab63`. All seven CSV related-image digests differ from their mapped snapshot operands.
Registry copying can change manifest digests, so this comparison is not proof of invalid content. The snapshot operator inspects as v0.22.2;
inspection of the embedded production operator failed. Reconcile source/content and registry identity before treating this candidate as release-ready.
No tracker step or artifact is advanced from this partial evidence.

## Prepared release-data and OCP 5 work

All four inspected release-data checkouts are clean. Cached main is `8c18efee295889f5d86b03d16930a2f11977fd58`.

| Draft | Exact local head | Scope and next handoff |
| --- | --- | --- |
| Registry repair | `3edd2876d3c3eaa31c573ada703fce1fe6c3f858` | Three tenant files; refresh base, validate live credential and GitOps/controller field ownership, submit when authorized |
| OCP 5 tenant | `47eda9c5b11c6f57fb7a4f7fb9be2e0fd42be588` | Sixteen configuration files plus an extra documentation rewrite; separate that rewrite before submission. Component reconciliation provisions the build account |
| OCP 5 admissions | `860aa737d01120c47d7b474d8119657dada5d08b` | Two managed RPA additions for later release matching; not a prerequisite for creating the build account |

[FBC #82](https://github.com/stolostron/submariner-operator-fbc/pull/82) remains open at
`1e8b3c26137b49db60a0d93853f144990770f304`. Actions and DCO pass; the published Konflux run still fails before tasks start because
`build-pipeline-submariner-fbc-5-0` is missing. Fresh cluster reads also find the 5.0 Application and Component absent. Its description still incorrectly calls the lifecycle pin non-expiring and bundles tenant/admission prerequisites together.
Correct those statements when an external PR update is authorized. Preserve its executable pipelines and reconcile the duplicate planning file after review.

Catalog/tooling PRs #76 and #81 are merged. The September implementation records are historical local evidence, not a current statement that no catalog or PR exists.
Configuration, exact-head build, authenticated index rendering, conditional install, QE, publishing and default-scope activation remain distinct gates.
See the [rollout plan](ocp-5-0-fbc-rollout.md) for their order and evidence requirements.

## Upstream audit and upgrade tests

The September 113-PR audit inventory remains historical: 105 merged, eight FIND-006 drafts then open.
Direct October 7 API reads of shipyard #2566 and #2567–2573 find all eight **closed without merging on October 3**.
The #2566 timeline attributes closure to GitHub Actions following its stale warning; do not infer every draft's closure reason from that one timeline.
The previous verification document's October 6 claim that these drafts remained open was incorrect.

The download-integrity finding needs a current prerequisite and supported-branch review, then an explicit remediation/re-triage decision.
Reopening or replacing the drafts is a separate external action. Preserve their source identities; closure is not evidence that their fixes shipped.

| Work | Current evidence | Required sequence |
| --- | --- | --- |
| [shipyard #2654](https://github.com/submariner-io/shipyard/pull/2654) | Open at `557bb9977cd4e2dcb9f8526620423faa20c4c1fb`; all returned checks pass or skip. Selects/verifies branch-appropriate upgrade baselines | Review/merge, then verify publication of the updated Shipyard Dapper runtime before enabling the consumer |
| [subctl #1944](https://github.com/submariner-io/subctl/pull/1944) | Draft at `9a7cec7d82d341d7159b512bce564c2f040c2f73`; dependency, upgrade-command, Go and vulnerability checks fail | Preserve dependency ordering; repair formatting and triage the scan now. Verify the baseline executable after runtime publication, then consumer CLI/image coverage and applicable backports; see [CI handoff](upgrade-ci-recovery.md) |
| [shipyard #2635](https://github.com/submariner-io/shipyard/issues/2635) | Still open; #2633 is closed | Keep open until coordinated fixes, runtime publication, consumer CI and applicable backports satisfy its criteria |
| [shipyard #2618](https://github.com/submariner-io/shipyard/pull/2618) | Open at `682127c8424d8f6a1614e0bf789bb7d17ea10af9`; current-head approval, passing/skipped checks, zero current unresolved threads. Aggregate changes requested comes from an older review | Confirm merge readiness and current-head OCP admission evidence. The body still claims `hostUsers:false`, but all three current manifests omit it; correct the body when authorized |

Upgrade PR descriptions report local kind validation and cached-image limitations. This planning audit did not repeat those runs.
Do not treat upgrade-test repair as proof that FIND-006 download-integrity fixes shipped.

## Release tooling and Jira payloads

ACM-39728 still has ten direct children. CORENET-7155 still has no children and an empty description.
Both epics remain In Progress. The first four ACM comments were posted and verified; their ids are recorded in the execution plan. The three contribution targets remain New with comment totals 0/1/1 on ACM-39738/39739/39740; their progress drafts are not posted.
Submariner Sprint 2026-59 (87579) and CORENET Sprint 295 (87581) remain active in the inspected records.
Both projects' create metadata and existing targets' edit/transition metadata were read successfully; actual creates, transitions and write canaries remain untested.

* [Upstream release PR #1444](https://github.com/submariner-io/releases/pull/1444) remains open at `7f67ec02b571d1cb46189814a74b5996a2cc07f8`. Keep ACM-39733 with its existing owner; no progress or comment is attributed to the maintainer by this refresh.
* October 7 maintainer report: another team member has begun using the CVE and autorelease tooling. This is initial adoption evidence for ACM-39729/39731/39736; completed full releases and feedback are not established by that report.
* [Release-management #114](https://github.com/stolostron/submariner-release-management/pull/114) remains open at `a1bfe041b626ed39c42e703afc3b735b1bbd04c0`, with completed checks passing and Tide pending. Its skip-completed-step changes are not on main; describe them as pending work on ACM-39731.
* `make test-skills` passes 19 checks while retaining five overlapping compatibility debt entries in `konflux-ci-fix`. The proposed S3 now names the delivered discovery/contract scope. The [compatibility plan](claude-codex-skill-compatibility.md) retains remaining execution and host-matrix work.
* [shipyard #2582](https://github.com/submariner-io/shipyard/pull/2582) is published at `a88023ad8dd9adfb11223a579cd13de3e6f513bc`, matching the clean local checkout. Its description now reports 1,455 regression checks, including 83 review-focused checks, plus six focused probes and client-go master/release-4.20 evidence with explicit limits. Those author-reported runs were not repeated here.
* The October 7 contribution read returns running hosted checks and 37 review threads: one unresolved/current YAML thread and four unresolved/outdated threads. No review or approval is recorded on this head; aggregate changes requested comes from earlier heads. Keep source/test claims separate from qualification and reviewer acceptance; refresh before posting.
* Marketplace main `a62717603bcf5cc13b744d123a7cef5ab02992f3` already registers golang, compliance and node-cve tooling. Direct reads confirm merged [#470](https://github.com/openshift-eng/ai-helpers/pull/470) (fix-cve), [#736](https://github.com/openshift-eng/ai-helpers/pull/736) (stdlib triage) and [#763](https://github.com/openshift-eng/ai-helpers/pull/763) (analyze-cve). These overlap the proposed contributions; review composition/extension with maintainers without treating their merges as this work's acceptance.

Before writes, settle the story split/status and CORENET points/sprint, refresh descriptions and PR evidence, then read back one canary at a time.
No new stories for ordinary release steps or unrelated product work are proposed by this refresh.

## Unpublished tooling and stale roadmap entries

The remote fork branch `acm-39732-fbcProdUrls-automation` points to `3cabf0e1f7526d3ef554571ffbb0a95db33bf013`.
GitHub's PR query for that head returns none. Its three-file delta adds `scripts/update-fbc-prod-urls.sh` and wiring/tests;
current main has no such script or `STEP_SCRIPT` entry for `fbcProdUrls`. ACM-39732 remains New. This is an existing implementation candidate, not shipped automation.

Before proposing it for review:

* Rebase/reconcile against current main and use an isolated clean worktree, including untracked files; the draft only warns on tracked dirt before running update/build commands and committing on main.
* Replace its assumption that one OCP production release establishes completion for every target. Require the actual applicable scope, QE-approved snapshot and index evidence; transient/auth failures must not become absence or completion.
* Separate conversion of the released bundle's URL from selecting a new bundle snapshot; verify the current FBC `update-bundle` contract before reusing that operation.
* Preserve original checkout and unrelated work, compare final catalog contents/digests, and keep tracker completion with the existing verifier. The draft writes an In Progress record before its branch/cleanliness checks.
* Reconcile timing: the old workflow calls conversion optional/deferred, while the conductor's linear closeout treats `fbcProdUrls` as its final required completion check. Do not revive a deferred-next-release closeout assumption from the draft.

No candidate script was executed or modified. Any branch push/PR or Jira progress comment remains a separate external action.

The [autorelease roadmap](autorelease-step-automation.md) now contains the current 19-step wiring and remaining work.
Current source has review-level build-readiness/component scripts, external verifiers on several scripted steps,
an extracted/tested `run_conductor`, tag-age snapshot warnings and original-ref restoration.
Completed-phase pseudocode and shelved apply/parallel designs are retired; historical implementation remains in Git.
Remaining write acknowledgement, snapshot identity and recovery risks are review questions, not reproduced failures from this pass.

## Kubernetes plugin qualification and publication

The local plugin HEAD is `a477bced687c3385311bafddbf2ae1a3b0228ed0`: 82 commits beyond upstream
[PR #617](https://github.com/openshift-eng/ai-helpers/pull/617), and 13 beyond verified fork bak42 `febb7974696e870f933e8ad3741605d31ead0b5c`.
Fresh GitHub ref reads show the fork's working branch still at PR head `7e1aa060f3167de8a66e5191bf8e8692666c3ad4` and bak42 unchanged.
Neither checked remote ref includes the newest 13 commits; another backup was not ruled out. Preserve/verify source before any authorized PR update.

Two test files have uncommitted court-permission changes (+101/-10), separate from committed HEAD and its qualification evidence.
No plugin test, model call or rebase trial was run here. Preserve both source states and verify the installed bytes before qualification.

The [K-story payload](agentic-sdlc-jira-updates-payloads/k8s-rebase/epic-and-stories.md) owns detailed trial evidence:
Keep proposed K2 In Progress because legacy 1.36.2 PASS summaries lack the current evidence archive;
K3 requires valid measured outcomes, excludes zero-valued fallback metrics, and has no automatic YAML-judge execution;
K4 records CNCC requalification, accepted-with-limits Multus and initial MCP failures/inconclusive gates, including live CI still selecting 1.36.4.
The `a477bced` lessons commit and dirty tests need separate frozen-source qualification. These are source/report observations, not fresh trial results.
PR #617 still has WIP, invalid-OWNERS and needs-ok-to-test labels; preserve those review/test gates when preparing the source refresh.

## Adjacent work with separate ownership and scope

| Work | Observed state | Planning treatment |
| --- | --- | --- |
| Submariner ART strategy | Local October 6 assessment and Jira drafts exist; they describe a conditional pilot and ownership decisions | Preserve this as a proposal. Existing builder migration and ACM-integrated addon consumption are distinct from adopting ART for the independently released product; no migration epic is created here |
| ART dev/test consumption, ACM-45508 | New | Keep the proposed S1 related-issue link; prove addon consumption separately from FBC catalog/runtime support |
| PQC image readiness, ACM-41119 | New; updated October 5, targets OCP 5 GA. Addon release-5.0 already selects a PQC-minimal Konflux runtime base; main/5.1 does not | Verify actual image policy/build evidence and approved scope. Existing source configuration is partial evidence, not shipped-image proof; see [branch inventory](art-builder-migration.md#addon-branch-differences) |
| Addon OLMv1, ACM-37426 | New; description says ACM 5.0, July 24 comment targets 5.1. Private research has ClusterExtension/installer prototypes; least-privilege RBAC explicitly lacks two required parts | Preserve preparation; apply the prepared title/description correction only after target confirmation, then confirm current API before addon integration, complete/review RBAC and prove install behavior. Do not count templates as implementation or inherit the old 5.0 deadline |
| EVPN delivery plan, CORENET-7615 | To Do; planning #2, public-safety check #4 and build-root #5 merged. Appliance #6 and Ansible #3/#7 imports remain open; #7 verify fails | Record planning acceptance separately from implementation; record owners/dates as decisions are made, without requiring every pending decision to be settled. Current decision index still proposes owners; related 7501/7504/7505 retain conflicting criteria and have no resolution comments |
| Older route-agent build, ACM-34593 | October 2 hosted route-agent push build succeeds at `82adbacd`; its later EC scenario fails | Review closure of the original DNF/RPM build issue against that exact source/build; keep EC failure as separate compliance evidence. See the [queue](jira-update-queue.md) |
| Pre-merge automation, CORENET-7086 | To Do in the current assigned-work query | Reconcile its existing acceptance criteria before proposing overlapping pre-merge or qualification automation; it is separate from the plugin epic |
| MCN CI tooling, CORENET-7171 and implementation stories | Research In Progress; implementation stories remain To Do in the assigned-work query | Retain their existing scope; shared tooling ideas do not make them Kubernetes-plugin deliverables |

EVPN main is `306b8fe8a68cd878a9b8272b5329e5a6b8ac1e92` (October 5). Its current `make verify` runs the planning/public-safety checks, not appliance build or AWS qualification.
[Appliance #6](https://github.com/openshift/evpn-gateway-appliance/pull/6) has a passing verify check at the new October 7 head `629d9e671a94e6303ff46c2e97c78b310c672c63`; tide is pending and the PR remains open;
[Ansible #7](https://github.com/openshift/evpn-gateway-appliance/pull/7) fails verify at `55d471e0336fa3c6812fdf88a4ce38732bb7533b`.
[Earlier Ansible #3](https://github.com/openshift/evpn-gateway-appliance/pull/3) is also open; reconcile the overlapping import scope with its owners rather than assuming supersession.
Keep these other-contributor handoffs outside assigned-issue totals and the Kubernetes plugin epic.

Private research exports, teammate identities, credential contents and internal links are not copied into this public plan.
