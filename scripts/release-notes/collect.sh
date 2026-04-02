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
      if [ -z "$VERSION" ]; then
        VERSION="$1"
      else
        echo "Multiple positional arguments not supported" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "Usage: $0 VERSION [--stage-yaml PATH]" >&2
  exit 1
fi

# Expand X.Y to X.Y.0
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

# Source shared library
# shellcheck source=../lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

# Output file
OUTPUT_JSON="/tmp/release-notes-data.json"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Collect Release Notes Data: $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# Prerequisites
# ============================================================================

echo "Testing acli authentication..."
if ! acli jira workitem search --jql 'project=ACM' --limit 1 --json </dev/null >/dev/null 2>&1; then
  echo "❌ ERROR: acli authentication failed" >&2
  echo "" >&2
  echo "Setup steps:" >&2
  echo "  1. acli jira auth login --web" >&2
  echo "  2. acli jira auth status" >&2
  exit 1
fi
echo "✓ Authenticated to redhat.atlassian.net"

# Check jq
if ! command -v jq &>/dev/null; then
  echo "❌ ERROR: jq not installed" >&2
  exit 1
fi

echo "✓ Prerequisites verified"
echo ""

# ============================================================================
# Calculate Versions
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Calculating ACM Version"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

calculate_acm_version

echo "Version mapping: Submariner $VERSION_MAJOR_MINOR → $ACM_VERSION"
echo ""

# ============================================================================
# Find Stage YAML
# ============================================================================

find_stage_yaml "$VERSION" "$STAGE_YAML_ARG"
echo "Found stage YAML: $STAGE_YAML"
echo ""

# ============================================================================
# Find Existing fixVersions
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Finding Existing fixVersions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Querying Jira for existing fixVersion values..."

# Get issue keys first (filter by affectedVersion for performance)
ISSUE_KEYS=$(query_jira --jql "project=ACM AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND affectedVersion = \"$ACM_VERSION\"" | jq -r '.[].key')

if [ -z "$ISSUE_KEYS" ]; then
  echo "⚠️  No issues found with affectedVersion - using empty fixVersions"
  FIXVERSIONS_JSON="[]"
else
  # Extract ACM major.minor for filtering (e.g., "ACM 2.16.0" → "ACM 2.16")
  ACM_VERSION_MAJOR_MINOR=$(echo "$ACM_VERSION" | grep -oE 'ACM [0-9]+\.[0-9]+')

  # Fetch fixVersions for each issue and build unique sorted list (batch with jq -s)
  FIXVERSIONS_JSON=$(echo "$ISSUE_KEYS" | while read -r KEY; do
    view_jira "$KEY" --fields "fixVersions" 2>/dev/null || echo "{}"
  done | jq -s "[.[] | .fields.fixVersions[]?.name | select(startswith(\"Submariner $VERSION_MAJOR_MINOR\") or startswith(\"$ACM_VERSION_MAJOR_MINOR\"))] | unique | sort" 2>/dev/null)

  if [ -z "$FIXVERSIONS_JSON" ] || [ "$FIXVERSIONS_JSON" = "[]" ]; then
    echo "⚠️  No fixVersions found - will use affectedVersion only in queries"
    FIXVERSIONS_JSON="[]"
  else
    echo "Found fixVersions: $(echo "$FIXVERSIONS_JSON" | jq -c .)"
  fi
fi
echo ""

# ============================================================================
# Scan Existing Issues
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking for Existing Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
RELEASE_DIR="$GIT_ROOT/releases/$VERSION_MAJOR_MINOR"

echo "Scanning $RELEASE_DIR/*/*.yaml for already-documented issues..."

