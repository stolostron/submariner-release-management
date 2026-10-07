<!-- markdownlint-disable MD013 -->

# Additional existing-issue updates

Prepared October 7, 2026; none posted. These drafts are independent of creating S/K stories.
Use the [assigned-issue queue](../jira-update-queue.md) for priority, evidence and status gates.
Refresh each target, omit already-recorded facts, convert rich text as needed, and set `Red Hat Employee` visibility at comment creation.
The [approval order](../jira-update-queue.md#approval-order) is authoritative; groups below follow it. Groups 6 and 8 link to their separate payloads. These comments propose no transitions. Private security details and internal research are excluded.

## Group 1 — CI research handoff

### CORENET-7171 — correct the May handoff

One comment correcting two obsolete statements; preserve status. Parent coverage/ownership questions remain in the implementation plan.

```text
Implementation subtasks CORENET-7173 through CORENET-7199 were created on May 20, 2026 and are tracked under CORENET-7086. CORENET-7196/7197/7198 scope AI security/RBAC review and release-note suggestions to post-merge workflows (push to main), correcting the earlier PR-review wording.
```

CORENET-7086: no parent comment proposed. Its hierarchy already exposes the task split; post when there is a concrete implementation or ownership decision.

## Group 2 — CVE contributions

### ACM-39740 — CVE-agent contribution

One contribution update; keep the already-posted adoption/remediation progress on ACM-39729/39736. Include the agent's cve-jira-triage dependencies in its configuration review rather than creating a duplicate task.

```text
Preparatory CVE-agent work merged October 6 in https://github.com/dfarrell07/claude-skills/pull/35: shipped-image applicability and provenance, source/version mapping, mixed triage outcomes and multi-architecture digest handling.

Per-product configuration still needs extraction, including component/image mappings, version references, Jira scope and cve-jira-triage dependencies. The ai-helpers contribution and non-Submariner product validation remain unfinished.
```

### ACM-39739 — CVE-fix contribution

One contribution update; the September remediation counts and team adoption are already recorded on ACM-39729. Refresh the pinned PR snapshot before any authorized post.

```text
The CVE-fix prerequisite https://github.com/submariner-io/shipyard/pull/2582 is now at 4fa703b3c4302d559023963071aec4e0187e127a. At the latest October 7 read, all returned hosted checks pass or skip; a review requests changes on this head, four current threads remain unresolved and no current-head approval is recorded.

Source supports repository-registry configuration and native-command overrides. Project-level configuration without hardcoded Submariner values and the go-fix-cves contribution to ai-helpers remain unfinished.
```

ACM-39738: no parent rollup proposed. Post the two child updates only; the broader generally relevant skill inventory remains an owner/scope decision in the [queue](../jira-update-queue.md).

## Group 3 — EVPN planning handoff

### CORENET-7615 — reconcile planning decisions

Group 3: one planning comment, with the merged PR and its substantive discussion linked. Preserve To Do; no related-issue edits, decision-index edits or transitions are authorized.

```text
The delivery plan merged October 1 in https://github.com/openshift/evpn-gateway-appliance/pull/2. Its [merge discussion](https://github.com/openshift/evpn-gateway-appliance/pull/2#issuecomment-5936707328) records preliminary artifact-graph review, the OpenShift FRR/frr-metrics choice with planned standalone/EVPN-metrics fixes, and a transit-VIF resolution for CORENET-7501.

The published decision index still reflects the earlier proposals. Product home, Konflux cluster and AMI channel remain pending; release-gate/responsibility confirmation and owner corrections or recorded resolutions for CORENET-7501/7504/7505 remain unfinished.
```

## Group 4 — deadline and requested status

### ACM-45318 — builder migration inventory

```text
Prepared a [branch-by-branch source inventory](https://github.com/stolostron/submariner-release-management/blob/ecb3f1be31bbea22219e0487063772c4664d505f/plans/art-builder-migration.md) for the October 15 builder migration. It identifies Brew builders in the addon; sampled downstream component Dockerfiles use UBI Go Toolset. Supported addon branches and approved replacement ART tags remain to be confirmed before preparing changes.
```

### OPGM-364 — requested lifecycle status

```text
Status: At Risk.

Remaining work: land lifecycle injection (current draft https://github.com/stolostron/submariner-operator-fbc/pull/82), release existing valid PLCC data without new OpenShift 5 / 5.0 compatibility statements, and attach an advisory/snapshot/IIB reference plus redhat-operator-index:v5.0 membership or the allowed team IIB/catalog proof. Tooling/catalog preparation merged in https://github.com/stolostron/submariner-operator-fbc/pull/81.

Blockers: #82 cannot build because its account is missing; the October 7 tenant read also finds the Application and Component absent. Tenant configuration remains an unmerged local draft; registry access and publication proof remain unverified.
```

## Group 5 — release evidence

### ACM-44527 — remaining FBC blocker

The existing parent already records component-stage success; omit another copy. Post this delta once on the parent if still missing, rather than repeating it on six subtasks.

```text
The six 0.23.4 FBC recovery snapshots/scenarios for OCP 4.16–4.21 are now identified at source 2e6b489e65620738d68504d9158418fe463e2073: [exact recovery map](https://github.com/stolostron/submariner-release-management/blob/ecb3f1be31bbea22219e0487063772c4664d505f/plans/fbc-failure-recovery.md#retained-snapshot-and-scenario-identities).

The October 7 read retains finished failed operator tests and the unlinked registry Secret.
```

### ACM-45070 — candidate evidence reconciliation

Use only if this candidate is relevant to the intended release; the inspection does not select or approve it. Reconcile source/registry mapping before advancing EC/bundle steps or parent artifacts.

```text
Inspected candidate submariner-0-22-20261002-125823-000-lz passes aggregate integration with completed warning results. Its bundle digest is sha256:cdbc25da3eb5bea32ee537a2fee2a943f7cd8a16507fb9dbfdc9d7f4e0d2a9d3, with image label v0.22.2 and CSV version 0.22.2, from operator source da81d438c0456f367bc5e83e671362181a47ab63.

Source/registry mapping remains unreconciled: all seven embedded related-image digests differ from the mapped snapshot operands, and the embedded production operator could not be inspected. Registry copying can change manifest digests, so the comparison alone does not prove invalid content.
```

## Group 6 — independent epic descriptions

Use [ACM epic edits](submariner-sustenance/epic-description-edits.md) in order 4, 3, 5, then optional 1/2; review the [Kubernetes epic description](k8s-rebase/epic-and-stories.md#epic-corenet-7155-add-a-description-it-is-currently-empty) separately. Neither needs new story keys.

## Group 7 — scope and conditional corrections

The optional [ACM-39732 candidate note](submariner-sustenance/comments-existing.md#acm-39732-optional-progress-on-the-existing-url-conversion-story) belongs here; it is fork-only progress, not shipped functionality.

ACM-26999: no comment proposed. Its May update already records production tooling and the remaining upstream contribution. Resolve its scope/closure disposition before drafting another update.

### ACM-25779 — proposed description correction

This is a replacement description after reviewing the full original ADF; preserve useful existing links and other required fields.
Its May comment already explains deferral, so another copy of that comment is unnecessary.

```text
Complete the agreed Submariner pipeline migration to konflux-build-catalog. Migration instructions: https://github.com/stolostron/konflux-build-catalog.

Addon adoption is recorded in the May comment. Migration of the upstream component repositories and FBC remains pending an ownership/maintenance decision because existing Submariner release automation assumes inline pipelineSpec. Supported branches and the required tooling changes remain to be agreed.
```

### ACM-37426 — OLMv1 target correction

Apply only after the issue owner confirms the July 24 target is still ACM 5.1 (February 2027). Update the title and description together; make no status change or duplicate timeline comment. Save the original ADF, preserve its analysis-document link on `analysis doc` below, and retain other useful reference nodes. Confirm fresh-install/migration scope with the owner; do not silently transfer the old 5.0 contract to 5.1.

* Original title: `Support OLMv1 for Submariner addon in ACM 5.0`
* Proposed title: `Support OLMv1 for Submariner addon in ACM 5.1`

Proposed description:

```text
Submariner addon OLMv1 support targets ACM 5.1 (February 2027), per the July 24 timeline clarification (analysis doc). stolostron/submariner-addon deploys operators on managed clusters via OLMv0 (Subscription + OperatorGroup) and needs to support OLMv1 (ClusterExtension).

The earlier ACM 5.0 analysis scoped fresh installs only and left upgrade migration without a committed timeline. The fresh-install/migration contract for ACM 5.1 remains unconfirmed.

Reference: [MCH#4109](https://github.com/stolostron/multiclusterhub-operator/pull/4109).
```

## Group 8 — new tracking

Approve [ACM stories](submariner-sustenance/new-stories.md) in order S4, S2, S3, S1, S5 and [CORENET stories](k8s-rebase/epic-and-stories.md) separately. Omit epic summaries that repeat the child tracking; status changes require acceptance/workflow review.

## Group 9 — acceptance reviews

ACM-34592 and ACM-40644 retain acceptance-review dispositions in the [queue](../jira-update-queue.md). They have no unconditional closure payload.

### ACM-34593 — original build-failure acceptance review

The September closure request already exists. Add this new build evidence only if not recorded, then separately review the original DNF/RPM criteria and fix attribution before proposing a resolution.

```text
A newer route-agent-0-21 push build succeeded October 2 at source 82adbacdd58e1edaf4c11a8f2d07a94e3b3b84fc: https://github.com/submariner-io/submariner/runs/110847099550. Its retained snapshot is submariner-0-21-20261002-125839-000.

The snapshot's separate EC scenario fails; the successful build supplies build evidence, while compliance remains unresolved.
```

Other release/closure reviews and private security follow-up remain in the [queue](../jira-update-queue.md); no success payload is drafted from Jira status alone.
