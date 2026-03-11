# Fix Tekton Config PRs - Bundle

**When:** Y-stream only (0.20 → 0.21), after Step 3 component builds complete

## Prerequisites

From Step 3: All 8 component builds completed and passing:

```bash
# Verify latest snapshot has all components passing
SNAPSHOT=$(oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "submariner-0-X" | tail -1 | awk '{print $1}')
echo "Latest snapshot: $SNAPSHOT"

# Check all tests passed
oc get snapshot $SNAPSHOT -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq -r '.[] | "\(.scenario): \(.status)"'
# All should show: TestPassed
```

Replace `0-X` with version (e.g., `0-22`).

## Process

Bundle setup has two parts:

### 1. Update Bundle SHAs

Update bundle CSV with component image SHAs from the passing snapshot.

**Repo:** <https://github.com/submariner-io/submariner-operator>
**Local:** `~/go/src/submariner-io/submariner-operator`
**Branch:** `release-0.X`

**Workflow:** `.agents/workflows/bundle-sha-update.md`

### 2. Run Bundle Konflux Setup

After bundle SHAs are updated and pushed, set up bundle Konflux build.

**Repo:** <https://github.com/submariner-io/submariner-operator>
**Local:** `~/go/src/submariner-io/submariner-operator`

**Skill:** `/konflux-bundle-setup [version]`

## Done When

- Bundle `.tekton/` files exist on `release-0.X` branch:

  ```bash
  gh api "repos/submariner-io/submariner-operator/contents/.tekton?ref=release-0.X" --jq '.[] | select(.name | startswith("submariner-bundle")) | .name'
  # Should show: submariner-bundle-0-X-pull-request.yaml, submariner-bundle-0-X-push.yaml
  ```

- Bundle builds passing (~15-30 min after PR merge):

  ```bash
  # Get latest snapshot that includes bundle
  SNAPSHOT=$(oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "submariner-0-X" | tail -1 | awk '{print $1}')

  # Verify bundle component exists in snapshot
  oc get snapshot $SNAPSHOT -n submariner-tenant -o jsonpath='{.spec.components[*].name}' | grep submariner-bundle-0-X

  # Verify bundle EC tests pass (not just build)
  oc get snapshot $SNAPSHOT -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq -r '.[] | select(.scenario | contains("enterprise-contract")) | "\(.scenario): \(.status)"'
  # Should show: TestPassed for enterprise-contract
  ```

**Next:** Proceed to Step 4 for EC violation fixes (if any remain).
