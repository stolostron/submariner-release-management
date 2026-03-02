#!/bin/bash
# Verify FBC release readiness (combined snapshot + component SHA verification)
#
# Usage: verify-fbc-release.sh <version>
#
# Arguments:
#   version: Submariner version (e.g., 0.22.1 or 0.22)
#
# Output: JSON with combined verification results (stdout)
# Exit codes:
#   0: Success (all verifications passed)
#   1: Failure (any verification failed)
#
# Optimizations:
#   - Batched OC queries: 1 API call instead of 30
#   - Single-pass extraction: Extract each snapshot once (not twice)
#   - Parallel extraction: 6 simultaneous extracts (added in Phase 2)

set -euo pipefail

# ============================================================================
# Argument Parsing and Setup
# ============================================================================

# Validate arguments
if [ $# -ne 1 ]; then
  echo "❌ ERROR: Invalid number of arguments" >&2
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 0.22.1" >&2
  exit 1
fi

VERSION_INPUT="$1"

# Extract major.minor (0.22.1 → 0.22)
if [[ "$VERSION_INPUT" =~ ^[0-9]+\.[0-9]+ ]]; then
  :  # Version format is valid
else
  echo "❌ ERROR: Invalid version format: $VERSION_INPUT" >&2
  echo "Expected: 0.Y or 0.Y.Z (e.g., 0.22 or 0.22.1)" >&2
  exit 1
fi

# Extract version components
MAJOR_MINOR=$(echo "$VERSION_INPUT" | grep -oP '^\d+\.\d+')
FULL_VERSION="$VERSION_INPUT"
MAJOR=$(echo "$MAJOR_MINOR" | cut -d. -f1)
MINOR=$(echo "$MAJOR_MINOR" | cut -d. -f2)
HYPHENATED="${MAJOR}-${MINOR}"  # 0-22

# Single tmpdir with trap cleanup
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== FBC Release Verification ===" >&2
echo "Version: $FULL_VERSION (branch: release-$MAJOR_MINOR, components: *-$HYPHENATED)" >&2
echo "" >&2

# ============================================================================
# Parallel Job Execution Helpers
# ============================================================================

# Run a job in background with error tracking
run_parallel_job() {
    local job_name="$1"
    local job_func="$2"
    shift 2
    (
        set -euo pipefail
        EXIT_CODE=0
        "${job_func}" "$@" 2>"$TMPDIR/${job_name}.stderr" || EXIT_CODE=$?
        echo "$EXIT_CODE" > "$TMPDIR/${job_name}.exit"
    ) &
    echo "$!" >> "$TMPDIR/pids.txt"
}

# Wait for all parallel jobs and check for errors
wait_parallel_jobs() {
    local job_description="$1"

    # Wait for all background jobs
    while read -r pid; do
        wait "$pid" || true  # Don't exit on individual job failure
    done < "$TMPDIR/pids.txt"

    # Check for errors after all jobs complete
    local failed_count=0
    local error_msg=""
    local exit_code
    local job_name
    local stderr
    for exit_file in "$TMPDIR"/*.exit; do
        [ -f "$exit_file" ] || continue
        exit_code=$(cat "$exit_file")
        if [ "$exit_code" -ne 0 ]; then
            ((failed_count++))
            job_name=$(basename "$exit_file" .exit)
            stderr=$(cat "${exit_file%.exit}.stderr" 2>/dev/null || echo "")
            error_msg="${error_msg}  ${job_name}: ${stderr}\n"
        fi
    done

    if [ $failed_count -gt 0 ]; then
        echo "" >&2
        echo "❌ ERROR: $failed_count $job_description job(s) failed:" >&2
        echo -e "$error_msg" >&2
        return 1
    fi

    # Clean up for next parallel batch
    rm -f "$TMPDIR/pids.txt" "$TMPDIR"/*.exit "$TMPDIR"/*.stderr 2>/dev/null || true
}

# ============================================================================
# Step 1: Verify GitHub Catalog Consistency
# ============================================================================

echo "Step 1: Verifying GitHub catalog consistency..." >&2

declare -A BUNDLE_SHAS
FAILED=0

for VERSION in 16 17 18 19 20 21; do
  CATALOG_URL="https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-4-${VERSION}/bundles/bundle-v${FULL_VERSION}.yaml"

  # Fetch bundle and extract SHA
  BUNDLE_SHA=$(curl -sf "$CATALOG_URL" | grep "^image:" | head -1 | grep -oP 'sha256:\K[a-f0-9]+' || true)

  if [ -z "$BUNDLE_SHA" ]; then
    echo "  4-${VERSION}: ✗ Failed to fetch bundle or extract SHA" >&2
    echo "    URL: $CATALOG_URL" >&2
    ((FAILED++))
    continue
  fi

  BUNDLE_SHAS["4-${VERSION}"]="$BUNDLE_SHA"
  echo "  4-${VERSION}: ${BUNDLE_SHA:0:12}..." >&2
done

# Check if all SHAs are the same
if [ $FAILED -eq 0 ]; then
  UNIQUE_SHAS=$(printf '%s\n' "${BUNDLE_SHAS[@]}" | sort -u | wc -l)

  if [ "$UNIQUE_SHAS" -ne 1 ]; then
    echo "" >&2
    echo "✗ ERROR: FBC catalog bundle SHA mismatch:" >&2
    for VERSION in 16 17 18 19 20 21; do
      echo "  4-${VERSION}: ${BUNDLE_SHAS[4-${VERSION}]}" >&2
    done
    echo "" >&2
    echo "Remediation:" >&2
    echo "1. Check if Step 11 (FBC catalog update) completed correctly" >&2
    echo "2. Verify all 6 catalogs were updated with same bundle SHA" >&2
    echo "3. Re-run Step 11 if needed" >&2
    exit 1
  fi

  # Get the common SHA
  EXPECTED_BUNDLE_SHA="${BUNDLE_SHAS[4-16]}"
  echo "" >&2
  echo "✓ Bundle SHA consistent across all 6 GitHub catalogs: ${EXPECTED_BUNDLE_SHA:0:12}..." >&2
else
  echo "" >&2
  echo "✗ ERROR: Failed to fetch $FAILED catalog(s)" >&2
  exit 1
fi

# ============================================================================
# Step 2: Batch Fetch All Snapshots (OPTIMIZATION: 1 query vs 30)
# ============================================================================

echo "" >&2
echo "Step 2: Fetching FBC snapshots (batched query)..." >&2

# ONE query for all snapshots (vs 6 list + 24 individual gets)
ALL_SNAPSHOTS=$(oc get snapshots -n submariner-tenant -o json 2>/dev/null)

# Save for debugging
echo "$ALL_SNAPSHOTS" > "$TMPDIR/snapshots.json"

# Extract data for each OCP version using jq (local filtering, no API calls)
declare -A SNAPSHOTS
declare -A CATALOG_IMAGES
declare -A EVENT_TYPES
declare -A TEST_STATUSES

FAILED=0
FAILED_DETAILS=""

for VERSION in 16 17 18 19 20 21; do
  # Filter for this version, get latest (all in one jq query)
  SNAPSHOT_DATA=""
  SNAPSHOT_DATA=$(echo "$ALL_SNAPSHOTS" | jq -r \
    ".items[] | select(.metadata.name | startswith(\"submariner-fbc-4-${VERSION}\")) |
    select(.metadata.creationTimestamp != null) |
    {name: .metadata.name,
     event: .metadata.annotations[\"pac.test.appstudio.openshift.io/event-type\"],
     tests: .metadata.annotations[\"test.appstudio.openshift.io/status\"],
     image: .spec.components[0].containerImage,
     timestamp: .metadata.creationTimestamp} |
    @json" | jq -s 'sort_by(.timestamp) | last')

  if [ -z "$SNAPSHOT_DATA" ] || [ "$SNAPSHOT_DATA" = "null" ]; then
    echo "  4-${VERSION}: ✗ No snapshot found" >&2
    FAILED_DETAILS="${FAILED_DETAILS}    4-${VERSION}: No snapshot found\n"
    ((FAILED++))
    continue
  fi

  # Parse JSON into associative arrays
  SNAPSHOTS["4-${VERSION}"]=$(echo "$SNAPSHOT_DATA" | jq -r '.name')
  CATALOG_IMAGES["4-${VERSION}"]=$(echo "$SNAPSHOT_DATA" | jq -r '.image')
  EVENT_TYPES["4-${VERSION}"]=$(echo "$SNAPSHOT_DATA" | jq -r '.event // "unknown"')
  TEST_STATUSES["4-${VERSION}"]=$(echo "$SNAPSHOT_DATA" | jq -r '.tests // "{}"')

  echo "  4-${VERSION}: ${SNAPSHOTS[4-${VERSION}]}" >&2
done

if [ $FAILED -gt 0 ]; then
  echo "" >&2
  echo "✗ ERROR: Failed to find $FAILED snapshot(s):" >&2
  echo -e "$FAILED_DETAILS" >&2
  exit 1
fi

echo "" >&2
echo "✓ Found all 6 FBC snapshots" >&2

# ============================================================================
# Step 3: Single-Pass Bundle Extraction (OPTIMIZATION: Parallel + extract once)
# ============================================================================

echo "" >&2
echo "Step 3: Extracting bundles from snapshots (parallel, single-pass)..." >&2

# Extract each snapshot's bundle ONCE (not twice like old scripts)
# Use parallel execution for 6 simultaneous extractions
# Bundle YAMLs stay in tmpdir for both bundle SHA AND component SHA verification

# Define extraction function for parallel execution
extract_single_bundle() {
    local VERSION="$1"
    local SNAPSHOT="$2"
    local CATALOG_IMAGE="$3"
    local FULL_VERSION="$4"

    # Each version gets own directory
    local EXTRACT_DIR="$TMPDIR/extract-4-${VERSION}"
    mkdir -p "$EXTRACT_DIR"

    # Extract bundle YAML (suppress output)
    oc image extract "$CATALOG_IMAGE" \
        --path "/configs/submariner/bundles/bundle-v${FULL_VERSION}.yaml:$EXTRACT_DIR/" \
        --confirm > /dev/null 2>&1

    # Verify file exists and extract SHA
    local BUNDLE_YAML="$EXTRACT_DIR/bundle-v${FULL_VERSION}.yaml"
    if [ ! -f "$BUNDLE_YAML" ]; then
        echo "Failed to extract bundle from $SNAPSHOT" >&2
        return 1
    fi

    local SNAPSHOT_BUNDLE_SHA
    SNAPSHOT_BUNDLE_SHA=$(grep "^image:" "$BUNDLE_YAML" | head -1 | grep -oP 'sha256:\K[a-f0-9]+' || true)
    if [ -z "$SNAPSHOT_BUNDLE_SHA" ]; then
        echo "Failed to extract SHA from bundle" >&2
        return 1
    fi

    # Save SHA for later use
    echo "$SNAPSHOT_BUNDLE_SHA" > "$EXTRACT_DIR/bundle-sha.txt"

    echo "  4-${VERSION}: ✓ ${SNAPSHOT_BUNDLE_SHA:0:12}..." >&2
}

# Export function and variables for subshells
export -f extract_single_bundle
export TMPDIR FULL_VERSION

# Launch parallel extraction jobs
for VERSION in 16 17 18 19 20 21; do
    run_parallel_job "extract-4-${VERSION}" extract_single_bundle \
        "$VERSION" "${SNAPSHOTS[4-${VERSION}]}" "${CATALOG_IMAGES[4-${VERSION}]}" "$FULL_VERSION"
done

# Wait for all extractions to complete and check for errors
if ! wait_parallel_jobs "bundle extraction"; then
    echo "" >&2
    echo "✗ ERROR: Bundle extraction failed" >&2
    exit 1
fi

echo "" >&2
echo "✓ Extracted all 6 bundles (parallel, single-pass)" >&2

# ============================================================================
# Step 4: Verify Snapshot Readiness
# ============================================================================

echo "" >&2
echo "Step 4: Verifying snapshot readiness..." >&2

declare -A VERIFIED_SNAPSHOTS
FAILED=0
FAILED_DETAILS=""

for VERSION in 16 17 18 19 20 21; do
  SNAPSHOT="${SNAPSHOTS[4-${VERSION}]}"
  EVENT_TYPE="${EVENT_TYPES[4-${VERSION}]}"
  TESTS_JSON="${TEST_STATUSES[4-${VERSION}]}"
  SNAPSHOT_BUNDLE_SHA=$(cat "$TMPDIR/extract-4-${VERSION}/bundle-sha.txt")

  # Verify event type
  if [ "$EVENT_TYPE" != "push" ]; then
    echo "  4-${VERSION}: ✗ Event type '$EVENT_TYPE' (must be 'push')" >&2
    FAILED_DETAILS="${FAILED_DETAILS}    4-${VERSION}: Event type '$EVENT_TYPE' (must be 'push', not PR)\n"
    ((FAILED++))
    continue
  fi

  # Verify tests passed
  if [ -z "$TESTS_JSON" ] || [ "$TESTS_JSON" = "{}" ]; then
    echo "  4-${VERSION}: ✗ No test status" >&2
    FAILED_DETAILS="${FAILED_DETAILS}    4-${VERSION}: No test status\n"
    ((FAILED++))
    continue
  fi

  # Check for any non-passing tests
  FAILED_TESTS=$(echo "$TESTS_JSON" | jq -r '.[] | select(.status != "TestPassed") | .scenario' 2>/dev/null || true)
  if [ -n "$FAILED_TESTS" ]; then
    echo "  4-${VERSION}: ✗ Tests failed: $FAILED_TESTS" >&2
    FAILED_DETAILS="${FAILED_DETAILS}    4-${VERSION}: Tests failed: $FAILED_TESTS\n"
    ((FAILED++))
    continue
  fi

  # Verify bundle SHA matches GitHub
  if [ "$SNAPSHOT_BUNDLE_SHA" != "$EXPECTED_BUNDLE_SHA" ]; then
    echo "  4-${VERSION}: ✗ Bundle SHA mismatch (snapshot: ${SNAPSHOT_BUNDLE_SHA:0:12}, expected: ${EXPECTED_BUNDLE_SHA:0:12})" >&2
    FAILED_DETAILS="${FAILED_DETAILS}    4-${VERSION}: Bundle SHA mismatch\n"
    ((FAILED++))
    continue
  fi

  # All checks passed
  echo "  4-${VERSION}: ✓ $SNAPSHOT (push, tests passed, bundle SHA verified)" >&2
  VERIFIED_SNAPSHOTS["4-${VERSION}"]="$SNAPSHOT"
done

if [ $FAILED -gt 0 ]; then
  echo "" >&2
  echo "✗ ERROR: Snapshot verification failed for $FAILED version(s):" >&2
  echo -e "$FAILED_DETAILS" >&2
  echo "Remediation:" >&2
  echo "1. Wait for FBC rebuild after Step 11 merge (~15-30 min)" >&2
  echo "2. Check: oc get snapshots -n submariner-tenant | grep fbc" >&2
  echo "3. Verify event type and test status" >&2
  exit 1
fi

echo "" >&2
echo "✓ All 6 FBC snapshots ready for release" >&2

# ============================================================================
# Step 5: Extract Bundle Metadata (Source Commit)
# ============================================================================

echo "" >&2
echo "Step 5: Extracting bundle source commit..." >&2

# Get bundle image URL from FBC catalog (using 4-21 as representative - all verified identical)
BUNDLE_IMAGE=$(curl -sf "https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-4-21/bundles/bundle-v${FULL_VERSION}.yaml" | grep "^image:" | head -1 | awk '{print $2}' || true)

if [ -z "$BUNDLE_IMAGE" ]; then
  echo "❌ ERROR: Failed to fetch bundle image URL from FBC catalog" >&2
  echo "URL: https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-4-21/bundles/bundle-v${FULL_VERSION}.yaml" >&2
  exit 1
fi

# Verify bundle SHA matches expected
BUNDLE_IMAGE_SHA=$(echo "$BUNDLE_IMAGE" | grep -oP 'sha256:\K[a-f0-9]+' || true)
if [ "$BUNDLE_IMAGE_SHA" != "$EXPECTED_BUNDLE_SHA" ]; then
  echo "❌ ERROR: Bundle SHA mismatch" >&2
  echo "  Expected (from snapshots): ${EXPECTED_BUNDLE_SHA:0:12}" >&2
  echo "  Found (in FBC catalog):    ${BUNDLE_IMAGE_SHA:0:12}" >&2
  exit 1
fi

echo "  ✓ Bundle image: $BUNDLE_IMAGE" >&2

# Extract source commit from OCI labels (try registry.redhat.io first, fallback to quay.io)
SOURCE_COMMIT=$(skopeo inspect "docker://${BUNDLE_IMAGE}" 2>/dev/null | jq -r '.Labels."org.opencontainers.image.revision"' || true)

if [ -z "$SOURCE_COMMIT" ] || [ "$SOURCE_COMMIT" = "null" ]; then
  # Fallback: try quay.io workspace URL from template
  echo "  ⚠ Bundle not found at ${BUNDLE_IMAGE%%@*}, trying quay.io workspace..." >&2
  BUNDLE_IMAGE_QUAY=$(curl -sf "https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-template.yaml" | grep -A1 "name: submariner.v${FULL_VERSION}" | grep "image:" | awk '{print $2}' || true)

  if [ -n "$BUNDLE_IMAGE_QUAY" ]; then
    SOURCE_COMMIT=$(skopeo inspect "docker://${BUNDLE_IMAGE_QUAY}" 2>/dev/null | jq -r '.Labels."org.opencontainers.image.revision"' || true)
    if [ -n "$SOURCE_COMMIT" ] && [ "$SOURCE_COMMIT" != "null" ]; then
      echo "  ✓ Using quay.io bundle: $BUNDLE_IMAGE_QUAY" >&2
      BUNDLE_IMAGE="$BUNDLE_IMAGE_QUAY"
    fi
  fi
fi

if [ -z "$SOURCE_COMMIT" ] || [ "$SOURCE_COMMIT" = "null" ]; then
  echo "❌ ERROR: Failed to extract source commit from bundle image" >&2
  echo "Image (registry.redhat.io): $BUNDLE_IMAGE" >&2
  echo "Image (quay.io fallback): ${BUNDLE_IMAGE_QUAY:-NOT FOUND}" >&2
  exit 1
fi

echo "  ✓ Source commit: $SOURCE_COMMIT" >&2

# ============================================================================
# Step 6: Fetch Operator CSV from Source Commit
# ============================================================================

echo "" >&2
echo "Step 6: Fetching operator CSV from commit ${SOURCE_COMMIT:0:7}..." >&2

# Fetch CSV from specific commit (not branch HEAD)
OP_CSV=$(curl -sf "https://raw.githubusercontent.com/submariner-io/submariner-operator/${SOURCE_COMMIT}/bundle/manifests/submariner.clusterserviceversion.yaml")
if [ -z "$OP_CSV" ]; then
  echo "❌ ERROR: Failed to fetch operator CSV from source commit" >&2
  echo "URL: https://raw.githubusercontent.com/submariner-io/submariner-operator/${SOURCE_COMMIT}/bundle/manifests/submariner.clusterserviceversion.yaml" >&2
  exit 1
fi

echo "  ✓ Fetched operator CSV from commit ${SOURCE_COMMIT:0:7}" >&2

# Fetch FBC bundle for comparison (using 4-21 as representative - all 6 catalogs verified identical)
FBC_BUNDLE=$(curl -sf "https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-4-21/bundles/bundle-v${FULL_VERSION}.yaml")
if [ -z "$FBC_BUNDLE" ]; then
  echo "❌ ERROR: Failed to fetch FBC bundle from GitHub" >&2
  echo "URL: https://raw.githubusercontent.com/stolostron/submariner-operator-fbc/main/catalog-4-21/bundles/bundle-v${FULL_VERSION}.yaml" >&2
  exit 1
fi

echo "  ✓ Fetched FBC GitHub bundle" >&2

# ============================================================================
# Step 7: Verify Component SHAs Across All Sources
# ============================================================================

echo "" >&2
echo "Step 7: Verifying component SHAs across all sources..." >&2

# Component list with CSV name mappings
declare -A CSV_NAMES
CSV_NAMES["submariner-operator"]="submariner-operator"
CSV_NAMES["submariner-gateway"]="submariner-gateway"
CSV_NAMES["submariner-globalnet"]="submariner-globalnet"
CSV_NAMES["submariner-route-agent"]="submariner-routeagent"  # Note: routeagent (no dash)
CSV_NAMES["lighthouse-agent"]="submariner-lighthouse-agent"
CSV_NAMES["lighthouse-coredns"]="submariner-lighthouse-coredns"
CSV_NAMES["nettest"]="submariner-nettest"

MISMATCH=0
declare -A COMPONENT_RESULTS

for COMP in submariner-operator submariner-gateway submariner-globalnet submariner-route-agent lighthouse-agent lighthouse-coredns nettest; do
  CSV="${CSV_NAMES[$COMP]}"

  # Extract SHA from operator repo and FBC catalog (GitHub)
  # Special case for nettest: it has no name field, match by image URL pattern
  if [ "$COMP" = "nettest" ]; then
    OP_SHA=$(echo "$OP_CSV" | awk '/relatedImages:/,/selector:/' | grep "nettest-rhel9" | grep -oP 'sha256:\K[a-f0-9]+' | head -1 || true)
    FBC_SHA=$(echo "$FBC_BUNDLE" | awk '/relatedImages:/,/schema:/' | grep "nettest-rhel9" | grep -oP 'sha256:\K[a-f0-9]+' | head -1 || true)
  else
    OP_SHA=$(echo "$OP_CSV" | awk '/relatedImages:/,/selector:/' | grep -B1 "name: $CSV" | grep -oP 'sha256:\K[a-f0-9]+' || true)
    FBC_SHA=$(echo "$FBC_BUNDLE" | awk '/relatedImages:/,/schema:/' | grep -B1 "name: $CSV" | grep -oP 'sha256:\K[a-f0-9]+' || true)
  fi

  # Check if extraction succeeded
  if [ -z "$OP_SHA" ] || [ -z "$FBC_SHA" ]; then
    echo "  $COMP: ✗ SHA extraction failed" >&2
    echo "    Operator CSV (commit ${SOURCE_COMMIT:0:7}): ${OP_SHA:-NOT FOUND}" >&2
    echo "    FBC bundle (v${FULL_VERSION}): ${FBC_SHA:-NOT FOUND}" >&2
    COMPONENT_RESULTS[$COMP]="fail"
    ((MISMATCH++))
    continue
  fi

  # Verify all 6 FBC snapshots have same SHA as operator repo (using extracted bundles)
  SNAP_MISMATCH=0
  for VERSION in 16 17 18 19 20 21; do
    SNAPSHOT="${SNAPSHOTS[4-${VERSION}]}"
    BUNDLE_YAML="$TMPDIR/extract-4-${VERSION}/bundle-v${FULL_VERSION}.yaml"

    # Special case for nettest: match by image URL pattern
    if [ "$COMP" = "nettest" ]; then
      SNAP_SHA=$(awk '/relatedImages:/,/schema:/' "$BUNDLE_YAML" | grep "nettest-rhel9" | grep -oP 'sha256:\K[a-f0-9]+' | head -1 || true)
    else
      SNAP_SHA=$(awk '/relatedImages:/,/schema:/' "$BUNDLE_YAML" | grep -B1 "name: $CSV" | grep -oP 'sha256:\K[a-f0-9]+' || true)
    fi

    if [ -z "$SNAP_SHA" ]; then
      echo "  $COMP: ✗ Failed to extract SHA from snapshot $SNAPSHOT" >&2
      ((SNAP_MISMATCH++))
    elif [ "$SNAP_SHA" != "$OP_SHA" ]; then
      echo "  $COMP: ✗ Snapshot $SNAPSHOT SHA mismatch (${SNAP_SHA:0:12} vs ${OP_SHA:0:12})" >&2
      ((SNAP_MISMATCH++))
    fi
  done

  if [ $SNAP_MISMATCH -gt 0 ]; then
    COMPONENT_RESULTS[$COMP]="fail"
    ((MISMATCH++))
    continue
  fi

  # Verify operator repo and FBC GitHub match
  if [ "$OP_SHA" != "$FBC_SHA" ]; then
    echo "  $COMP: ✗ SHA mismatch" >&2
    echo "    Operator repo:  ${OP_SHA:0:12}" >&2
    echo "    FBC GitHub:     ${FBC_SHA:0:12}" >&2
    COMPONENT_RESULTS[$COMP]="fail"
    ((MISMATCH++))
    continue
  fi

  echo "  $COMP: ✓ ${OP_SHA:0:12}... (verified across all sources)" >&2
  COMPONENT_RESULTS[$COMP]="pass:${OP_SHA}"
done

# Summary
if [ $MISMATCH -gt 0 ]; then
  echo "" >&2
  echo "✗ $MISMATCH component(s) failed verification" >&2
  echo "" >&2
  echo "Remediation:" >&2
  echo "1. Verify Step 7 (update bundle SHAs) completed at commit $SOURCE_COMMIT" >&2
  echo "2. Check bundle CSV: https://github.com/submariner-io/submariner-operator/blob/${SOURCE_COMMIT}/bundle/manifests/submariner.clusterserviceversion.yaml" >&2
  echo "3. If SHAs don't match, re-run Step 7 (bundle SHA update)" >&2
  echo "4. If SHAs don't match FBC catalog, re-run Step 11 (FBC catalog update)" >&2
  exit 1
fi

echo "" >&2
echo "✓ All 7 components verified (operator commit ${SOURCE_COMMIT:0:7}, FBC GitHub, 6 FBC snapshots)" >&2

# ============================================================================
# Step 8: Output Combined JSON
# ============================================================================

# Extract component data (format: "pass:SHA")
OP_STATUS=$(echo "${COMPONENT_RESULTS[submariner-operator]}" | cut -d: -f1)
OP_SHA=$(echo "${COMPONENT_RESULTS[submariner-operator]}" | cut -d: -f2)
GW_STATUS=$(echo "${COMPONENT_RESULTS[submariner-gateway]}" | cut -d: -f1)
GW_SHA=$(echo "${COMPONENT_RESULTS[submariner-gateway]}" | cut -d: -f2)
GL_STATUS=$(echo "${COMPONENT_RESULTS[submariner-globalnet]}" | cut -d: -f1)
GL_SHA=$(echo "${COMPONENT_RESULTS[submariner-globalnet]}" | cut -d: -f2)
RA_STATUS=$(echo "${COMPONENT_RESULTS[submariner-route-agent]}" | cut -d: -f1)
RA_SHA=$(echo "${COMPONENT_RESULTS[submariner-route-agent]}" | cut -d: -f2)
LA_STATUS=$(echo "${COMPONENT_RESULTS[lighthouse-agent]}" | cut -d: -f1)
LA_SHA=$(echo "${COMPONENT_RESULTS[lighthouse-agent]}" | cut -d: -f2)
LC_STATUS=$(echo "${COMPONENT_RESULTS[lighthouse-coredns]}" | cut -d: -f1)
LC_SHA=$(echo "${COMPONENT_RESULTS[lighthouse-coredns]}" | cut -d: -f2)
NT_STATUS=$(echo "${COMPONENT_RESULTS[nettest]}" | cut -d: -f1)
NT_SHA=$(echo "${COMPONENT_RESULTS[nettest]}" | cut -d: -f2)

# Output JSON to stdout (single line for easy parsing)
printf '{"status":"pass","bundle_sha":"%s","source_commit":"%s","snapshots":{"4-16":"%s","4-17":"%s","4-18":"%s","4-19":"%s","4-20":"%s","4-21":"%s"},"components":{"submariner-operator":{"status":"%s","sha":"%s"},"submariner-gateway":{"status":"%s","sha":"%s"},"submariner-globalnet":{"status":"%s","sha":"%s"},"submariner-route-agent":{"status":"%s","sha":"%s"},"lighthouse-agent":{"status":"%s","sha":"%s"},"lighthouse-coredns":{"status":"%s","sha":"%s"},"nettest":{"status":"%s","sha":"%s"}}}\n' \
  "$EXPECTED_BUNDLE_SHA" \
  "$SOURCE_COMMIT" \
  "${VERIFIED_SNAPSHOTS[4-16]}" \
  "${VERIFIED_SNAPSHOTS[4-17]}" \
  "${VERIFIED_SNAPSHOTS[4-18]}" \
  "${VERIFIED_SNAPSHOTS[4-19]}" \
  "${VERIFIED_SNAPSHOTS[4-20]}" \
  "${VERIFIED_SNAPSHOTS[4-21]}" \
  "$OP_STATUS" "$OP_SHA" \
  "$GW_STATUS" "$GW_SHA" \
  "$GL_STATUS" "$GL_SHA" \
  "$RA_STATUS" "$RA_SHA" \
  "$LA_STATUS" "$LA_SHA" \
  "$LC_STATUS" "$LC_SHA" \
  "$NT_STATUS" "$NT_SHA"