EXISTING_ISSUES_JSON="[]"
if [ -d "$RELEASE_DIR" ]; then
  EXISTING_ISSUES=$(grep -h "id: ACM-" "$RELEASE_DIR"/*/*.yaml 2>/dev/null | sed 's/.*id: //' | sed 's/[[:space:]]*$//' | sort -u || echo "")
  if [ -n "$EXISTING_ISSUES" ]; then
    EXISTING_ISSUES_JSON=$(echo "$EXISTING_ISSUES" | jq -R . | jq -s .)
    echo "Found $(echo "$EXISTING_ISSUES_JSON" | jq 'length') existing issues"
  else
    echo "No existing issues found (clean slate for $VERSION_MAJOR_MINOR)"
  fi
else
  echo "No existing issues found (clean slate for $VERSION_MAJOR_MINOR)"
fi
echo ""

# ============================================================================
# Determine Release Timeframe
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Determining Release Timeframe"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract patch number
PATCH_VERSION=$(echo "$VERSION" | cut -d. -f3)

if [ "$PATCH_VERSION" = "0" ]; then
  echo "Y-stream release ($VERSION) - no timeframe filtering needed"
  TIMEFRAME_START=""
  TIMEFRAME_TYPE="y-stream"
else
  echo "Z-stream release ($VERSION) - will filter non-CVE issues by timeframe"
  echo ""
  echo "Fetching previous release date from catalog.redhat.com..."

  # TODO: Implement catalog lookup
  echo "⚠️  Catalog lookup not yet implemented - using approximate date"

  # Approximate: 2 months before current date
  TIMEFRAME_START=$(date -d "2 months ago" +%Y-%m-%d)
  TIMEFRAME_TYPE="z-stream"

  echo "Using timeframe start: $TIMEFRAME_START"
fi
echo ""

# ============================================================================
# Query CVE Issues
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Querying Jira for CVE Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build fixVersion clause (only if we have fixVersions)
if [ "$(echo "$FIXVERSIONS_JSON" | jq 'length')" -gt 0 ]; then
  FIXVERSION_IN=$(echo "$FIXVERSIONS_JSON" | jq -r 'map("\"" + . + "\"") | join(", ")')
  VERSION_CLAUSE="(affectedVersion = \"$ACM_VERSION\" OR fixVersion in ($FIXVERSION_IN))"
else
  VERSION_CLAUSE="affectedVersion = \"$ACM_VERSION\""
fi

echo "Fetching Security-labeled issues..."

CVE_JQL="project=ACM AND labels in (Security) AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND $VERSION_CLAUSE"

CVE_KEYS=$(query_jira --jql "$CVE_JQL" | jq -r '.[].key')

if [ -z "$CVE_KEYS" ]; then
  echo "No CVE issues found."
  CVE_ISSUES_JSON="[]"
else
  echo "Found $(echo "$CVE_KEYS" | wc -l) CVE issues, fetching details and mapping components..."

  # Fetch labels for each CVE issue
  CVE_ISSUES_JSON="[]"
  for KEY in $CVE_KEYS; do
    # Skip empty/null keys
    if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
      continue
    fi

    # Fetch labels with error handling
    if ! LABELS_JSON=$(view_jira "$KEY" --fields "labels" 2>&1 | jq -r '.fields.labels' 2>/dev/null); then
      echo "⚠️  $KEY: Failed to fetch labels, skipping" >&2
      continue
    fi

    # Extract CVE key (first CVE-* label)
    CVE_KEY=$(echo "$LABELS_JSON" | jq -r '.[] | select(startswith("CVE-"))' | head -1)

    # Extract pscomponent (pscomponent:* label without prefix)
    PSCOMPONENT=$(echo "$LABELS_JSON" | jq -r '.[] | select(startswith("pscomponent:")) | sub("pscomponent:"; "")')

    if [ -z "$CVE_KEY" ] || [ -z "$PSCOMPONENT" ]; then
      echo "⚠️  $KEY: Missing CVE or pscomponent label, skipping"
      continue
    fi

    # Map component in bash (cannot call bash function from jq)
    COMPONENT_MAPPED=$(map_component_name "$PSCOMPONENT" "$VERSION_MAJOR_MINOR_DASH")

    # Skip EXCLUDE and UNKNOWN
    if [ "$COMPONENT_MAPPED" = "EXCLUDE" ] || [ "$COMPONENT_MAPPED" = "UNKNOWN" ]; then
      continue
    fi

    # Build JSON object
    ISSUE_OBJ=$(jq -n \
      --arg issue_key "$KEY" \
      --arg cve_key "$CVE_KEY" \
      --arg pscomponent "$PSCOMPONENT" \
      --arg component_mapped "$COMPONENT_MAPPED" \
      --argjson labels "$LABELS_JSON" \
      '{
        issue_key: $issue_key,
        cve_key: $cve_key,
        pscomponent: $pscomponent,
        component_mapped: $component_mapped,
        labels: $labels
      }')

    CVE_ISSUES_JSON=$(echo "$CVE_ISSUES_JSON" | jq --argjson obj "$ISSUE_OBJ" '. + [$obj]')
  done

  echo "Mapped $(echo "$CVE_ISSUES_JSON" | jq 'length') CVE issues to components"
fi
echo ""

# ============================================================================
# Query Non-CVE Issues
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Querying Jira for Non-CVE Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$TIMEFRAME_START" ]; then
  echo "Fetching non-Security issues (timeframe: since $TIMEFRAME_START)..."
else
  echo "Fetching non-Security issues (no timeframe filtering)..."
fi

NON_CVE_JQL="project=ACM AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND $VERSION_CLAUSE AND (labels is EMPTY OR labels not in (Security, SecurityTracking))"

NON_CVE_KEYS=$(query_jira --jql "$NON_CVE_JQL" | jq -r '.[].key')

if [ -z "$NON_CVE_KEYS" ]; then
  echo "No non-CVE issues found."
  NON_CVE_ISSUES_JSON="[]"
else
  echo "Found $(echo "$NON_CVE_KEYS" | wc -l) non-CVE issues, fetching details..."

  # Fetch details for each issue
  NON_CVE_ISSUES_JSON="[]"
  for KEY in $NON_CVE_KEYS; do
    # Skip empty/null keys
    if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
      continue
    fi

    # Fetch issue details with error handling
    if ! ISSUE_JSON=$(view_jira "$KEY" --fields "priority,status,created,updated,summary,fixVersions,resolution" 2>&1); then
      echo "⚠️  $KEY: Failed to fetch details, skipping" >&2
      continue
    fi

    # Extract fields
    PRIORITY=$(echo "$ISSUE_JSON" | jq -r '.fields.priority.name // "Unknown"')
    PRIORITY_ID=$(echo "$ISSUE_JSON" | jq -r '.fields.priority.id // "99999"')  # Default ID for unprioritized issues
    STATUS=$(echo "$ISSUE_JSON" | jq -r '.fields.status.name // "Unknown"')
    CREATED=$(echo "$ISSUE_JSON" | jq -r '.fields.created[:10]')
    UPDATED=$(echo "$ISSUE_JSON" | jq -r '.fields.updated[:10]')
    SUMMARY=$(echo "$ISSUE_JSON" | jq -r '.fields.summary // ""')
    FIXVERSIONS=$(echo "$ISSUE_JSON" | jq -r '[.fields.fixVersions[]?.name] | join(", ")')
    RESOLUTION=$(echo "$ISSUE_JSON" | jq -r '.fields.resolution.name // "Unresolved"')

    # Build JSON object
    ISSUE_OBJ=$(jq -n \
      --arg issue_key "$KEY" \
      --arg priority "$PRIORITY" \
      --arg priority_id "$PRIORITY_ID" \
      --arg status "$STATUS" \
      --arg created "$CREATED" \
      --arg updated "$UPDATED" \
      --arg summary "$SUMMARY" \
      --arg fixversions "$FIXVERSIONS" \
      --arg resolution "$RESOLUTION" \
      '{
        issue_key: $issue_key,
        priority: $priority,
        priority_id: $priority_id,
        status: $status,
        created: $created,
        updated: $updated,
        summary: $summary,
        fixversions: $fixversions,
        resolution: $resolution
      }')

    NON_CVE_ISSUES_JSON=$(echo "$NON_CVE_ISSUES_JSON" | jq --argjson obj "$ISSUE_OBJ" '. + [$obj]')
  done

  echo "Collected $(echo "$NON_CVE_ISSUES_JSON" | jq 'length') non-CVE issue details"
fi
echo ""

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
  --arg timeframe_start "$TIMEFRAME_START" \
  --arg timeframe_type "$TIMEFRAME_TYPE" \
  --arg collected_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson existing_issues "$EXISTING_ISSUES_JSON" \
  --argjson fixversions "$FIXVERSIONS_JSON" \
  --argjson cve_issues "$CVE_ISSUES_JSON" \
  --argjson non_cve_issues "$NON_CVE_ISSUES_JSON" \
  '{
    metadata: {
      version: $version,
      version_major_minor: $version_major_minor,
      version_major_minor_dash: $version_major_minor_dash,
      acm_version: $acm_version,
      stage_yaml: $stage_yaml,
      timeframe_start: $timeframe_start,
      timeframe_type: $timeframe_type,
      collected_at: $collected_at
    },
    existing_issues: $existing_issues,
    fixversions: $fixversions,
    cve_issues: $cve_issues,
    non_cve_issues: $non_cve_issues
  }' > "$OUTPUT_JSON"

echo "✓ Data collected: $OUTPUT_JSON"
echo ""
echo "Summary:"
echo "  CVE issues: $(echo "$CVE_ISSUES_JSON" | jq 'length')"
echo "  Non-CVE issues: $(echo "$NON_CVE_ISSUES_JSON" | jq 'length')"
echo "  Existing issues: $(echo "$EXISTING_ISSUES_JSON" | jq 'length')"
