<!-- markdownlint-disable MD013 -->

# Additional existing-issue updates

Group 1 posted and verified October 7, 2026 at 22:59 UTC; the group 4 lifecycle comment posted and verified October 8 at 09:37 UTC. Other updates remain pending. These updates are independent of creating S/K stories.
Use the [assigned-issue queue](../jira-update-queue.md) for priority, evidence and status gates.
Refresh each target, omit already-recorded facts, convert rich text as needed, and set `Red Hat Employee` visibility at comment creation.
The [approval order](../jira-update-queue.md#approval-order) is authoritative; groups below follow it. Groups 6 and 8 link to their separate payloads. These comments propose no transitions. Private security details and internal research are excluded.

## Group 1 — CI research handoff

### CORENET-7171 — correct the May handoff

Completed: comment `18824859`, created October 7 at 22:59 UTC with initial `Red Hat Employee` visibility. Approved text, rendered links and unchanged In Progress status were verified. The block below is a fixed posted record; do not repost it. Parent coverage/ownership questions remain in the implementation plan.

```text
Implementation subtasks CORENET-7173 through CORENET-7199 were created on May 20, 2026 and are tracked under CORENET-7086. CORENET-7196/7197/7198 scope AI security/RBAC review and release-note suggestions to post-merge workflows (push to main), correcting the earlier PR-review wording.
```

CORENET-7086: no parent comment proposed. Its hierarchy already exposes the task split; post when there is a concrete implementation or ownership decision.

## Group 2 — CVE contributions

Reviewed October 7, 2026 at 23:11 UTC; two child comments only, in the order below. Both issues remain New. Refresh targets and mutable PR evidence before posting; verify each restricted comment, including its rendered text/links, before the next write.

### ACM-39740 — CVE-agent contribution

One contribution update; keep the already-posted adoption/remediation progress on ACM-39729/39736. Include the agent's cve-jira-triage dependencies in its configuration review rather than creating a duplicate task.

```text
Preparatory CVE-agent work merged October 6 in https://github.com/dfarrell07/claude-skills/pull/35: shipped-image applicability and provenance, source/version mapping, mixed triage outcomes and multi-architecture digest handling.

Per-product configuration still needs extraction, including component/image mappings, version references, Jira scope and cve-jira-triage dependencies. The ai-helpers contribution and non-Submariner product validation remain unfinished.
```

### ACM-39739 — CVE-fix contribution

One contribution update; the September remediation counts and team adoption are already recorded on ACM-39729. Refresh the pinned PR snapshot before any authorized post.

```text
The CVE-fix prerequisite https://github.com/submariner-io/shipyard/pull/2582 remains open at 453dbbb47ad189b86d811aeff0c18b71115126e1. At the October 7, 23:11 UTC read, all returned hosted checks pass or skip; the latest changes-requested review is on the previous head, two current threads remain unresolved and no current-head approval is recorded.

This PR implements per-repository .cve-fix.yaml overrides and repository-registry configuration. Remaining Submariner-specific defaults and the go-fix-cves merge into ai-helpers still need resolution against this story’s acceptance criteria.
```

ACM-39738: no parent rollup proposed. Post the two child updates only; the broader generally relevant skill inventory remains an owner/scope decision in the [queue](../jira-update-queue.md).

## Group 4 — deadline and requested status

Partially complete: the lifecycle comment is posted; ACM-45318 remains a reviewed, unposted October 7 draft. Refresh the builder target and source evidence before separately approved posting. Future lifecycle comments must add a missing delta; the posted record below must not be reposted. No workflow transition or program label was assigned.

### ACM-45318 — builder migration inventory

```text
Prepared a [branch-by-branch source inventory](https://github.com/stolostron/submariner-release-management/blob/4460072eac2b8f88c72bab567078fe42873e0b1c/plans/art-builder-migration.md) for the October 15 ART builder migration. Direct Brew consumers are in the addon; all 18 ticket-listed downstream component Dockerfiles across 0.22–0.24 use UBI Go Toolset.

Remaining work: confirm supported addon build sources, select documented ART replacement tags, verify CI entitlement and qualify the compiler and release architectures. The inventory does not establish a completed migration.
```

### OPGM-364 — requested lifecycle status

Completed: comment `18829498`, created October 8 at 09:37 UTC with initial `Red Hat Employee` visibility. Exact ADF, rendered text/links, unchanged In Progress status and prior comments were verified. The block below is a fixed posted record; do not repost it.

```text
Lifecycle publication is pending. Tenant configuration blocks the build.

Catalog/tooling preparation merged in https://github.com/stolostron/submariner-operator-fbc/pull/81.

Remaining work: reconcile tenant resources, merge lifecycle injection in https://github.com/stolostron/submariner-operator-fbc/pull/82, and release existing valid PLCC data without new OpenShift 5 / 5.0 compatibility statements. Record the release advisory/snapshot/IIB and redhat-operator-index:v5.0 membership or team IIB/catalog proof.

Blockers observed October 7: the published build fails at init for a missing build account; the tenant also lacks the Application and Component. Refreshing GitLab main fails DNS. Registry access remains unverified.
```

## Group 5 — release evidence

Reviewed October 8, 2026 against both parents, all 32 children and their complete histories. One recovery-map comment is ready for review; the candidate comment remains conditional on release relevance. Preserve fields/statuses and refresh mutable evidence before any approved post.

### ACM-44527 — exact recovery map

The parent already records component-stage success, the failed FBC tests and registry diagnosis. Add only the missing exact recovery map, once on the parent.

```text
The six 0.23.4 FBC recovery snapshots/scenarios for OCP 4.16–4.21 are identified at source 2e6b489e65620738d68504d9158418fe463e2073: [exact recovery map](https://github.com/stolostron/submariner-release-management/blob/0d23d60a992aeb432a0cd72ad868d256427ce35f/plans/fbc-failure-recovery.md#retained-snapshot-and-scenario-identities).
```

### ACM-45070 — conditional candidate evidence

The October 2 candidate is absent from the full release-target histories. Use only after confirming its relevance to the intended release; inspection does not select or approve it. Production operand identity remains a prerequisite to advancing EC/bundle steps or parent artifacts.

```text
The October 8 inspection of candidate submariner-0-22-20261002-125823-000-lz confirms completed aggregate integration with warnings. Its bundle digest is sha256:cdbc25da3eb5bea32ee537a2fee2a943f7cd8a16507fb9dbfdc9d7f4e0d2a9d3, with image label v0.22.2 and CSV version 0.22.2. Bundle source da81d438c0456f367bc5e83e671362181a47ab63 and snapshot operator source b416904aa589f54ff8ba0b270e80968cd5872218 contain the same CSV.

Production operand identity remains unverified: all seven embedded related-image digests differ from the mapped snapshot operands, and the embedded production operator returns manifest unknown. Registry copying can change manifest digests, so these results do not establish invalid content or release readiness.
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

## Group 3 — EVPN planning handoff

### CORENET-7615 — reconcile planning decisions

Deferred to the end of the queue at the maintainer’s request. October 7 report: another planning PR iteration is WIP and CI PRs will start soon. Refresh this retained draft before review. Group 3: one planning comment, with the merged PR and its substantive discussion linked. Preserve To Do; no related-issue edits, decision-index edits or transitions are authorized.

```text
The delivery plan merged October 1 in https://github.com/openshift/evpn-gateway-appliance/pull/2. The October 1 [review discussion](https://github.com/openshift/evpn-gateway-appliance/pull/2#issuecomment-5936707328) records preliminary artifact-graph review, the OpenShift FRR/frr-metrics choice with planned standalone/EVPN-metrics fixes, and a transit-VIF resolution for CORENET-7501.

The decision index on main still needs these outcomes recorded with owners and dates. Open [appliance PR #6](https://github.com/openshift/evpn-gateway-appliance/pull/6) proposes host-installed FRR for RHEL 10; reconcile it with the recorded payload choice. Product home, Konflux cluster and AMI channel remain pending. Release-gate/responsibility review and owner-attributed recording of the CORENET-7501/7504/7505 criteria resolutions remain unfinished.
```
