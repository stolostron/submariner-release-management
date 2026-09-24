# Complete OCP 5 FBC onboarding

Updated 2026-09-24. The four-batch implementation plan is preserved in Git history
(`296fca8`). The reusable skill, generation/validation fixes, target-image/live
verification and installed-skill reuse tests are implemented. Real tenant,
admission and push/PR pipeline drafts are committed. The remaining work is the
actual catalog policy and rollout; no new framework or skill rewrite is needed.
See [status and validation](ocp-5-implementation-status.md) for commits and evidence.

## 1. Resolve the real catalog policy

Obtain the approved **minimum Submariner stream and initial bundle**. The pending
question has not been answered. `0.24` is E2E fixture data, not an approved choice;
the inspected 0.24.1 bundle declares OCP `v4.15-v4.19`. Confirm compatibility and
that the approved bundle is in the catalog template. Use the existing bundle-update
workflow only if that bundle must be added or rebuilt. A released approved bundle
can onboard a catalog without waiting for a fresh component snapshot.

## 2. Refresh and finish the prepared changes

When GitLab DNS works, fetch release-data main and review/rebase the separate
`ocp-5-work/tenant` and `ocp-5-work/admission` drafts. They currently derive from
`8c18efee295889f5d86b03d16930a2f11977fd58`. The real FBC worktree is
`ocp-5-work/fbc`, based on tested tooling `f641fb9`, with pipeline commit `0641db0`.
Keep the independent immutable source refs consistent with the reviewed rebases.

Once `MIN_SUPPORTED_SUB` is set to the approved value, resume the same skill and
workspace. For the current cached draft inputs:

```bash
: "${MIN_SUPPORTED_SUB:?Set the approved inclusive Submariner minimum}"
./skills/add-fbc-ocp-version/scripts/run.sh 5.0 \
  --min-supported-sub "$MIN_SUPPORTED_SUB" \
  --release-data-repo /home/dfarrell07/konflux/konflux-release-data \
  --release-data-ref 8c18efee295889f5d86b03d16930a2f11977fd58 \
  --fbc-repo /home/dfarrell07/konflux/ocp-5-skill-work/fbc-tooling \
  --fbc-ref f641fb9 \
  --workspace /home/dfarrell07/konflux/ocp-5-work \
  --kustomize /home/dfarrell07/konflux/ocp-5-work/bin/kustomize \
  --phase prepare
./skills/add-fbc-ocp-version/scripts/run.sh 5.0 \
  --workspace /home/dfarrell07/konflux/ocp-5-work --phase test-image
```

Update the refs after a reviewed refresh; cached inputs must not be described as
fresh. Preparation adds the real drop-through map entry and populated catalog,
validates the existing pipeline pair and configuration, and preserves unrelated
work. Run relevant repository checks, review the diffs and commit. User authorization
to commit persists. Tenant and admission changes remain separate.

## 3. Reconcile and prove the merged build

Review/publish the concrete changes under the session's authorization. Configuration
must reconcile before expecting PAC builds or matched admissions. Inspect actual bot
PR contents if one appears; the validated manual pair is already prepared otherwise.
Check required contexts and app identities at the exact current PR head using both
effective rulesets and legacy protection. A 404 from legacy protection is insufficient.

After merge, run `--phase verify-live --expected-commit <merged-40-character-sha>`.
Require the real RPAs/account bindings, original push build, completed snapshot
checks, correct source/image linkage, all four architectures and each platform's
catalog matching the merged source. Local preparation and a native image pass do
not imply that this gate has passed.

## 4. Prove installation, then release

Confirm access to the 0.3 install path's configured OpenShift CI profile. Inspect
actual task execution, selected bundle/channel and the cluster's observed 5.0.x
version. A skipped install or fallback 4.x cluster is not OCP 5 evidence. If the
approved released bundle is skipped by the generic unreleased-bundle ITS, run the
existing explicit-bundle QE procedure; do not alter the catalog merely to force it.

Use the existing scoped stage/prod workflow with the exact verified snapshot.
Promotion must reuse the stage snapshot QE approved. Verify public-index membership,
then activate `5-0` in the default release scope. Until these gates pass, report
**locally prepared**, **merged build verified**, **installed**, and **released** as
separate states; do not mark OCP 5.0 onboarded early.
