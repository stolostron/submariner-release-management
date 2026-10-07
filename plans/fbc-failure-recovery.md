<!-- markdownlint-disable MD013 -->

# FBC failure recovery — current priority

Reviewed 2026-10-07; published checks, retained snapshots, component-stage release and local drafts rechecked.
The [current work map](current-work.md) records concurrent upstream repairs, release trackers and the independent October 15 builder-migration deadline. First unblock the existing **0.23.4 / OCP 4.16–4.21** FBC integration tests, then address the separate
OCP 5.0 PR prerequisite. Jira payload application remains a separate reviewed handoff.
No Release resource, live secret binding, snapshot rerun or GitLab submission has been applied by this review.

## Confirmed failures and proposed fixes

GitHub's published operator checks on FBC main `2e6b489e65620738d68504d9158418fe463e2073` failed September 30/October 1.
The exact snapshot/scenario/run map below combines those checks with retained cluster evidence.

All six report `get-unreleased-bundle` / `StepFailed`; their corresponding catalog push builds succeeded.
The saved September 30 4.19 step log shows repeated anonymous pulls of the production index returning `401 Unauthorized`.
The standard integration checks report warnings, not the operator failure; inspect the complete snapshot verdict before releasing.
These failures remain published/historical evidence. The October 7 authenticated read checked the explicit `submariner-tenant` namespace:

* `submariner-konflux-registry-redhat-io` exists with type `kubernetes.io/dockerconfigjson`; no credential data was read or printed.
* Its name is absent from both `secrets` and `imagePullSecrets` on `konflux-integration-runner`. This confirms the missing link; it does not verify credential usability.
* `submariner-fbc-5-0` Application and Component and `build-pipeline-submariner-fbc-5-0` are NotFound. Reconciliation remains a prerequisite.
* The latest namespace read returns zero PipelineRuns and 746 retained snapshots. The six exact failing FBC snapshot/scenario associations are recovered below; archived task logs are still needed for fresh diagnosis and historical root-cause comparison.

The earlier GitLab main-ref read failed DNS; fresh-base/controller ownership and credential usability remain unverified. The current six FBC snapshot verdicts are Failed. No link, resource or rerun was changed.

| Priority | Failure | Prepared action | Success evidence |
| --- | --- | --- | --- |
| P0 | 4.x operator test cannot authenticate the production-index render | Link the existing Red Hat registry secret to the integration runner; retain the link declaratively | New snapshot integration runs render the index successfully and meet the release gate |
| P1 | FBC #82 fails before its first task can start | Refresh and reconcile the existing 5.0 tenant draft, then rerun the PR | Expected live build SA exists and the exact PR head's Konflux check passes |
| P2 | Four task pins approach their October expiry | Refresh pins in a separate reviewed change after checking current trust/deny rules | Exact-head EC succeeds with the replacement refs |

Task expiry is not the demonstrated cause of the current failures. The OCP 5 catalog, profile access and runtime support remain separate rollout gates in the
[OCP 5 plan](ocp-5-0-fbc-rollout.md).

## Retained snapshot and scenario identities

October 7 authenticated reads recover one snapshot per 4.16–4.21 Application at FBC source
`2e6b489e65620738d68504d9158418fe463e2073`. All six have integration Finished=True, aggregate TestSucceeded=False/Failed,
and a completed operator scenario with TestFail. Standard scenarios finished with “passed with warnings”; their retained
`BuildPLRInProgress` strings do not mean the operator tests passed or are still running.

| OCP | Snapshot | Operator scenario | Recorded failed run |
| --- | --- | --- | --- |
| 4.16 | `submariner-fbc-4-16-20260930-152915-000` | `submariner-fbc-operator-4-16` | `submariner-fbc-operator-4-16-z2gvp` |
| 4.17 | `submariner-fbc-4-17-20260930-152915-000` | `submariner-fbc-operator-4-17` | `submariner-fbc-operator-4-17-5plbs` |
| 4.18 | `submariner-fbc-4-18-20260930-152916-000` | `submariner-fbc-operator-4-18` | `submariner-fbc-operator-4-18-d4pr2` |
| 4.19 | `submariner-fbc-4-19-20260930-152916-000` | `submariner-fbc-operator-4-19` | `submariner-fbc-operator-4-19-gc5df` |
| 4.20 | `submariner-fbc-4-20-20260930-152915-000` | `submariner-fbc-operator-4-20` | `submariner-fbc-operator-4-20-xswhp` |
| 4.21 | `submariner-fbc-4-21-20260930-152915-000` | `submariner-fbc-operator-4-21` | `submariner-fbc-operator-4-21-zzbxz` |

