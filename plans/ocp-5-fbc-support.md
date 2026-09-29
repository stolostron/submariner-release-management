# OCP 5.0 FBC support: investigation and implementation plan

Historical investigation of the pre-implementation baseline. Many defects and
proposed changes below have since been addressed. Use the
[implementation status](ocp-5-implementation-status.md) for completed work and the
[skill completion plan](ocp-5-skill-completion-plan.md) for the current remaining work.

Investigated on 2026-09-24. “OCP 5” is interpreted as OCP 5.0.

The follow-up [onboarding skill/workflow audit](ocp-5-onboarding-workflows.md) adds reproduced failure cases and
a proposed phased interface. In particular, current FBC tests can erase an uncommitted new catalog, and the
4.22 onboarding already required a manual fallback when the bot did not create a PR.

Adding 5.0 builds is feasible with the existing FBC architecture. The OCP 5.0 base image and production index exist,
and an isolated amd64 build of the existing Submariner catalog Dockerfile passed validation and served successfully.
The substantial work is making release automation understand a full OCP major/minor version, onboarding the new
Konflux application, and proving that installation tests actually exercise OCP 5.0.

This investigation created no commits in the working repositories, remote branches, Release CRs, or deployed resources.
The only repository changes are plan documents. Build, generation, and failure-reproduction experiments used temporary copies.

## Verified results

| Check | Result |
| --- | --- |
| OCP 5.0 operator-registry image | Available for amd64, arm64, ppc64le, and s390x |
| Public OCP 5.0 operator index | Available for the same four architectures |
| Existing Dockerfile with the 5.0 base | Local amd64 build succeeded, including `opm serve --cache-only` |
| Built fragment validation | The image's `opm validate /configs` succeeded |
| Catalog server | `/bin/grpc_health_probe -addr=localhost:50051` returned `SERVING` |
| Image version provenance | OCI base annotation contains the actual `openshift5/...:v5.0` image |
| Temporary 5.0 tenant overlay | Overlay and full tenant Kustomize renders succeeded; seven new resources |
| Existing Release YAML generator | Rejects `5-0` with “Expected: 4-14 through 4-29” |
| Existing release scope helper | Finds the 4.22 fixture, silently omits an equivalent 5.0 fixture |
| Existing minor-only sort | Sorts `5-0` before `4-22` |
| Catalog cutoff `"5.0": "0.23"` | Generates `stable-0.24` with bundles 0.24.0 and 0.24.1 |
| Catalog cutoff `"5.0": "0.24"` | Generates no channels or bundles from the current template |
| Install-test version selection | With 5.0 requested and only 4.21/4.22 available, succeeds with 4.22 |

The catalog used in the build experiment was a copy of `catalog-4-22`, renamed `catalog-5-0`. This establishes
Dockerfile, catalog format, cache, and serving compatibility. It does not establish Submariner runtime support on
OCP 5.0 or select 0.24 as the supported product stream. Other architectures were checked for available manifests;
they were not built or executed locally.

## External prerequisites and precedent

The correct observed base image is:

```text
registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0
```

The repository namespace changes from `openshift4` to `openshift5`; the observed image still uses RHEL 9.
Changing only the tag on the existing `openshift4` path is not the verified configuration.

Observed manifest-list digest:

```text
sha256:bd914d872e4a082a61dbd502ef2069fdd23d401c37bc6457cbf81e77078155b5
```

The public production index also resolves:

```text
registry.redhat.io/redhat/redhat-operator-index:v5.0
sha256:508ce3c8978067c61daf8296d8ad22a7e6d44cc3a3b07dba11c98bd316d713ef
```

Its labels identify delivery version `v5.0`, distribution scope `prod`, and FBC directory `/configs`.
Extraction of `/configs/submariner/` succeeded but produced no files. That is evidence of no Submariner content at
the expected package path in this observed image, rather than a full semantic search of the entire index.
Image availability alone is not an ACM/Submariner support announcement or proof that staging publication will succeed.

