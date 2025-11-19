# Apply Component Release

**Used by:** Step 10 (stage), Step 16 (prod)

## Process

Apply component YAML to cluster.

**Repo:** `~/konflux/submariner-release-management`

## Apply Release

Agent provides user with commands:

```bash
# For stage (Step 10):
make test-remote FILE=releases/0.X/stage/submariner-0-X-Y-stage-YYYYMMDD-01.yaml
make apply FILE=releases/0.X/stage/submariner-0-X-Y-stage-YYYYMMDD-01.yaml
make watch NAME=submariner-0-X-Y-stage-YYYYMMDD-01

# For prod (Step 16):
make test-remote FILE=releases/0.X/prod/submariner-0-X-Y-prod-YYYYMMDD-01.yaml
make apply FILE=releases/0.X/prod/submariner-0-X-Y-prod-YYYYMMDD-01.yaml
make watch NAME=submariner-0-X-Y-prod-YYYYMMDD-01
```

Replace `0.X.Y` with version and `YYYYMMDD` with date from create step.

## Done When

Release running on cluster and completes successfully.

```bash
# Verify release exists and completed
oc get release submariner-0-X-Y-{stage,prod}-YYYYMMDD-01 -n submariner-tenant
```

**Stage:** Bundle now available in stage registry for Step 11 (catalog update).

**Prod:** Bundle now available in prod registry.
