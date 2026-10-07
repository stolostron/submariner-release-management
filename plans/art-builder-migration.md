<!-- markdownlint-disable MD013 -->

# ART builder migration: source inventory and implementation handoff

Checked October 7, 2026. ACM-45318 remains New and requests migration by October 15.
This plan turns the [current work map](current-work.md)'s deadline into a source-backed change inventory.
No Dockerfile, dependency, pipeline, branch or external issue was changed by this audit.

## Current source and coverage

The three ticket-listed independent-product repositories have downstream builders in `release-0.22`, `release-0.23` and `release-0.24`.
Their devel Dockerfiles use the shared Shipyard Dapper builder and Fedora/scratch output; these are separate upstream build paths.
The ticket targets Brew/OSBS consumers of ART Go builders. The sampled downstream component Dockerfiles use UBI Go Toolset, not the named ART builder; no replacement is justified by the deadline alone. Inspect shared/transitive build inputs before identifying an affected component path.
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

All six 0.24 ticket-listed component Dockerfiles were read: both lighthouse components, all three submariner components and the operator use UBI9 Go Toolset.
Older-stream rows sampled one component per repository; inspect sibling and pipeline inputs before classifying any path as affected. No component-builder migration is proposed from these UBI samples alone.
The operator also builds a tools module for controller-gen: inspect its own Go/toolchain directive and build path as well as the root module.

The CLI is outside the four repositories named by the ticket but inside the independently released product. Its `subctl` rows above identify the same builder family;
confirm whether the ticket's accepted scope includes that image before silently declaring all product builders migrated.
Nettest is different: `package/Dockerfile.nettest.konflux` on all three inspected Shipyard streams has one pinned UBI9 runtime stage and copies scripts;
it has no Go builder stage. The root Shipyard Go floor alone is not evidence that this container needs a new compiler stage.
The operator bundle uses `FROM scratch`; assess its build tasks separately rather than adding a Go builder to the bundle Dockerfile.

## Addon branch differences

Addon belongs to the ACM artifact path and has its own release branches. Source reads distinguish its ordinary and Konflux Dockerfiles:

| Branch | Root Go floor | Ordinary Dockerfile | Konflux Dockerfile | Pinned source |
| --- | --- | --- | --- | --- |
| release-2.14 | 1.25.8 | CI `stolostron/builder:go1.24-linux` | Brew `openshift-golang-builder:v1.25` | [546eaf0c](https://github.com/stolostron/submariner-addon/tree/546eaf0cb95c1433e27d00fa8d4b1bb84e00610f) |
| release-2.16 | 1.25.8 | Brew `v1.25` | Brew `v1.25` | [19532bd7](https://github.com/stolostron/submariner-addon/tree/19532bd70d7014013ca9490bc1d52ca4b51a41c6) |
| release-2.17 | 1.25.13 | Brew `v1.25` | Brew `v1.25` | [19baa867](https://github.com/stolostron/submariner-addon/tree/19baa867769757ca1700bb90b290eca3d8153ffe) |
| release-5.0 | 1.26.0 | Brew `v1.26` | Brew `v1.26`; PQC-minimal runtime base | [cd2fbb77](https://github.com/stolostron/submariner-addon/tree/cd2fbb7714ca8be7052dc239569449e33d7a1598) |
| release-5.1 / main | 1.26.0 | Brew `v1.26` | Brew `v1.26`; ordinary UBI-minimal runtime base | [1805dcb1](https://github.com/stolostron/submariner-addon/tree/1805dcb1166ad331097f0379c1a1d3b27f0ae12e) |

At the inspected heads, the 2.14 ordinary builder's tag advertises an older Go minor than the root directive. Actual toolchain auto-download or compiler behavior
was not measured; do not infer either a working build or a universal failure solely from the tag. Verify the actual compiler and required patch level.
Older branches and `release-5.2` exist but were not inspected here; this inventory does not choose the supported stream set.
Addon task-ref PR #2792 targets the separate `appstudio-submariner-addon-acm-214` branch and does not implement this migration.

The PQC runtime base on release-5.0 is existing configuration evidence relevant to ACM-41119, not proof of the released image's crypto policy.
Main/5.1 differs; avoid carrying a generic "PQC is absent everywhere" or "all streams are covered" claim forward.

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
6. Review the future Y-stream propagation path: `konflux-component-setup.sh` copies the preceding stream's Dockerfile and adjusts version/branch labels.
   Updating only today's release branch can leave another predecessor or the next setup inheriting the old builder. Cover the accepted predecessor set without broadening product support.
7. After authorized merge, verify built-image provenance and record exact evidence in ACM-45318. Builder migration does not establish ART ownership transfer, PQC runtime state,
   OLMv1 support or OCP 5 operator compatibility; those keep their existing acceptance criteria.

## Validation boundary and immediate next action

This audit read GitHub source at pinned heads, not private registry manifests or running build containers. No target ART image or build was qualified.
The concrete next handoff is supported-addon-branch/tag confirmation followed by isolated changes to verified Brew consumers and applicable compiler/crypto/architecture verification. Retain a no-change disposition for unaffected paths.
Konflux authentication succeeds in the third October 7 pass. No migration build was submitted or qualified; approved image/scope selection and change review remain the next handoff.