[VolSync's existing 5.0 pipeline][volsync-pipeline] uses this exact base-image path and all four architectures.
[VolSync PR 142][volsync-pr] is a merged example of staging a release that includes OCP 5.0.
The local `konflux-release-data` main also contains BGP cloud connector 5.0 FBC Applications, Components, ReleasePlans,
and RPAs on the same Konflux cluster as Submariner. Those RPAs use the same index templates as Submariner.

The live Submariner namespace has FBC Applications, Components, and stage/prod ReleasePlans through 4.22, including
retained 4.14/4.15 resources. It has no 5.0 equivalents. No existing Submariner FBC PR was found by a `5.0` title search.

## Changes in submariner-release-management

The central problem is representation: `FBC_OCP_VERSIONS` stores only minors (`16 ... 22`), and callers reconstruct
every version by prepending `4`. Appending `0`, `5.0`, or `5-0` to that list is not sufficient.

| File | Current assumption or failure | Required change |
| --- | --- | --- |
| `scripts/add-fbc-ocp-version.sh` | `^4-[0-9]+$`, `4-*-overlay`, minor-only sort | Full-version validation and discovery |
| `scripts/lib/fbc-scope.sh` | Minor list; searches `releases/fbc/4-$version` | Canonical full IDs throughout scope |
| `scripts/verify-fbc-release.sh` | `catalog-4-*`, snapshot names, keys, and temporary paths | Preserve the complete OCP ID |
| `scripts/create-fbc-releases.sh` | Prod glob `4-*`; prepends `4-` to verification output | Full IDs for stage and prod |
| `scripts/generate-fbc-release.sh` | Allows only `4-14` through `4-29` | Validate major/minor syntax |
| `scripts/get-fbc-urls.sh` | Removes `4.`/`4-`; constructs `v4.*` indexes and paths | Normalize and format full IDs |
| `scripts/lib/prod-bundle.sh` | `prod_index_has_bundle` takes a minor; builds `:v4.*` | Accept the complete OCP version |
| `scripts/release-status.sh` | Minor-based discovery, matching, and range display | Full IDs and accurate mixed-major output |
| `scripts/autorelease.sh` | Scope/index callers; prefixes `4.` in messages | Update the caller contract and output |
| `scripts/lib/jira-tracker.sh` | Describes `4.<first> through 4.<last>` | Format full versions in generated descriptions |

The generic Release CR field/data validators do not impose an OCP 4-only rule. The Makefile's existing
`OCP_VERSION` argument plumbing is also reusable. `scripts/fbc-catalog-update.sh` already stages `catalog-*/`.

### Recommended version contract

Use the hyphenated major/minor ID already present in resource and directory names as the internal representation:

```text
4-16 4-17 4-18 4-19 4-20 4-21 4-22 5-0
```

Accept `5.0` and `5-0` at CLI boundaries. Require an explicit minor version rather than interpreting arbitrary
bare integers. Format `5.0` for display and `v5.0` for registry tags. Do not strip the major component anywhere.
Separate valid syntax from the configured active set, so a syntax change does not activate unknown catalogs.

Keep the existing centralized active-version list, converted to full IDs. Represent retired catalog versions
explicitly when auditing historical catalog consistency; do not infer active build support from every retained directory.
Membership in a release must also depend on whether that Submariner bundle is applicable to the catalog.

Change the verifier and its consumer together. For example, their internal JSON contract should become:

```json
{
  "applicable_versions": ["4-22", "5-0"],
  "snapshots": {
    "4-22": "submariner-fbc-4-22-example",
    "5-0": "submariner-fbc-5-0-example"
  }
}
```

Use version-aware or numeric major/minor sorting. Overlay template selection should accept an explicit source
or select an appropriate preceding version: after 5.0 exists, adding a late 4.23 overlay must not accidentally
choose 5.0 just because it is the greatest version.

Validate onboarding arguments before fetching, switching branches, or modifying another repository. Currently
the onboarding script switches to `konflux-release-data/main` before rejecting a 5.0 argument.
It also deletes an existing local feature branch and commits automatically; add a safe review/dry-run path before
using it for this migration. These are script behaviors, not prerequisites imposed by OCP 5.0.

### Release correctness issues to address with the migration

1. **Active catalogs can disappear from verification.** `verify-fbc-release.sh` skips a catalog when there is no
   snapshot, then narrows `applicable_versions`. Once 5.0 is activated and contains the requested bundle, missing
   build/test evidence should block that release. Preserve deliberate handling of retired 4.14/4.15 catalogs.
2. **Keep stage/prod snapshot identity.** Prod currently reuses the version-specific stage YAML's snapshot. Extend
   that behavior to 5.0; never reselect a newer snapshot during promotion.
3. **Versioned release names need recognition.** The generator now emits names such as
   `submariner-fbc-5-0-0-24-1-stage-YYYYMMDD-NN`. The live-status matcher still expects the historical form without
   a Submariner version. Match both formats, preferably by reading the selected YAML's `metadata.name`.
4. **Date-only scope can miss later onboarding.** Scope inference uses a ±3-day window around the component release.
   Publishing an already-released bundle to 5.0 weeks later falls outside it. Prefer exact versioned filenames for
   modern records, retaining date inference only for historical names that lack the Submariner version.
5. **Do not mistake registry URLs for publication verification.** `get-fbc-urls.sh --prod-index` confirms the bundle
   image exists and prints index URLs; it does not establish that every requested index contains that bundle.
   Verify the actual 5.0 index content after promotion.
6. **Readiness is more than an annotation.** The verifier currently permits `BuildPLRInProgress` as passing.
   The live 4.22 snapshot inspected had that status alongside “passed with warnings.” For the first 5.0 rollout,
   inspect actual build, EC, and installation outcomes before treating the snapshot as ready.

The high-level create command has no per-OCP filter today. Decide whether initial onboarding should regenerate
all applicable release YAMLs or introduce a validated `--ocp 5.0` option. An isolated 5.0 release must still use
the normal bundle, snapshot, test, and promotion checks.

## Changes in submariner-operator-fbc

### Catalog contents and the cutoff trap

`scripts/generate-catalog-template.sh` already discovers OCP keys from `drop-versions.json` and converts dots to
hyphens. The renderer treats all templates except 4.14/4.15/4.16 as requiring
`--migrate-level=bundle-object-to-csv-metadata`, which includes 5.0. No separate FBC schema was needed for the build probe.

However, the map is not an inclusive minimum despite the onboarding docs' `MIN_SUB` terminology. The generator
appends `.99` to its configured value and prunes versions below or equal to that threshold. Channels of that
stream are removed too. With the current template:

| Entry | Actual result |
| --- | --- |
| `"5.0": "0.23"` | Retains the 0.24 channel and its 0.24.0/0.24.1 bundles |
| `"5.0": "0.24"` | Retains no channels or bundles; 0.25 is not present yet |

Choose the first supported Submariner stream explicitly. If 0.24 is intended, the current cutoff convention needs
`0.23`; if 0.25 is intended, first add the appropriate 0.25 bundle/channel and use `0.24` under that convention.
This is not a recommendation to support either stream on 5.0.

For minimal scope, document/rename the cutoff accurately. Changing it to an inclusive minimum is possible, but
requires migrating every existing map entry and proving all existing catalog contents remain unchanged.
Check default-channel existence, retained upgrade edges, `replaces`, `skipRange`, and bundle image identity.

### Pipeline and tooling changes

Add `catalog-5-0/` and the 5.0 map entry, plus push and PR PipelineRuns with:

```yaml
- name: build-args
  value:
    - INPUT_DIR=catalog-5-0
    - OPM_IMAGE=registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0
```

Use the new component/application name `submariner-fbc-5-0`, its generated service account and registry path,
and the existing four build platforms. Preserve the Submariner pipeline's current task references and policies;
VolSync is evidence for the base-image choice, not a replacement pipeline template.

Path filters should cover both new PipelineRuns, `catalog-5-0/***`, `catalog.Dockerfile`, and
`.tekton/images-mirror-set.yaml`. The generated catalog must be committed alongside template/map changes;
changing the template alone is not enough to trigger a catalog-directory-filtered build.

Additional concrete updates:

- `build/build.sh`: cleanup only removes `catalog-template-4-*.yaml`; include 5.0 intermediates.
- `scripts/reset-test-environment.sh`: has the same OCP 4-only cleanup assumptions.
- `test/scripts/test-build.sh`: discovers and validates only `catalog-4-*/`; include 5.0.
- `test/scripts/test-generate-catalog-template.sh`: hardcoded expected set stops at 4.21; derive/test the configured set.
- `test/e2e/test-workflow-e2e.sh`: minor-only `catalog-4-$v` loop misses 5.0.
- `Makefile build-image`: builds the first discovered catalog with the default upstream OPM image. Add explicit
  catalog/base-image selection or a matrix so image CI actually tests 5.0 with the production 5.0 base.
- `Makefile validate-catalogs`: ensure any failed catalog validation makes the target fail, rather than relying on
  the last loop iteration's exit code.
- README, Dockerfile base-image guidance, and onboarding/update workflows: describe full versions and cutoff semantics.

Local generation pins OPM v1.56.0, one rendering path uses upstream `latest`, the Dockerfile default is v1.65.0,
and production uses the OCP-tagged base. The successful build probe removes an immediate serving-format concern,
but version-specific validation should use the actual target base as well as local generation tooling.

## Changes in konflux-release-data

Under `tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/`:

1. Add `overlay/application-submariner-fbc/5-0-overlay/`, based on the eight files in `4-22-overlay/`.
2. Update the tenant `kustomization.yaml`.
3. Regenerate manifests from source. The isolated render produced the expected objects below.
4. Add `submariner-fbc-5-0` to the existing stage and prod RPA application lists under
   `config/kflux-prd-rh02.0fk9.p1/product/ReleasePlanAdmission/submariner/`.

```text
Application              submariner-fbc-5-0
Component                submariner-fbc-5-0
ImageRepository          imagerepository-submariner-fbc-5-0
ReleasePlan              submariner-fbc-release-plan-stage-5-0
ReleasePlan              submariner-fbc-release-plan-prod-5-0
IntegrationTestScenario  submariner-fbc-operator-5-0
IntegrationTestScenario  submariner-fbc-standard-5-0
```

Stage and prod use separate existing RPAs and retain `auto-release: false`. Keep the two GitOps workflows distinct
in review: tenant infrastructure reconciles through ArgoCD; managed RPA configuration is applied by its separate CI flow.
Existing CODEOWNERS patterns cover both the tenant subtree/generated subtree and Submariner RPA files.

No OCP-specific hardcoded index URL needs replacing in those RPAs:

```text
stage fromIndex: registry-proxy.engineering.redhat.com/rh-osbs/iib-pub-pending:{{ OCP_VERSION }}
prod fromIndex:  registry-proxy.engineering.redhat.com/rh-osbs/iib-pub:{{ OCP_VERSION }}
prod target:     quay.io/redhat-prod/redhat----redhat-operator-index:{{ OCP_VERSION }}
```

At the inspected production release-service revision, OCP is extracted from the fragment's
`org.opencontainers.image.base.name` annotation, including the per-architecture manifest for an image index.
The accepted regex is `^v[0-9]+\.[0-9]{1,2}$`, so `v5.0` is accepted and substituted into these templates.
The local probe image's annotation produced `v5.0` with this extraction logic.

The checked-out release-service development code additionally supports an explicit version label; the inspected
production filter did not. Do not assume that development feature is deployed. Preserve the expected base-image
annotation, and recheck extraction if changing digest/tag conventions.

GitLab DNS was unavailable during this investigation. Configuration conclusions use the local merged main from
2026-09-18 plus live Submariner resource reads. Internal staging-index reachability and IIB publication were not tested.
Before implementation, refresh main and follow its current generation and `tox` requirements.

## Installation and product support need separate evidence

The current operator ITS base sets `CHANNEL_NAME=stable`. This is also the live value for 4.22, while the actual
4.22 catalog contains `stable-0.24` and defaults to that channel. The current upstream unreleased-bundle step exits
successfully with no bundle when nothing matches the selected package/channel; later installation tasks are conditional.

For the new overlay, select the intended versioned channel or use an empty channel value to resolve the catalog
default. Verify that an unreleased bundle was selected and installation actually occurred. The recently recorded
4.22 test PipelineRun was already garbage-collected, so this investigation does not claim its particular run skipped.

There is a second independent gap: the [cluster-version selection step][pick-version] substitutes the highest
available EaaS OCP version when the fragment requests a newer version. A controlled execution of its current script,
with a stubbed fragment version `v5.0` and available versions `4.21 4.22`, returned success and selected `4.22`.

First-release acceptance must explicitly check the provisioned cluster is 5.0. If EaaS cannot supply 5.0,
use a suitable separately provisioned test cluster and record that evidence. Do not count a 4.x fallback as OCP 5 validation.

QE should cover the chosen Submariner bundle's installation, operand startup, CRDs/RBAC, cross-cluster connectivity,
service discovery, Globalnet where supported, and a supported upgrade path. Include disconnected mirrors and relevant
architecture/FIPS coverage according to the product's support requirements. Catalog build success does not cover these.
The local operator working tree contains existing user changes and was not modified or treated as released support evidence.

## Suggested implementation and rollout order

1. Confirm the initial supported Submariner stream and whether the immediate milestone is builds, staging, or production.
2. Land full-version plumbing and mixed-major regression tests in release management. Keep 5.0 activation separate
   from accepting its syntax until its catalog and expected build resources are ready.
3. Prepare the FBC map/catalog, pipeline changes, and ITS channel correction against current main.
4. Merge tenant onboarding first and discover the normal Konflux-generated pipeline PR; review RPA changes through
   their managed-config workflow. Wait for actual Application/Component/ImageRepository/ReleasePlan reconciliation.
   If the bot does not open a PR, use the verified manual pipeline preparation path documented in the follow-up audit.
5. Complete the bot or manual PR with catalog content, correct base image/build arguments, triggers, service account,
   and current task references. Review PR EC results according to the existing Submariner policy.
6. Merge the FBC changes, activate 5.0 in release orchestration, and require a successful main-branch snapshot
   with all four built architectures and verified catalog/bundle digests.
7. Create/apply the 5.0 stage Release through the normal workflow. Verify IIB completion and actual 5.0 installation.
8. Promote only after the chosen support/QE requirements are met, preserving the exact stage snapshot.
9. Confirm the expected bundle/channel exists in the public `v5.0` index; then share the verified URLs and close tracking.

The release-management onboarding document currently lists catalog source first, while the FBC and tenant workflows
require tenant onboarding first so the bot creates pipeline files. Reconcile that ordering during implementation.

## Regression and acceptance matrix

- Normalize `4.22`, `4-22`, `5.0`, and `5-0`; reject malformed IDs; sort 4.9, 4.10, 4.22, 5.0, and 5.1 correctly.
- Add 5.0 from 4.22, then 5.1 from 5.0; test explicitly selecting a 4.x template after a 5.x overlay exists.
- A failed onboarding preflight must not change branches or erase local work.
- Generate both stage/prod names and paths for 5.0; reject a snapshot belonging to another OCP version.
- Verifier JSON and release creation must agree on complete IDs, including mixed-major batches.
- Missing required 5.0 snapshots/tests must block; genuine bundle inapplicability and retired catalogs remain explicit.
- Production uses the exact 5.0 stage snapshot even when a newer build exists.
- Scope/status handles both historical and versioned filenames and a delayed 5.0 release of an older component version.
- URL lookup, garbage-collected Release fallback, index membership checks, tracker text, and auto-close all retain 5.0.
- Cover cutoff boundaries, nonempty channels, valid default channels, and upgrade edges; preserve all existing 4.x catalog content.
- Catalog tests enumerate 5.0, clean 5.0 intermediates, and fail when the new catalog is invalid.
- Build the production-style 5.0 image on all four architectures, then inspect OCI version provenance and catalog contents.
- Assert actual install-test execution and a 5.0 cluster; explicitly reject skipped installs or lower-version fallback as support proof.

## Evidence and reproduction

Repository revisions inspected:

- Release management: `1fa5052e01c8dc8c09b506610bb807b04fe45f06` (also current remote main at inspection).
- FBC local checkout: `a4de6c6`; remote main at inspection: `b3bd5f3a449001e51d7d385a72f5d6f5cda4a7a1`.
  These diverge in the 14 existing Tekton files; the inspected catalog map remains identical. Refresh pipeline references
  against remote main when preparing a change. This investigation did not reset either checkout.
- Konflux release data: `8c18efee295889f5d86b03d16930a2f11977fd58`.
- Release-service production: `155acaca6dff636f322238d5edbe60d22abaeb5c`.

Temporary evidence is at `/tmp/ocp5-fbc-exploration.yCqwxd/`, including `build.log`, `overlay-5-0.yaml`,
`tenant-with-5-0.yaml`, cutoff-test outputs, production task source, and the cluster-version reproduction.
The probe container was stopped. The untagged local probe image ID is:

```text
sha256:8c52f5dc70967d09cb178b4ac9a154010f7406267199c183abd71237f914ee9d
```

Representative build reproduction, from a throwaway context containing the Dockerfile and a candidate catalog:

```bash
podman build -f catalog.Dockerfile \
  --build-arg INPUT_DIR=catalog-5-0 \
  --build-arg OPM_IMAGE=registry.redhat.io/openshift5/ose-operator-registry-rhel9:v5.0 \
  --iidfile image-id .
podman run --rm --network=none "$(cat image-id)" validate /configs
```

No full Konflux build, actual OCP 5.0 install, stage publication, or production release was initiated.
Those remain rollout acceptance work, rather than results of this investigation.

[volsync-pipeline]: https://github.com/stolostron/volsync-operator-product-fbc/blob/main/.tekton/volsync-fbc-5-0-push.yaml
[volsync-pr]: https://github.com/stolostron/volsync-operator-product-fbc/pull/142
[pick-version]: https://github.com/konflux-ci/tekton-integration-catalog/blob/main/stepactions/bundles/pick-cluster-version/0.1/pick-cluster-version.yaml
