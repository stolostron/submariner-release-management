# Share FBC with QE

Provide FBC catalog/index URLs to QE for testing in stage and production environments.

**Repo:** `~/konflux/submariner-release-management`

## Share Stage FBC with QE

**When:** After FBC stage releases applied and verified (Step 13b complete)

### Extract Stage Catalog URLs

Agent extracts catalog URLs for all OCP versions from stage snapshots:

```bash
echo "=== FBC Stage Catalog URLs for QE ==="
for VERSION in 16 17 18 19 20; do
  STAGE_YAML=$(ls releases/fbc/4-$VERSION/stage/*.yaml | tail -1)
  SNAPSHOT=$(awk '/^  snapshot:/ {print $2}' "$STAGE_YAML")
  CATALOG=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant \
    -o jsonpath='{.spec.components[0].containerImage}')
  echo "OCP 4.$VERSION: $CATALOG"
done
```

Example output (5 catalog URLs):

```text
OCP 4.16: quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-16@sha256:...
OCP 4.17: quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-17@sha256:...
OCP 4.18: quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-18@sha256:...
OCP 4.19: quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-19@sha256:...
OCP 4.20: quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-20@sha256:...
```

### Verify Stage Catalog Content

Verify one catalog contains the expected bundle version:

```bash
# Pick one catalog to verify (e.g., 4-20)
CATALOG="quay.io/redhat-user-workloads/submariner-tenant/submariner-fbc-4-20@sha256:..."

# Extract and list bundles
TMPDIR=$(mktemp -d)
oc image extract "$CATALOG" --path /configs/submariner/bundles/:$TMPDIR/ --confirm
ls $TMPDIR/bundle-v*.yaml
# Should show: bundle-v0.21.0.yaml, bundle-v0.21.2.yaml (or current version)

# Verify bundle accessible
BUNDLE_IMAGE=$(grep "^image:" "$TMPDIR/bundle-v0.21.2.yaml" | head -1 | awk '{print $2}')
skopeo inspect "docker://$BUNDLE_IMAGE"
# Should succeed (bundle mirrored to registry.redhat.io)

rm -rf $TMPDIR
```

### Share Stage with QE

**Communication method:** Jira ticket in ACM QE project

Create ticket with:

- **Summary:** "Submariner 0.X.Y FBC Stage Ready for Testing"
- **Description:** Include all 5 catalog URLs
- **Installation:** Point to FBC installation docs (CatalogSource creation)

**Key concept:** Catalog contains operator bundle with registry.redhat.io URLs. ImageDigestMirrors in
cluster redirect to quay.io for actual image pulls.

### Stage Done When

- QE ticket created with catalog URLs
- QE confirms receipt and begins testing
- Waiting for QE approval to proceed to prod releases

**Next:** Wait for QE approval, then proceed to Step 15 (Component Prod Release) and Step 17 (FBC Prod Releases)

## Share Prod FBC with QE

**When:** After FBC prod releases complete (after Step 18)

### Extract Prod Index URLs

Agent extracts index URLs from completed prod releases:

```bash
echo "=== FBC Prod Index URLs for QE ==="
for VERSION in 16 17 18 19 20; do
  RELEASE=$(oc get releases -n submariner-tenant --no-headers | \
    grep "submariner-fbc-4-$VERSION-prod.*Succeeded" | tail -1 | awk '{print $1}')

  if [ -n "$RELEASE" ]; then
    INDEX=$(oc get release "$RELEASE" -n submariner-tenant -o yaml | \
      grep "index_image_resolved:" | head -1 | awk '{print $2}')
    PUBLIC_INDEX=$(echo "$INDEX" | \
      sed 's|registry-proxy.engineering.redhat.com/rh-osbs/iib-pub|registry.redhat.io/redhat/redhat-operator-index|')
    echo "OCP 4.$VERSION: $PUBLIC_INDEX"
  else
    echo "OCP 4.$VERSION: (release not complete yet)"
  fi
done
```

Example output (5 index URLs with SHA256 digests):

```text
OCP 4.16: registry.redhat.io/redhat/redhat-operator-index@sha256:...
OCP 4.17: registry.redhat.io/redhat/redhat-operator-index@sha256:...
OCP 4.18: registry.redhat.io/redhat/redhat-operator-index@sha256:...
OCP 4.19: registry.redhat.io/redhat/redhat-operator-index@sha256:...
OCP 4.20: registry.redhat.io/redhat/redhat-operator-index@sha256:...
```

**Important:** Must wait for all 5 FBC prod releases to show "Succeeded" status before extracting URLs.

### Share Prod with QE (Optional)

**Note:** QE typically does NOT need direct prod index URLs. OpenShift clusters automatically use the certified
operator catalog which includes these indexes.

If QE requests verification:

**Communication method:** Jira ticket OR Slack notification

Provide either:

1. **Direct index URLs** (from above) for manual CatalogSource creation
2. **OperatorHub instructions:** "Submariner 0.X.Y available in OperatorHub for OCP 4.16-4.20 (allow 1hr for
   propagation after releases complete)"

### Prod Done When

- All 5 FBC prod releases succeeded
- QE notified (if requested)
- Submariner 0.X.Y visible in production OperatorHub (verify on test cluster)

**Complete:** 0.X.Y release fully published to production.
