# Update FBC Catalog with Stage Bundle

**When:** After stage release completes (Step 10)

## Process

Update catalog in FBC repo with bundle from completed stage release.

**Repo:** `~/konflux/submariner-operator-fbc`

**Workflow:** Follow `CLAUDE.md` in FBC repo → `.agents/workflows/update-catalog.md`

## Done When

For each OCP version (4-16 through 4-21):

```bash
# 1. Check latest snapshot created after catalog update
oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "^submariner-fbc-4-XX" | tail -1

# 2. Verify both tests pass
SNAPSHOT="submariner-fbc-4-XX-xxxxx"
oc get snapshot $SNAPSHOT -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq -r '.[] | "\(.scenario): \(.status)"'
# Both must show: TestPassed
```

Record snapshot names for all OCP versions - needed for Step 12.
