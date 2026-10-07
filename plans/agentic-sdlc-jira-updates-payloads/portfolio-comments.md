<!-- markdownlint-disable MD013 -->

# Additional existing-issue updates

Prepared October 7, 2026; none posted. These drafts are independent of creating S/K stories.
Use the [assigned-issue queue](../jira-update-queue.md) for priority, evidence and status gates.
Refresh each target, omit already-recorded facts, convert rich text as needed, and set `Red Hat Employee` visibility at comment creation.
These comments propose no transitions. Private security details and internal research are excluded.

## ACM-39738 — contribution parent

Use this rollup if the parent needs a missing status delta; otherwise post the child-specific updates below and omit it.

```text
The existing CVE contribution children remain the right tracking scope for those skills:

* ACM-39739: https://github.com/submariner-io/shipyard/pull/2582 is now published at 0777e63c. Hosted checks are still running and GitHub reports changes requested; no current-head approval is recorded. Author-reported checks do not replace acceptance of this prerequisite or the separate ai-helpers merge.
* ACM-39740: https://github.com/dfarrell07/claude-skills/pull/35 merged October 6, delivering shipped-image applicability and provenance improvements. Product configuration extraction, contribution to ai-helpers and validation on a non-Submariner product remain.

Neither child has met its ai-helpers merge acceptance criterion. The parent's original criterion covers all generally relevant skills, so reconcile that inventory before parent acceptance. The k8s-rebase contribution remains open in https://github.com/openshift-eng/ai-helpers/pull/617; its qualification and upstreaming stay on existing CORENET-7155 tracking, without duplicate children here.
```

## ACM-39739 — CVE-fix contribution

Use this in place of the optional maintenance paragraph in `submariner-sustenance/comments-existing.md`; post once.

```text
The maintained prerequisite https://github.com/submariner-io/shipyard/pull/2582 was refreshed October 7 to 0777e63c3a429d86624c9302b4f4f01276115ad8. The local checkout is clean at that same head; the previously local follow-ups are now included in the published source. Hosted checks are still running, GitHub reports changes requested, and no current-head approval is recorded. Four unresolved threads are outdated; author responses do not establish acceptance.

The PR reports 1,372 regression checks, six focused probes and live client-go master/release-4.20 checks, with explicit scan/toolchain limits and no cluster E2E. Those runs were not repeated by this planning audit. Preserve the distinction between author-reported validation and the current head's hosted checks/reviewer acceptance.

Remaining for this story: acceptance of the prerequisite, configurable project-neutral go-fix-cves packaging, and merge into openshift-eng/ai-helpers. Keep the contribution open until its own criteria are met.
```

## ACM-39740 — CVE-agent contribution

Use this in place of the optional standalone cve-agent bullet in `submariner-sustenance/comments-existing.md`; post once.

```text
Preparatory CVE-agent work merged October 6: https://github.com/dfarrell07/claude-skills/pull/35. It improves shipped-image applicability and provenance, source/version mapping, mixed triage outcomes and multi-architecture digest handling.

This is a merge in the maintained source repository, not the ai-helpers contribution. Remaining acceptance criteria are product configuration extraction, merge into ai-helpers, and validation against at least one non-Submariner product's CVE issues. The contribution story remains unfinished.
```

## OPGM-364 — requested lifecycle status

```text
Status: At Risk.

Remaining work: merge lifecycle injection in https://github.com/stolostron/submariner-operator-fbc/pull/82, build the existing valid lifecycle fragment, and issue its FBC release with advisory/snapshot/IIB or catalog proof. Tooling/catalog preparation merged in https://github.com/stolostron/submariner-operator-fbc/pull/81; that is not publication evidence.

Blockers: #82's published build fails before tasks start because its build account is missing; the October 7 tenant read also finds the Application and Component absent. Local tenant/admission drafts need fresh-base review and reconciliation. Registry access for the push test and current publication proof remain unverified.
```

## ACM-45318 — builder migration inventory

```text
Source inventory is prepared for the October 15 builder migration. The inspected downstream component streams use UBI Go Toolset, while selected addon branches still use older Brew builders; Go floors and build paths differ by branch. Devel's Dapper builder and the addon's existing 5.0 PQC runtime selection are separate concerns.

Next: confirm the supported branches and migrate verified Brew/OSBS builder consumers, beginning with the affected addon paths. Existing UBI Go Toolset use does not by itself require this ART migration. Inspect transitive build inputs before classifying another path as affected; prepare reviewed changes with the applicable compiler, crypto, registry and build evidence. No builder migration or shipped-image verification is claimed by the inventory.

Inventory and handoff: plans/art-builder-migration.md in stolostron/submariner-release-management.
```

## CORENET-7086 — parent CI scope

```text
CI research is tracked in CORENET-7171, and implementation is already split into CORENET-7173 through CORENET-7199. The earlier draft's proposal to create those subtasks is superseded; no additional copies are needed.

The existing parent criteria still cover tests, coverage, formatting/lint, license headers and API compatibility. CORENET-7195 covers dependency licensing, not source headers; the existing 27 descriptions do not identify an API-compatibility implementation task. Reconcile those gaps before accepting the parent. Prow/cloud E2E remains CORENET-7083 scope; Kubernetes plugin qualification remains CORENET-7155 scope.

The implementation tasks remain To Do. Research and task creation do not establish configured or passing CI in the target repository.
```

## CORENET-7171 — research update