Each snapshot has its matching single FBC Component and immutable catalog-image digest. Those identities are retained privately with the raw evidence.
The association is established; source/image catalog-content and intended 0.23.4 bundle verification remain before mutation.
A missing live PipelineRun does not erase the snapshot's finished failed verdict. Re-read this map before a separately authorized rerun.

The component-stage snapshot `submariner-0-23-20260930-064533-000` is also retained with nine components and aggregate TestSucceeded=True.
Its EC/standard scenario finished with warnings. The recorded `submariner-0-23-4-stage-20260930-01` Release still reports Released=True/Succeeded,
matching the existing Jira artifact entry. This confirms the component-stage evidence, not FBC/QE/production completion; no duplicate component success comment is needed.

## Prepared registry-link repair

A separate release-data worktree contains a minimal change based on cached September 18 main:

* Local branch: `fix-fbc-integration-registry-access`; commit `3edd2876d3c3eaa31c573ada703fce1fe6c3f858`.
* Add `integration-runner-service-account.yaml` to the Submariner tenant's source directory and Kustomization.
* Commit the corresponding generated ServiceAccount. Its only declared credential reference is `secrets[].name: submariner-konflux-registry-redhat-io`.
* Leave `imagePullSecrets`, RBAC, token mounting, all pipelines and all channel settings unspecified by this repair.

