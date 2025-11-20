# Check Component Release Build

**Used by:** After Step 10 (stage), After Step 16 (prod)

## Process

Monitor release pipeline execution and verify successful completion.

**TODO:** Document detailed monitoring and troubleshooting workflow.

## Monitor Pipeline

```bash
# Watch release status
make watch NAME=submariner-0-X-Y-{stage,prod}-YYYYMMDD-01

# Check pipeline status in UI
# TODO: Add URL pattern or command to get pipeline URL
```

## Verify Completion

```bash
# Check release completed
oc get release submariner-0-X-Y-{stage,prod}-YYYYMMDD-01 -n submariner-tenant -o jsonpath='{.status.conditions[?(@.type=="Released")].status}'
# Should show: True

# TODO: Add commands to verify:
# - All tasks completed successfully
# - Bundle pushed to registry
# - Component images published
```

## If Build Fails

If the release pipeline fails and fixes are needed, rename the Release CR with incremented sequence number:

```bash
# Rename file
mv releases/0.X/{stage,prod}/submariner-0-X-Y-{stage,prod}-YYYYMMDD-01.yaml \
   releases/0.X/{stage,prod}/submariner-0-X-Y-{stage,prod}-YYYYMMDD-02.yaml

# Update metadata.name to match, fix issues, re-apply
```

## Done When

- Release pipeline completed successfully
- Bundle available in registry (stage or prod)
- All tasks passed
- Ready for next step
