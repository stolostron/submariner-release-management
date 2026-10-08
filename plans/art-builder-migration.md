<!-- markdownlint-disable MD013 -->

# ART builder migration: source inventory and implementation handoff

Rechecked October 8, 2026: 46 branch/ref reads across eight repositories and 45 immutable source trees, plus pinned OpenShift CI configuration and the ACM remote-build task source. ACM-45318 remains New with no comments and requests migration by October 15.
This plan turns the [current work map](current-work.md)'s deadline into a source-backed change inventory.
No implementation or external issue was changed by this audit.

## Current source and coverage

The three ticket-listed independent-product repositories have downstream builders in `release-0.22`, `release-0.23` and `release-0.24`.
Their devel Dockerfiles use the shared Shipyard Dapper builder and Fedora/scratch output; these are separate upstream build paths.
The ticket targets Brew/OSBS consumers of ART Go builders. Its parent lists `registry.redhat.io/openshift/golang-builder:golang-builder-vX.YY-rhelZ` replacements, including Go 1.25/1.26 on RHEL9, and requires internal registry entitlement. Local manifest/config reads now confirm the documented RHEL9 Go 1.23–1.26 tags and four platforms. Supported build-source selection, CI access and build qualification remain pending.
The downstream component Dockerfiles use UBI Go Toolset, not the named ART builder; no replacement is justified by the deadline alone. Inspect shared/transitive build inputs before identifying an affected component path.
The rows below read an immutable branch head's Go directive and sample Konflux Dockerfile; that directive is a module floor, not the observed build compiler.

