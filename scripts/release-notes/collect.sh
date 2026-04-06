#!/bin/bash
# Phase 1: Collect raw release notes data from Jira and filesystem
# Output: /tmp/release-notes-data.json
set -euo pipefail

# ============================================================================
# Argument Parsing
# ============================================================================

VERSION=""
STAGE_YAML_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage-yaml)
      STAGE_YAML_ARG="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
      else
        echo "Multiple positional arguments not supported" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 VERSION [--stage-yaml PATH]" >&2
  exit 1
fi

if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  VERSION="${VERSION}.0"
fi

# Validate version format (X.Y.Z where X,Y,Z are numbers)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ ERROR: Invalid version format: $VERSION" >&2
  echo "Expected format: X.Y.Z (e.g., 0.23.1)" >&2
  exit 1
fi

# ============================================================================
# Initialize
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

OUTPUT_JSON="/tmp/release-notes-data.json"

# JQL text filter for Submariner-related issues
readonly JQL_TEXT_FILTER="(text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest)"

banner "Collect Release Notes Data: $VERSION"

# ============================================================================
# Prerequisites
# ============================================================================

echo "Testing acli authentication..."
if ! acli jira workitem search --jql 'project=ACM' --limit 1 --json </dev/null >/dev/null 2>&1; then
  echo "❌ ERROR: acli authentication failed" >&2
  echo "Setup steps:" >&2
  echo "  1. acli jira auth login --web" >&2
  echo "  2. acli jira auth status" >&2
  exit 1
fi
echo "✓ Authenticated to redhat.atlassian.net"

if ! command -v jq &>/dev/null; then
  echo "❌ ERROR: jq not installed" >&2
  exit 1
fi

echo "✓ Prerequisites verified"

# ============================================================================
# Calculate Versions
# ============================================================================

banner "Calculate Version and Locate Stage YAML"

calculate_acm_version
find_stage_yaml "$VERSION" "$STAGE_YAML_ARG"

echo "Version mapping: Submariner $VERSION_MAJOR_MINOR → $ACM_VERSION"
echo "Stage YAML: $STAGE_YAML"

VERSION_CLAUSE="(affectedVersion = \"$ACM_VERSION\" OR fixVersion = \"$ACM_VERSION\")"
echo "Version clause: $VERSION_CLAUSE"

# ============================================================================
# Scan Existing Issues
# ============================================================================

banner "Checking for Existing Issues"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_ROOT" ]]; then
  echo "❌ ERROR: Not in a git repository" >&2
  echo "Run this script from within the repository" >&2
  exit 1
fi

PROD_DIR="$GIT_ROOT/releases/$VERSION_MAJOR_MINOR/prod"

echo "Scanning $PROD_DIR/*.yaml for published issues..."

