# Check FBC Release Builds

**Used by:** After Step 13 (stage), After Step 18 (prod)

## Process

Monitor FBC release pipeline executions for all OCP versions (4-16 through 4-21) and verify successful completion.

## Check Build Status

```bash
# Check all FBC stage releases (replace 'stage' with 'prod' for Step 18)
for VERSION in 16 17 18 19 20 21; do
  RELEASE=$(oc get release -n submariner-tenant --no-headers | grep "submariner-fbc-4-$VERSION-stage" | tail -1 | awk '{print $1}')
  [ -z "$RELEASE" ] && { echo "4-$VERSION: Not applied"; continue; }

  STATUS=$(oc get release "$RELEASE" -n submariner-tenant -o jsonpath='{.status.conditions[?(@.type=="Released")].status}')
  REASON=$(oc get release "$RELEASE" -n submariner-tenant -o jsonpath='{.status.conditions[?(@.type=="Released")].reason}')

  echo "4-$VERSION: $STATUS ($REASON)"
done
```

Expected: All show `True (Succeeded)`. If any show `False (Failed)` or `False (Progressing)`:

```bash
# Check failure details (replace 4-XX with failed version, YYYYMMDD with date)
oc get release submariner-fbc-4-XX-stage-YYYYMMDD-01 -n submariner-tenant -o yaml | grep -A 30 "conditions:"
```

Infra failures can be retried. Code/config failures need investigation.

## Debug Failed Releases

When a release shows `False (Failed)`, investigate systematically to determine if it's an infra failure (retry) or code issue (fix required).

### 1. Get Full Conditions

```bash
# Replace with actual failed release name
RELEASE="submariner-fbc-4-XX-stage-YYYYMMDD-01"

# View all conditions
oc get release "$RELEASE" -n submariner-tenant -o jsonpath='{.status.conditions}' | jq '.[] | {type: .type, status: .status, reason: .reason, message: .message}'
```

Key conditions:

- `Released`: Overall status
- `ManagedPipelineProcessed`: Managed pipeline execution (most failures here)
- `TenantPipelineProcessed`: Tenant pipeline execution

### 2. Check Pipeline Task Details

```bash
# ManagedPipelineProcessed shows task counts
oc get release "$RELEASE" -n submariner-tenant -o jsonpath='{.status.conditions[?(@.type=="ManagedPipelineProcessed")]}' | jq '.'
```

Example failure: `"message": "Tasks Completed: 6 (Failed: 1, Cancelled 0), Skipped: 11"`

### 3. Get Konflux UI Log Link

```bash
# Extract log URL from annotations (opens in Konflux UI)
oc get release "$RELEASE" -n submariner-tenant -o jsonpath='{.metadata.annotations.pac\.test\.appstudio\.openshift\.io/log-url}'
```

Opens pipeline run details in Konflux UI at `https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/`.

### 4. Compare Failed vs Successful

```bash
# Compare specs (should be nearly identical except snapshot/releasePlan)
FAILED="submariner-fbc-4-XX-stage-YYYYMMDD-01"
SUCCESS="submariner-fbc-4-YY-stage-YYYYMMDD-01"  # Working version

oc get release "$FAILED" -n submariner-tenant -o jsonpath='{.spec}' | jq '{snapshot: .snapshot, releasePlan: .releasePlan}'
oc get release "$SUCCESS" -n submariner-tenant -o jsonpath='{.spec}' | jq '{snapshot: .snapshot, releasePlan: .releasePlan}'

# Verify snapshot exists
oc get snapshot $(oc get release "$FAILED" -n submariner-tenant -o jsonpath='{.spec.snapshot}') -n submariner-tenant
```

### 5. Determine Retry vs Fix

**Retry (infra failure):**

- Same code succeeded on another OCP version (compare SHA from annotations in Step 4)
- To retry: Increment sequence number in both filename and `metadata.name`

**Investigate/Fix (code/config issue):**

- All OCP versions failing consistently
- Snapshot doesn't exist or has test failures
- Different code than successful releases (different SHA)

## Retry Failed Release

If determined to be infra failure, agent prepares retry, then user applies.

### Agent Prepares Retry

```bash
# Example: Retry 4-19 (increment -01 to -02)
cd releases/fbc/4-19/stage

# Rename file
mv submariner-fbc-4-19-stage-20251120-01.yaml \
   submariner-fbc-4-19-stage-20251120-02.yaml

# Update metadata.name inside YAML
sed -i 's/name: submariner-fbc-4-19-stage-20251120-01/name: submariner-fbc-4-19-stage-20251120-02/' \
   submariner-fbc-4-19-stage-20251120-02.yaml

# Commit retry YAML
git add submariner-fbc-4-19-stage-20251120-02.yaml
git commit -s -m "Retry 4-19 stage release (-02)

Previous -01 failed due to infra issue (not released)"
```

### User Applies Retry

```bash
make apply FILE=releases/fbc/4-19/stage/submariner-fbc-4-19-stage-20251120-02.yaml
```

After apply, agent returns to **Check Build Status** section to verify retry succeeded.

## Done When

- All 6 FBC release pipelines completed successfully (4-16 through 4-21)
- Index images published to target registries
- Catalogs updated in indices
- Ready for next step

**Stage:** Catalogs available for QE testing (Step 14)

**Prod:** Catalogs live in production indices