| Repository | Stream | Root Go floor | Sample builder | Exact source |
| --- | --- | --- | --- | --- |
| lighthouse | 0.22 | `1.25.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/lighthouse/blob/2cd528f6a2289f3179f6fcf223602486d45ff8f6/package/Dockerfile.lighthouse-agent.konflux) |
| lighthouse | 0.23 | `1.25.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/lighthouse/blob/3a3dc0eb7beb25aa25034f81f784198fff1e669e/package/Dockerfile.lighthouse-agent.konflux) |
| lighthouse | 0.24 | `1.25.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/lighthouse/blob/228b141caf956fbfcacdc5dc986edc5070f0f9ed/package/Dockerfile.lighthouse-agent.konflux) |
| submariner | 0.22 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner/blob/ed38953ef65f2103d86f922a4f94bb83d9c6667b/package/Dockerfile.submariner-gateway.konflux) |
| submariner | 0.23 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner/blob/6b37e846544e3def0b180afefc680854e05401c9/package/Dockerfile.submariner-gateway.konflux) |
| submariner | 0.24 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner/blob/e9b4dec4944cbbf8d630603904fb6e0f82a2b566/package/Dockerfile.submariner-gateway.konflux) |
| submariner-operator | 0.22 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner-operator/blob/41333ee509b4ca75135984e6bc75ea632f2615ff/package/Dockerfile.submariner-operator.konflux) |
| submariner-operator | 0.23 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner-operator/blob/524fe6e71666672533298e53caed03b4076c1b17/package/Dockerfile.submariner-operator.konflux) |
| submariner-operator | 0.24 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/submariner-operator/blob/1e41f5c71977e2b47875d02d47bddafaaf7bc175/package/Dockerfile.submariner-operator.konflux) |
| subctl | 0.22 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/subctl/blob/252b24e8de3b1bd615b102ff9b64a482569e5d18/package/Dockerfile.subctl.konflux) |
| subctl | 0.23 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/subctl/blob/3e2f1fab0347ffcb8f027b8a66934b69ae9a2ab3/package/Dockerfile.subctl.konflux) |
| subctl | 0.24 | `1.26.0` | UBI9 Go Toolset `latest` | [Dockerfile](https://github.com/submariner-io/subctl/blob/8a2d1298c2489dae7832cfc5dac7b2c489b2e9ad/package/Dockerfile.subctl.konflux) |

All 18 ticket-listed component Dockerfiles across 0.22–0.24 and their push/PR pipeline selections were read: both lighthouse components, all three submariner components and the operator use UBI9 Go Toolset. No direct Brew/ART builder reference was found in those source trees or their devel trees; registry contents and transitive task inputs remain unqualified.
Module floors can differ inside a repository: [0.22 CoreDNS](https://github.com/submariner-io/lighthouse/blob/2cd528f6a2289f3179f6fcf223602486d45ff8f6/coredns/go.mod) requires Go 1.26.0 despite the root's 1.25.0. Its pipeline prefetches `./coredns` and builds in that directory. Retain each compiled module's floor, including operator tools/controller-gen, rather than selecting a compiler from the root alone.

The CLI is outside the four repositories named by the ticket but inside the independently released product. Its `subctl` rows above identify the same builder family;
confirm whether the ticket's accepted scope includes that image before silently declaring all product builders migrated.
Nettest is different: `package/Dockerfile.nettest.konflux` on all three inspected Shipyard streams has one pinned UBI9 runtime stage and copies scripts;
it has no Go builder stage. The root Shipyard Go floor alone is not evidence that this container needs a new compiler stage.
The operator bundle uses `FROM scratch`; assess its build tasks separately rather than adding a Go builder to the bundle Dockerfile.

## Addon branch differences

Addon belongs to the ACM artifact path and has its own release branches. Source reads distinguish its ordinary and Konflux Dockerfiles:

| Branch | Root Go floor | Ordinary Dockerfile | Konflux Dockerfile | Pinned source |
| --- | --- | --- | --- | --- |
| release-2.10 | 1.24.0 | CI `stolostron/builder:go1.23-linux` | Brew `rhel_9_1.23` | [e1d3198b](https://github.com/stolostron/submariner-addon/tree/e1d3198b81b8b44d9881898caa2a4200e35229cc) |
| release-2.11 | 1.24.0 | Brew `v1.24.6` | Brew `v1.24.6` | [7299448b](https://github.com/stolostron/submariner-addon/tree/7299448bfed1df125955bef08e8bc21d267ce1f1) |
| release-2.12 | 1.24.0 | Brew `v1.24.6` | Brew `v1.24.6` | [35ede4a6](https://github.com/stolostron/submariner-addon/tree/35ede4a6fb8a346db26c2a47144e798a6f741de2) |
| release-2.13 | 1.25.0 | Brew `v1.25` | Brew `v1.25` | [95ba831f](https://github.com/stolostron/submariner-addon/tree/95ba831f529d8dd824f84e3e95d1d56cd4a08b4a) |
| release-2.14 | 1.25.8 | CI `stolostron/builder:go1.24-linux` | Brew `openshift-golang-builder:v1.25` | [546eaf0c](https://github.com/stolostron/submariner-addon/tree/546eaf0cb95c1433e27d00fa8d4b1bb84e00610f) |
| release-2.15 | 1.25.8 | Brew `v1.25` | Brew `v1.25` | [77383385](https://github.com/stolostron/submariner-addon/tree/77383385f14254be6db8264b38393fdc0400e6fe) |
| release-2.16 | 1.25.8 | Brew `v1.25` | Brew `v1.25` | [19532bd7](https://github.com/stolostron/submariner-addon/tree/19532bd70d7014013ca9490bc1d52ca4b51a41c6) |
| release-2.17 | 1.25.13 | Brew `v1.25` | Brew `v1.25` | [19baa867](https://github.com/stolostron/submariner-addon/tree/19baa867769757ca1700bb90b290eca3d8153ffe) |
| release-4.23 | 1.25.8 | Brew `v1.25` | Brew `v1.25` | [f9e62785](https://github.com/stolostron/submariner-addon/tree/f9e627854f63038ff99fa39d417eeda4b08379b9) |
| release-5.0 | 1.26.0 | Brew `v1.26` | Brew `v1.26`; PQC-minimal runtime base | [cd2fbb77](https://github.com/stolostron/submariner-addon/tree/cd2fbb7714ca8be7052dc239569449e33d7a1598) |
| release-5.1 / release-5.2 | 1.26.0 | Brew `v1.26` | Brew `v1.26`; ordinary UBI-minimal runtime base | [1805dcb1](https://github.com/stolostron/submariner-addon/tree/1805dcb1166ad331097f0379c1a1d3b27f0ae12e) |
| main | 1.26.0 | Brew `v1.26` | Brew `v1.26`; ordinary UBI-minimal runtime base | [1105c8c1](https://github.com/stolostron/submariner-addon/tree/1105c8c1f97704f7b1c3f74057992515c9f3fffd) |

At the inspected heads, both 2.10 builder tags and the 2.14 ordinary builder tag advertise an older Go minor than the root directive. Actual toolchain auto-download or compiler behavior
was not measured; do not infer either a working build or a universal failure solely from the tag. Verify the actual compiler and required patch level.
The extended audit also reads every published addon `release-X.Y` and appstudio branch. Releases 2.2–2.9 have no Konflux Dockerfile: 2.2 uses `docker.io/openshift/origin-release`, and 2.3–2.9 use CI `stolostron/builder` images. Release-2.9 advertises Go 1.22 against its 1.24.0 root floor. Branch existence does not choose the supported stream set; preserve or retire these paths according to actual support/build use rather than migrating every archived branch.
The separate [appstudio 2.14 source](https://github.com/stolostron/submariner-addon/tree/8270d50dd684a3936b9693a52220130e75d1d902) has a 1.23.0 root floor and Brew `rhel_9_1.23` Konflux builder. Task-ref PR #2792 targets that branch, not release-2.14, and does not implement the builder migration. Include that build source in the owner’s scope decision.

Inspected addon pipelines select `Dockerfile.konflux`; push definitions request four architectures while PR definitions request only x86_64, except the appstudio 2.14 pair, which requests only x86_64 for both. Release-2.10 has no returned `.tekton` pipeline files. A successful PR build alone does not qualify all push platforms.

PaC filters match `release-2.11`–`release-2.17` and `release-5.0` on those branches. The 5.1/5.2 branch copies filter for `main`; the 4.23 copies also filter for `main`. The separate appstudio 2.14 branch’s pair filters for `release-2.14`, although #2792 targets the appstudio branch. Cached release-data at `8c18efee` selects `Dockerfile.konflux`, release-2.11–2.17 and release-5.0 for those components, and **main for both ACM 5.1 and 5.2**. Their filters therefore agree with the cached component source and are not established defects. Resolve the deployed component revision and PaC source before changing filters or editing an appstudio/branch copy; the cached configuration is not a current deployment read.

Three additional appstudio branches retain Brew Konflux references, while their ordinary Dockerfiles use CI builders:

| Appstudio source | Root floor | Brew builder tag | Pinned source |
| --- | --- | --- | --- |
| ACM 2.11 | 1.22.0 | `rhel_9_1.22` | [fb3c0f6e](https://github.com/stolostron/submariner-addon/tree/fb3c0f6e5f04f1fccd40627953d3d3c959e81102) |
| ACM 2.12 | 1.22.0 | `rhel_9_1.21` | [c8b99692](https://github.com/stolostron/submariner-addon/tree/c8b996925e4c3965b509ca6135a44a73ca5c89a3) |
| ACM 2.13 | 1.22.0 | `rhel_9_1.22` | [d95c0520](https://github.com/stolostron/submariner-addon/tree/d95c0520d17c6666fa67c2d7f444639f59241585) |

Their PaC filters target the corresponding release branches, which the cached components also select. Do not treat these appstudio copies as active consumers without deployment evidence. The 2.12 builder/root mismatch is another source-level discrepancy to resolve if that source is still used. The later main commit changes only deployment resource limits; its Dockerfiles, root/tools modules and Makefile match the preceding inventory.

Release-2.15 and 2.16 explicitly set `CGO_ENABLED=1 GOEXPERIMENT=strictfipsruntime` in `Dockerfile.konflux`. Preserve and exercise that contract when replacing their compiler; the other addon paths do not establish the same explicit settings. Keep this separate from release-5.0’s PQC runtime base.

The PQC runtime base on release-5.0 is existing configuration evidence relevant to ACM-41119, not proof of the released image's crypto policy.
Main/5.1 differs; avoid carrying a generic "PQC is absent everywhere" or "all streams are covered" claim forward.

## ART replacement metadata checked October 8

Local registry reads succeeded for these parent-documented floating RHEL9 tags. Each index and all four architecture-specific configs were read by digest; each has Linux amd64, arm64, ppc64le and s390x. Tekton calls amd64 `x86_64`. Config `GO_VERSION` and the image version label agree across those four architectures:

| Tag in `registry.redhat.io/openshift/golang-builder` | Declared Go version | Source floor to assess |
| --- | --- | --- |
| `golang-builder-v1.23-rhel9` | `1.23.10` | Separate appstudio 2.14 source (`1.23.0`); not sufficient for release-2.10’s `1.24.0` floor |
| `golang-builder-v1.24-rhel9` | `1.24.13` | 2.10–2.12 roots (`1.24.0`) |
| `golang-builder-v1.25-rhel9` | `1.25.14` | 2.13–2.17 and 4.23 roots (up to `1.25.13`) |
| `golang-builder-v1.26-rhel9` | `1.26.7` | 5.0–5.2/main roots and tools (`1.26.0`) |

These are metadata observations and candidate families, not measured compiler execution or approved stream/tag selections. Preserve all compiled-module floors and existing toolchain requirements. Local index/config access does not establish CI entitlement, layer pulls, builds or crypto behavior; verify those in the actual build context. Tags float by policy, so retain resolved image digests and compiler evidence for each qualification run. Runtime-base selection remains independent.

## Other build inputs and full migration scope

The [OpenShift CI configuration](https://github.com/openshift/release/tree/8dc32b0f7b22122ad82bed2511fdec40419429a7/ci-operator/config/stolostron/submariner-addon) selects the ordinary `Dockerfile` for ten addon branch configurations. Its build root is separate: CI `stolostron/builder` Go 1.25 for 2.11–2.13 and Go 1.26 for 2.14–2.17, 5.0/5.1 and main. Both Dockerfiles therefore need a disposition on each accepted stream; replacing only `Dockerfile.konflux` leaves the ordinary Brew path where present. The addon Makefile also defaults image builds to `./Dockerfile`.

That shared CI builder is [UBI-based](https://github.com/stolostron/image-builder/blob/363bb4685ebf964821f67d8405481dd498eb1bdc/Dockerfile.go1.26-linux), with [Go downloaded directly](https://github.com/stolostron/image-builder/blob/363bb4685ebf964821f67d8405481dd498eb1bdc/build/setup-go.sh); no named Brew builder consumer is found in its source. Its Go 1.26 Dockerfile specifies **1.26.8**, whereas the earlier ART metadata read reports **1.26.7**. Neither source nor metadata proves a running compiler; reconcile required patch/security levels before approving a replacement, even when both exceed the module floor. The Shipyard Dapper base uses Fedora and installs its Go package through dnf; its inspected source and vendored build inputs add no direct Brew consumer.

Addon release pipelines resolve [ACM common.yaml](https://github.com/stolostron/konflux-build-catalog/blob/d6b74add90f5717bd2858cb8b7d1cd6aec32c09e/pipelines/common.yaml) through mutable `main`. It carries hermetic mode, root-module prefetch and platform parameters into digest-pinned build tasks. The remote build task’s OCI manifest identifies [this immutable task source](https://github.com/konflux-ci/container-build-catalog/blob/cab160f4afed001a6ad32f4b0e1ee3067d1b8547/task/buildah-remote-oci-ta/buildah-remote-oci-ta.yaml). Record the catalog revision actually resolved in each qualification run and verify registry access in its remote build context. Local registry login, registry pull entitlement and RPM subscription certificates are separate evidence; do not add RPM entitlement configuration merely to pull the ART image.

| Area | Work needed before closure |
| --- | --- |
| Build sources and Dockerfiles | Confirm supported/deployed revisions; replace both verified Brew consumers where used. Give appstudio copies and archived branches an explicit disposition. Preserve matching PaC filters. |
| CI registry access | Verify the actual build service account and remote workers can pull each required platform. Change credentials or policy only when an actual missing requirement is identified. |
| Compiler and crypto | Preserve module/toolchain and required patch levels, CGO and the 2.15/2.16 strict-FIPS settings. Measure the compiler used; successful registry reads do not exercise these settings. |
| Hermetic builds and release platforms | Retain root prefetch and offline build behavior; check toolchain switching as well as dependencies. No addon RPM lockfiles were found, so regenerate only inputs actually affected. Qualify every required platform and the resulting image/provenance. |
| Future branches and completion | Carry both Dockerfile changes through the addon’s accepted stream/branch process. The eight-component setup wrapper does not include addon. Close only with reviewed changes and qualified consumer builds, plus explicit dispositions for unaffected paths. |

[Go toolchain selection](https://go.dev/doc/toolchain) can switch to a different compiler from the image’s bundled version. Verify `GOTOOLCHAIN` and the compiler used in the actual hermetic build; an automatic download must not substitute an unqualified compiler or hide a source-floor mismatch.

## Prepare a reviewable change

1. Confirm the current supported streams, ticket scope and approved ART registry/tag family with the existing issue owner. Retain the module Go floors and higher toolchain requirements;
   do not choose one Go minor for all repositories merely because they share Submariner versions. Verify exact target-image availability, patch compiler, architectures and registry access.
2. Start with an isolated addon change for the verified Brew references. Inspect pipeline `DOCKERFILE`/build-argument selection so each edit reaches the affected build. Propose an independent-product change only if a named ART/Brew consumer is found in its Dockerfiles, shared builder or pipeline inputs; otherwise record no change required.
   Refresh branch heads first; keep upstream Dapper and downstream Konflux paths separately reviewable. Preserve source pins, runtime-base policy and image labels unless a reviewed requirement changes them.
3. Preserve each affected build's existing compiler, crypto, CGO and platform contract. Exercise `GOEXPERIMENT=strictfipsruntime` and related build tags where already configured or separately required. Check the target Go/crypto implementation against that applicable contract; preserve the addon's independent runtime-base policy.
4. Trace RPM lockfiles and hermetic prefetch inputs against the new builder. Regenerate only affected data through the existing deterministic tools and inspect the result;
   record which dependencies/locks are unchanged instead of assuming a registry swap has no build implications.
5. Run meaningful native builds/tests and the actual required multiarchitecture Konflux checks at each proposed head. Record the compiler used for root/tools modules,
   platform images and the applicable crypto behavior. Keep source verification, local compilation and hosted build evidence distinct.
6. Review the addon’s supported-stream propagation for both Dockerfiles; `tekton-component-setup.sh` covers eight independent-product components and does not include addon.
   If a separate component consumer is identified, its `konflux-component-setup.sh` copies the preceding stream’s Dockerfile. Cover the affected predecessor path without broadening product support.
7. After authorized merge, verify built-image provenance and record exact evidence in ACM-45318. Builder migration does not establish ART ownership transfer, PQC runtime state,
   OLMv1 support or OCP 5 operator compatibility; those keep their existing acceptance criteria.

## Validation boundary and immediate next action

This audit reads all published addon release/appstudio branches, independent-product/shared sources, pinned CI configuration and the remote task source, alongside the earlier four ART indexes and sixteen platform configs. No builder container or migration build was run; execution and CI qualification remain unestablished.
The concrete next handoff is supported-addon-build-source and CI-access confirmation, then isolated changes to verified Brew consumers with applicable compiler/crypto/architecture qualification. Retain a no-change disposition for unaffected paths.
Local ART metadata access succeeds on October 8; CI registry access remains unverified. A fresh read-only Konflux authentication check returns Unauthorized, so cached tenant configuration does not establish the current deployed build source. No migration build was submitted or qualified; supported source/tag selection, CI access and change review remain the next handoff.