This is a proposed tenant GitOps fix, not an FBC pipeline-code fix. Source inspection at integration-service
[`badd6dbac7e17bfe9f983a410bc1206ec78b5731`](https://github.com/konflux-ci/integration-service/blob/badd6dbac7e17bfe9f983a410bc1206ec78b5731/internal/controller/scenario/scenario_adapter.go)
shows it appends its component-registry `imagePullSecrets` entry and preserves existing fields; it does not replace the additional `secrets` list.
That supports the minimal manifest but does not establish the deployed controller version or ArgoCD's apply mode.
Review server-side ownership/dry-run results and current tenant policy before applying or merging.

The [Konflux private-registry guide](https://konflux-ci.dev/docs/testing/integration/accessing-private-repositories/) documents the required service-account link.
`oc secrets link` defaults to a **mount** link, which makes credentials available to Tekton's task initialization. An image-pull-only link is not equivalent
when a running task renders another registry's index.
An authenticated local `skopeo inspect --raw` of the 4.19 index succeeded during this review; it does not establish access from the integration pod or prove
that the named tenant secret is currently valid. No secret contents are committed or printed.

### Release-data merge-request scope

The local repository contains three independent drafts, all based on cached September 18 main:

| Change | Local branch | Config scope | Purpose |
| --- | --- | --- | --- |
| Registry repair | `fix-fbc-integration-registry-access` | Three files: source SA, Kustomization and generated SA | Restore 4.x integration-task credentials |
| 5.0 tenant onboarding | `ocp-5-work-ocp-5-0-tenant` | 16 configuration files; seven generated resources | Reconcile the Component and create #82's build account |
| 5.0 release admission | `ocp-5-work-ocp-5-0-admission` | Two existing RPA files, adding only the application | Enable later stage/prod release matching |

The tenant draft currently also rewrites its `CLAUDE.md`, making 17 files in its existing diff.
Separate that documentation change from the CI repair before submission; preserve the inspected draft until preparing the reviewed branch.
Keep one reviewable commit per submitted MR and source/generated tenant changes together. Existing CODEOWNERS covers all affected paths.
The two admission additions are not required to create the build account or to retest #82; keep them out of the immediate CI-fix path.
ReleasePlan/RPA matching, target-index readiness and release approval remain later rollout gates.

The cached repository has no declaration of the named Red Hat registry Secret or this integration-runner ServiceAccount.
The proposed link therefore depends on the existing live credential; do not add or recreate secret material from an assumed value.
Local files also do not establish the tenant's ArgoCD apply/pruning mode, so the controller/GitOps ownership check remains necessary.

### Restore and verify live access

1. Reconfirm authentication/namespace and the recovered snapshot/scenario map above. Verify each Application, FBC source URL/revision, catalog digest and actual 0.23.4 bundle contents before any rerun; do not choose a newer snapshot implicitly.
2. Read the current integration ServiceAccount and confirm the named registry secret exists with the expected Docker-config type.
   Validate that its `auths` entries contain usable credentials for `registry.redhat.io`; report registry names and pass/fail only, never credential values.
   Check for competing credentials for the same registry before assuming the merged configuration uses this secret. Save the original ServiceAccount and binding privately.
3. Confirm the current binding and field ownership. If it is already linked, stop and inspect the new task's credentials and logs rather than unlinking/relinking blindly.
   If absent and the live repair is authorized, add the documented link:

   ```bash
   oc secrets link konflux-integration-runner submariner-konflux-registry-redhat-io -n submariner-tenant
   ```

4. Read it back and verify the existing links remain. In the new TaskRun, verify credential initialization and that `opm` reads the resulting Docker configuration.
   Inspect credential-copy errors and any `HOME`, `DOCKER_CONFIG` or explicit auth-file override; a linked secret alone cannot prove usable runtime credentials.
   New TaskRun pods must receive the credentials; a ServiceAccount edit cannot repair an already-failed pod.
5. Refresh/rebase the separate declarative repair onto current GitLab main, review the diff and ownership, and submit it as a tenant-only merge request when authorized.
   GitLab currently fails DNS resolution, so cached-main checks are not current-main readiness. Retain live remediation until GitOps reconciliation is verified.

### Rerun the same release snapshots

Follow the [integration-test rerun procedure](https://konflux-ci.dev/docs/testing/integration/rerunning/).
Use the recovered identities above after re-reading their source/content and finished test state; do not guess from timestamps or select a newer snapshot with different content.
Initial tests must be finished. Rerun one affected snapshot first, then the other five after it passes:

```bash
oc label snapshot <verified-snapshot-name> test.appstudio.openshift.io/run=<verified-operator-scenario> -n submariner-tenant
```

The controller consumes/removes the label. Confirm that the new PipelineRun references the intended snapshot/scenario and that
`get-unreleased-bundle` successfully rendered the authenticated index. Retain its logs, task results and complete snapshot test verdict.
A `/retest` comment starts a build; it does not rerun the selected snapshot's integration tests.

The existing 4.x channel mismatch remains a separate coverage issue. An empty returned bundle and skipped install can be an aggregate ITS pass;
that is not installation or QE evidence. Do not change channels or provisioning versions merely to remove the registry failure.
Once all applicable snapshots satisfy the existing test/content/provenance checks, re-run the read-only release verification:

```bash
FBC_EXPECTED_COMMIT=2e6b489e65620738d68504d9158418fe463e2073 ./scripts/verify-fbc-release.sh 0.23.4
```

Confirm this is still the intended source revision before using the pin. This command validates release evidence; it does not authorize stage or production release.

### Rollback

Remove the link only if this recovery added it and the maintainer chooses rollback:

```bash
oc secrets unlink konflux-integration-runner submariner-konflux-registry-redhat-io -n submariner-tenant
```

Do not delete the shared registry Secret or the controller-managed ServiceAccount. For the declarative change, revert the credential reference and regenerate manifests;
do not use ServiceAccount deletion/pruning as the rollback strategy. Verify preserved controller/component links after reconciliation.

## Separate OCP 5.0 repair

[FBC #82](https://github.com/stolostron/submariner-operator-fbc/pull/82) fails with `PodCreationFailed`:
`build-pipeline-submariner-fbc-5-0` is absent. Do not replace it with another component's service account or weaken the pipeline to get a green result.
The existing 5.0 tenant draft requires fresh-main reconciliation, configuration-only scope and its own validation/review. Its Component reconciliation
creates the build account; the separate admission additions do not fix that build failure. Verify the Application, Component,
ImageRepository, generated build account and push-secret relationships live, then rerun #82 at its actual head.
A passing PR check still supplies no OCP 5 push-test, installation or release evidence. Track those gates in the [rollout plan](ocp-5-0-fbc-rollout.md).

## Validation and remaining access

The proposed registry-link manifest renders correctly and declares no replacement for controller-managed image-pull credentials.
Repository validation results are recorded in the [verification record](agentic-sdlc-jira-updates-verification.md).
Recheck Konflux authentication before a separately authorized repair/rerun; durable submission requires GitLab access and a fresh base.
No FBC failure is marked resolved until the corrected live run and existing release verification pass.