```text
The research recommendations are recorded, with 27 implementation subtasks already created under CORENET-7086 (CORENET-7173 through CORENET-7199). The existing May comments document the tool survey; this update distinguishes those recommendations from implementation.

The existing descriptions of CORENET-7196/7197/7198 already place AI security/RBAC/release-note automation after merge. They supersede the older research comment's PR-review wording; verify the intended execution boundary when implementing those tasks.

The original research deliverable is to evaluate tooling and document recommendations with rationale. Review that existing evidence for acceptance; implementation ownership, repository/forge choices and the parent's license/API gaps are downstream handoffs, not additional acceptance criteria silently added to this research story. No deployed or passing CI is claimed.
```

## CORENET-7615 — landed planning context

```text
The EVPN CI/CD planning context landed October 1 in https://github.com/openshift/evpn-gateway-appliance/pull/2. This satisfies the planning-PR landing criterion.

Remaining acceptance: confirm the artifact graph, release gates and responsibilities with reviewers; record owners/dates for open decisions, beginning with product home, cluster, payload and AMI channel; and obtain owner-recorded resolution of the three acceptance conflicts (CORENET-7501, CORENET-7504, CORENET-7505).

Current repository work has moved beyond planning: public-safety checks (#4) and a build-root (#5) merged October 5; appliance import #6 and Ansible imports #3/#7 remain open. #6 verify passes and #7 verify fails at the inspected heads. These are separate implementation handoffs; neither the planning merge nor static verification establishes product build/support acceptance. The current decision index still proposes owners, and 7501/7504/7505 retain the conflicting criteria without resolution comments. Keep this issue open pending its original acceptance review.
```

## ACM-26999 — older CVE scope

```text
The existing May progress comment already records production CVE tooling. Current hardening is tracked in ACM-39729, with upstream contribution split between ACM-39739 (go-fix-cves) and ACM-39740 (CVE agent).

Preparatory shipped-image/provenance improvements merged in https://github.com/dfarrell07/claude-skills/pull/35; https://github.com/submariner-io/shipyard/pull/2582 remains open. Neither establishes completion of the ai-helpers contribution criteria.

Please reconcile this older issue's remaining scope with those existing stories before choosing acceptance or supersession. There is no need to recreate the production tooling or file duplicate contribution stories.
```

## ACM-25779 — proposed description correction

This is a replacement description after reviewing the full original ADF; preserve useful existing links and other required fields.
Its May comment already explains deferral, so another copy of that comment is unnecessary.

```text
Complete the agreed Submariner pipeline migration to konflux-build-catalog. The console-specific template is unrelated to this issue; migration instructions remain https://github.com/stolostron/konflux-build-catalog.

The May update records addon adoption and explains that the five upstream component repositories and FBC use inline pipelineSpec with existing release automation. Confirm current branch coverage before changing pipelines.

The remaining decision is ownership and maintenance responsibility: adopting the ACM abstraction requires reconciling the existing Submariner pipeline-generation and release tooling. Keep the migration open pending that decision, consistent with the May comment. Confirm the adopted scope and supported branches before implementation; changing the task to assessment-only or marking it superseded requires a separate scope decision.
```

## ACM-44527 — remaining FBC blocker

The existing parent already records component-stage success; omit another copy. Post this delta once on the parent if still missing, rather than repeating it on six subtasks.

```text
The October 7 retained-snapshot check recovers all six 4.16–4.21 FBC snapshot/scenario identities at source 2e6b489e65620738d68504d9158418fe463e2073. All six have finished aggregate Failed verdicts and completed operator TestFail results; standard-test warnings do not override those failures. The exact map is recorded in plans/fbc-failure-recovery.md in stolostron/submariner-release-management.

The registry Secret remains absent from the integration runner's credential lists. Verify credential usability, field ownership and intended catalog content before a separately authorized repair/rerun. Component-stage success is confirmed separately; FBC stage/QE/production are still gated on their own successful evidence.
```

## ACM-45070 — candidate evidence reconciliation

Use only if this candidate is relevant to the intended release; the inspection does not select or approve it.

```text
The retained nine-component candidate submariner-0-22-20261002-125823-000-lz has aggregate TestSucceeded=True and completed integration results with warnings. Its bundle image has version v0.22.2 and CSV version 0.22.2 at digest sha256:cdbc25da3eb5bea32ee537a2fee2a943f7cd8a16507fb9dbfdc9d7f4e0d2a9d3, built from operator source da81d438c0456f367bc5e83e671362181a47ab63.

All seven CSV related-image digests differ from the mapped snapshot operands. Registry copying can change manifest digests; this comparison alone does not establish invalid content. The snapshot operator inspects as v0.22.2, while the embedded production operator could not be inspected. Reconcile source/content and registry identity before accepting the candidate, completing EC/bundle tracking or filling parent artifact references. No release completion is claimed.
```

## ACM-34593 — original build-failure acceptance review

The September closure request already exists. Add this new build evidence only if not recorded, then separately review the original DNF/RPM criteria and fix attribution before proposing a resolution.

```text
A newer route-agent-0-21 push build succeeded October 2 at source 82adbacdd58e1edaf4c11a8f2d07a94e3b3b84fc: https://github.com/submariner-io/submariner/runs/110847099550. Its retained snapshot is submariner-0-21-20261002-125839-000.

This supports reviewing acceptance of the original DNF/RPM build failure. Confirm the relevant fix/source and build criteria before resolving. The candidate's separate EC scenario fails; the successful push build does not establish release or compliance acceptance, and that failure needs its own investigation.
```

Other release/closure reviews and private security follow-up remain in the [queue](../jira-update-queue.md); no success payload is drafted from Jira status alone.
