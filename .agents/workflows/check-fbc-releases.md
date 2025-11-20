# Check FBC Release Builds

**Used by:** After Step 13 (stage), After Step 18 (prod)

## Process

Monitor FBC release pipeline executions for all OCP versions (4-16 through 4-20) and verify successful completion.

**TODO:** Document detailed monitoring and troubleshooting workflow for FBC releases.

## Monitor Pipelines

```bash
# Watch all FBC releases
for VERSION in 16 17 18 19 20; do
  echo "=== Checking 4-$VERSION ==="
  make watch NAME=submariner-fbc-4-$VERSION-{stage,prod}-YYYYMMDD-01
done

# TODO: Add command to monitor all in parallel or summary view
```

## Verify Completion

```bash
# Check all FBC releases completed
oc get releases -n submariner-tenant | grep "fbc.*{stage,prod}" | sort

# For each release, verify completed status
for VERSION in 16 17 18 19 20; do
  STATUS=$(oc get release submariner-fbc-4-$VERSION-{stage,prod}-YYYYMMDD-01 -n submariner-tenant -o jsonpath='{.status.conditions[?(@.type=="Released")].status}')
  echo "4-$VERSION: $STATUS"
done
# All should show: True

# TODO: Add commands to verify:
# - Index images built successfully
# - IIB operations completed
# - Catalogs published to target indices
```

## If Build Fails

If any FBC release pipeline fails and fixes are needed, rename the Release CR(s) with incremented sequence numbers:

```bash
# Rename file(s)
mv releases/fbc/4-XX/{stage,prod}/submariner-fbc-4-XX-{stage,prod}-YYYYMMDD-01.yaml \
   releases/fbc/4-XX/{stage,prod}/submariner-fbc-4-XX-{stage,prod}-YYYYMMDD-02.yaml

# Update metadata.name to match, fix issues, re-apply
```

## Done When

- All 5 FBC release pipelines completed successfully (4-16 through 4-20)
- Index images published to target registries
- Catalogs updated in indices
- Ready for next step

**Stage:** Catalogs available for QE testing (Step 14)

**Prod:** Catalogs live in production indices