# Use yq to properly parse YAML and extract issue IDs from prod releases only
# Rationale: Only prod releases are actually published to registry.redhat.io
# Stage releases are attempts that may never get applied
EXISTING_ISSUES_JSON="[]"
if [[ -d "$PROD_DIR" ]]; then
  # Find all prod YAML files and extract issue IDs with yq
  EXISTING_ISSUES=$(find "$PROD_DIR" -name "*.yaml" -type f -exec sh -c '
    yq eval ".spec.data.releaseNotes.issues.fixed[].id" "$1" 2>/dev/null || true
  ' _ {} \; | sort -u || echo "")
  if [[ -n "$EXISTING_ISSUES" ]]; then
    EXISTING_ISSUES_JSON=$(jq -Rs 'split("\n") | map(select(length > 0))' <<< "$EXISTING_ISSUES")
    echo "Found $(jq 'length' <<< "$EXISTING_ISSUES_JSON") published issues (from prod releases)"
  fi
fi
[[ "$EXISTING_ISSUES_JSON" == "[]" ]] && echo "No published issues found (clean slate for $VERSION_MAJOR_MINOR)"

# ============================================================================
# Get Last Published Release Info (Metadata Only)
# ============================================================================

banner "Checking Last Published Release"

PATCH_VERSION="${VERSION##*.}"

# Check if this is the first release in the series
PROD_RELEASE_COUNT=0
if [[ -d "$PROD_DIR" ]]; then
  PROD_RELEASE_COUNT=$(find "$PROD_DIR" -name "*.yaml" -type f 2>/dev/null | wc -l)
fi

# Determine release type
if [[ "$PROD_RELEASE_COUNT" -eq 0 ]]; then
  # First release for this Y-stream (no prior prod releases)
  echo "First release in $VERSION_MAJOR_MINOR series"
  RELEASE_TYPE="first-in-series"
  LAST_PUBLISHED_DATE=""
elif [[ "$PATCH_VERSION" == "0" ]]; then
  # First patch release (X.Y.0) with existing prod releases
  echo "Y-stream release ($VERSION)"
  RELEASE_TYPE="y-stream"
  LAST_PUBLISHED_DATE=""
else
  # Subsequent patch release (X.Y.Z where Z > 0)
  echo "Z-stream release ($VERSION)"
  RELEASE_TYPE="z-stream"

  # Get last published version's build date from registry.redhat.io
  echo "Finding last published version for $VERSION_MAJOR_MINOR series..."

  LAST_TAG="v${VERSION_MAJOR_MINOR}"
  BUILD_DATE=$(skopeo inspect "docker://registry.redhat.io/rhacm2/submariner-rhel9-operator:${LAST_TAG}" 2>/dev/null | \
    jq -r '.Labels["build-date"] // empty' || true)

  if [[ -n "$BUILD_DATE" ]]; then
    LAST_PUBLISHED_DATE=$(date -d "$BUILD_DATE" +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$LAST_PUBLISHED_DATE" ]]; then
      echo "✓ Found last published version: $LAST_TAG (built $BUILD_DATE)"
      echo "  Last published date: $LAST_PUBLISHED_DATE (for filtering old issues)"
    else
      echo "⚠️  Failed to parse build date '$BUILD_DATE'" >&2
      LAST_PUBLISHED_DATE=""
    fi
  else
    echo "⚠️  Could not find $LAST_TAG in registry" >&2
    LAST_PUBLISHED_DATE=""
  fi
fi

echo "Querying ALL issues for $ACM_VERSION (filtering in next phase)"

# ============================================================================
# Query CVE Issues
# ============================================================================

banner "Querying Jira for CVE Issues"

echo "Fetching Security-labeled issues..."

CVE_JQL="project=ACM AND labels in (Security) AND $JQL_TEXT_FILTER AND $VERSION_CLAUSE"

CVE_JSON=$(query_jira --jql "$CVE_JQL")
read -r CVE_COUNT CVE_KEYS < <(jq -r '[.[].key] | "\(length) \(join(" "))"' <<< "$CVE_JSON")

if [[ "$CVE_COUNT" -eq 0 ]]; then
  echo "No CVE issues found."
  CVE_ISSUES_JSON="[]"
else
  echo "Found $CVE_COUNT CVE issues, fetching details and mapping components..."

  CVE_DATA_LINES=()
  for KEY in $CVE_KEYS; do
    [[ -z "$KEY" || "$KEY" == "null" ]] && continue

    ISSUE_JSON=$(view_jira "$KEY" --fields "labels,resolutiondate") || {
      echo "⚠️  $KEY: Failed to fetch details, skipping" >&2
      continue
    }

    read -r CVE_KEY PSCOMPONENT < <(jq -r '
      ([.fields.labels[] | select(startswith("CVE-"))] | first // "") as $cve |
      ([.fields.labels[] | select(startswith("pscomponent:")) | sub("pscomponent:"; "")] | first // "") as $ps |
      "\($cve) \($ps)"
    ' <<< "$ISSUE_JSON")

    if [[ -z "$CVE_KEY" || -z "$PSCOMPONENT" ]]; then
      echo "⚠️  $KEY: Missing CVE or pscomponent label, skipping" >&2
      continue
    fi

    COMPONENT_MAPPED=$(map_component_name "$PSCOMPONENT" "$VERSION_MAJOR_MINOR_DASH")
    [[ "$COMPONENT_MAPPED" == "EXCLUDE" || "$COMPONENT_MAPPED" == "UNKNOWN" ]] && continue

    RESOLVED=$(jq -r '(.fields.resolutiondate // "")[:10]' <<< "$ISSUE_JSON")
    CVE_DATA_LINES+=("$(jq -n --arg ik "$KEY" --arg ck "$CVE_KEY" --arg ps "$PSCOMPONENT" --arg cm "$COMPONENT_MAPPED" --arg rd "$RESOLVED" '{issue_key:$ik,cve_key:$ck,pscomponent:$ps,component_mapped:$cm,resolved:$rd}')")
  done

  CVE_ISSUES_JSON=$(printf '%s\n' "${CVE_DATA_LINES[@]}" | jq -s '.')
  echo "Mapped ${#CVE_DATA_LINES[@]} CVE issues to components"
fi

# ============================================================================
# Query Non-CVE Issues
# ============================================================================

banner "Querying Jira for Non-CVE Issues"

echo "Fetching ALL non-Security issues for $ACM_VERSION..."
if [[ -n "$LAST_PUBLISHED_DATE" ]]; then
  echo "(Last published: $LAST_PUBLISHED_DATE - for filtering old issues)"
fi

NON_CVE_JQL="project=ACM AND $JQL_TEXT_FILTER AND $VERSION_CLAUSE AND (labels is EMPTY OR labels not in (Security, SecurityTracking))"

NON_CVE_JSON=$(query_jira --jql "$NON_CVE_JQL")
read -r NON_CVE_COUNT NON_CVE_KEYS < <(jq -r '[.[].key] | "\(length) \(join(" "))"' <<< "$NON_CVE_JSON")

if [[ "$NON_CVE_COUNT" -eq 0 ]]; then
  echo "No non-CVE issues found."
  NON_CVE_ISSUES_JSON="[]"
else
  echo "Found $NON_CVE_COUNT non-CVE issues, fetching details..."

  NON_CVE_DATA_LINES=()
  for KEY in $NON_CVE_KEYS; do
    [[ -z "$KEY" || "$KEY" == "null" ]] && continue

    ISSUE_JSON=$(view_jira "$KEY" --fields "priority,status,created,updated,resolutiondate,summary,resolution") || {
      echo "⚠️  $KEY: Failed to fetch details, skipping" >&2
      continue
    }

    NON_CVE_DATA_LINES+=("$(jq -c --arg ik "$KEY" '
      {
        issue_key: $ik,
        priority: (.fields.priority.name // "Unknown"),
        status: (.fields.status.name // "Unknown"),
        created: ((.fields.created // "1970-01-01")[:10]),
        updated: ((.fields.updated // "1970-01-01")[:10]),
        resolved: ((.fields.resolutiondate // "")[:10]),
        summary: (.fields.summary // ""),
        resolution: (.fields.resolution.name // "Unresolved")
      }
    ' <<< "$ISSUE_JSON")")
  done

  NON_CVE_ISSUES_JSON=$(printf '%s\n' "${NON_CVE_DATA_LINES[@]}" | jq -s '.')
  echo "Collected ${#NON_CVE_DATA_LINES[@]} non-CVE issue details"
fi

# ============================================================================
# Build Output JSON
# ============================================================================

echo "Building output JSON..."

jq -n \
  --arg version "$VERSION" \
  --arg version_major_minor "$VERSION_MAJOR_MINOR" \
  --arg version_major_minor_dash "$VERSION_MAJOR_MINOR_DASH" \
  --arg acm_version "$ACM_VERSION" \
  --arg stage_yaml "$STAGE_YAML" \
  --arg last_published_date "$LAST_PUBLISHED_DATE" \
  --arg release_type "$RELEASE_TYPE" \
  --arg collected_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson existing_issues "$EXISTING_ISSUES_JSON" \
  --argjson cve_issues "$CVE_ISSUES_JSON" \
  --argjson non_cve_issues "$NON_CVE_ISSUES_JSON" \
  '{
    metadata: {
      version: $version,
      version_major_minor: $version_major_minor,
      version_major_minor_dash: $version_major_minor_dash,
      acm_version: $acm_version,
      stage_yaml: $stage_yaml,
      last_published_date: $last_published_date,
      release_type: $release_type,
      collected_at: $collected_at
    },
    existing_issues: $existing_issues,
    cve_issues: $cve_issues,
    non_cve_issues: $non_cve_issues
  }' > "$OUTPUT_JSON"

echo "✓ Data collected: $OUTPUT_JSON"

jq -r '"Summary:",
  "  CVE issues: \(.cve_issues | length)",
  "  Non-CVE issues: \(.non_cve_issues | length)",
  "  Existing issues: \(.existing_issues | length)"' "$OUTPUT_JSON"
