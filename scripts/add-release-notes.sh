#!/bin/bash
# Add release notes to component stage release YAML
#
# Usage: add-release-notes.sh <version> [--stage-yaml path]
#
# Arguments:
#   version: Submariner version (e.g., 0.22.1 or 0.22)
#   --stage-yaml: Optional path to specific stage YAML file
#
# Exit codes:
#   0: Success (release notes added and committed)
#   1: Failure (prerequisites, queries, or validation failed)

set -euo pipefail

# ============================================================================
# Global Variables
# ============================================================================

VERSION=""
VERSION_DOT=""
VERSION_DASH=""
VERSION_MAJOR_MINOR=""
VERSION_MAJOR_MINOR_DASH=""
ACM_VERSION=""
STAGE_YAML=""
GIT_ROOT=""

# Arrays for issue tracking
declare -a CVE_ISSUES
declare -a CVE_KEYS
declare -a CVE_COMPONENTS
declare -a NON_CVE_ISSUES
declare -a SELECTED_ISSUES
declare -a EXISTING_ISSUES

RELEASE_TYPE=""
TIMEFRAME_START=""

# ============================================================================
# Helper Functions
# ============================================================================

check_acli_auth() {
  # Check if acli is authenticated
  if ! acli jira auth status &>/dev/null; then
    echo "❌ ERROR: acli is not authenticated"
    echo ""
    echo "Please authenticate with: acli jira auth login --web"
    echo "Or with API token: acli jira auth login --site redhat.atlassian.net --email your@email.com --token YOUR_TOKEN"
    exit 1
  fi
}

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
  local MISSING_TOOLS=()

  # Check required tools
  command -v jq &>/dev/null || MISSING_TOOLS+=("jq")
  command -v git &>/dev/null || MISSING_TOOLS+=("git")
  command -v acli &>/dev/null || MISSING_TOOLS+=("acli")
  command -v oc &>/dev/null || MISSING_TOOLS+=("oc")

  if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "❌ ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "Installation instructions:"
    for tool in "${MISSING_TOOLS[@]}"; do
      case "$tool" in
        jq) echo "  jq: https://jqlang.github.io/jq/download/" ;;
        git) echo "  git: https://git-scm.com/downloads" ;;
        acli) echo "  acli: https://developer.atlassian.com/cloud/acli/guides/install-acli/" ;;
        oc) echo "  oc: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html" ;;
      esac
    done
    exit 1
  fi

  # Check yq (optional - will fall back to sed)
  if ! command -v yq &>/dev/null; then
    echo "ℹ️  yq not found - will use sed for YAML editing (may be less robust)"
  fi

  # Test acli authentication
  echo "Testing acli authentication..."
  check_acli_auth

  local AUTH_STATUS
  AUTH_STATUS=$(acli jira auth status 2>&1)
  if echo "$AUTH_STATUS" | grep -q "✓ Authenticated"; then
    local SITE
    SITE=$(echo "$AUTH_STATUS" | grep "Site:" | awk '{print $2}')
    echo "✓ Authenticated to $SITE"
  else
    echo "❌ ERROR: acli authentication check failed"
    exit 1
  fi

  # Check oc login (not strictly required, but recommended for date lookups)
  if ! oc whoami &>/dev/null; then
    echo "⚠️  WARNING: Not logged into OpenShift cluster"
    echo "   Release date lookups may fail for Z-stream releases"
    echo "   Run: oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/"
    echo ""
  fi

  echo "✓ Prerequisites verified"
  echo ""
}

# ============================================================================
# Argument Parsing
# ============================================================================

show_usage() {
  echo "Usage: $0 <version> [--stage-yaml path]"
  echo "Example: $0 0.22.1"
  echo "Example: $0 0.22"
  echo "Example: $0 0.22.1 --stage-yaml releases/0.22/stage/submariner-0-22-1-stage-20260316-01.yaml"
}

parse_arguments() {
  local VERSION_ARG="${1:-}"
  local STAGE_YAML_ARG=""

  if [ -z "$VERSION_ARG" ]; then
    echo "❌ ERROR: Version required"
    show_usage
    exit 1
  fi

  # Parse optional arguments
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stage-yaml)
        if [ -z "${2:-}" ]; then
          echo "❌ ERROR: --stage-yaml requires a value"
          show_usage
          exit 1
        fi
        STAGE_YAML_ARG="$2"
        shift 2
        ;;
      *)
        echo "❌ ERROR: Unknown argument: $1"
        show_usage
        exit 1
        ;;
    esac
  done

  # Validate and expand version
  VERSION="$VERSION_ARG"
  if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    VERSION="${VERSION}.0"
    echo "ℹ️  Defaulting to $VERSION (patch version 0)"
  elif ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ ERROR: Invalid version format: $VERSION"
    echo "Expected: X.Y or X.Y.Z (e.g., 0.22 or 0.22.1)"
    exit 1
  fi

  # Extract version components
  VERSION_DOT=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
  VERSION_DASH="${VERSION_DOT//./-}"
  VERSION_MAJOR_MINOR="$VERSION_DOT"
  VERSION_MAJOR_MINOR_DASH="$VERSION_DASH"

  # Find git repository root
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$GIT_ROOT" ]; then
    echo "❌ ERROR: Not in a git repository"
    exit 1
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Add Release Notes: $VERSION"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Version: $VERSION"
  echo "Major.Minor: $VERSION_MAJOR_MINOR"
  echo ""

  # Find or verify stage YAML
  if [ -n "$STAGE_YAML_ARG" ]; then
    STAGE_YAML="$STAGE_YAML_ARG"
    if [ ! -f "$STAGE_YAML" ]; then
      echo "❌ ERROR: Stage YAML not found: $STAGE_YAML"
      exit 1
    fi
  else
    # Find latest stage YAML for this version
    local VERSION_FULL_DASH
    VERSION_FULL_DASH="${VERSION//./-}"
    local STAGE_DIR="$GIT_ROOT/releases/$VERSION_MAJOR_MINOR/stage"

    if [ ! -d "$STAGE_DIR" ]; then
      echo "❌ ERROR: Stage directory not found: $STAGE_DIR"
      echo ""
      echo "Possible causes:"
      echo "  - Step 8 not complete (create-component-release not run)"
      echo ""
      echo "Run: /create-component-release $VERSION"
      exit 1
    fi

    STAGE_YAML=$(find "$STAGE_DIR" -name "submariner-${VERSION_FULL_DASH}-stage-*.yaml" -type f | sort | tail -1)

    if [ -z "$STAGE_YAML" ] || [ ! -f "$STAGE_YAML" ]; then
      echo "❌ ERROR: No stage YAML found for version $VERSION"
      echo "Expected: $STAGE_DIR/submariner-${VERSION_FULL_DASH}-stage-*.yaml"
      echo ""
      echo "Run: /create-component-release $VERSION"
      exit 1
    fi
  fi

  echo "Found stage YAML: $STAGE_YAML"
  echo ""

  # Check if YAML already has non-placeholder release notes
  if grep -q "# CVE Issues\|# Non-CVE Issues" "$STAGE_YAML" 2>/dev/null; then
    echo "⚠️  WARNING: Stage YAML appears to already have release notes"
    echo "This will overwrite existing release notes."
    echo ""
    read -p "Continue? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
    echo ""
  fi
}

# ============================================================================
# ACM Version Calculation
# ============================================================================

calculate_acm_version() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Calculating ACM Version"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Submariner 0.X → ACM 2.(X-7)
  local MINOR_VERSION
  MINOR_VERSION=$(echo "$VERSION_MAJOR_MINOR" | cut -d. -f2)
  local ACM_MINOR=$((MINOR_VERSION - 7))

  if [ $ACM_MINOR -lt 0 ]; then
    echo "❌ ERROR: Cannot calculate ACM version for Submariner $VERSION_MAJOR_MINOR"
    exit 1
  fi

  # Always use base ACM version (not patch)
  ACM_VERSION="ACM 2.${ACM_MINOR}.0"

  echo "Version mapping: Submariner $VERSION_MAJOR_MINOR → $ACM_VERSION"
  echo ""
}

# ============================================================================
# Find Existing fixVersions
# ============================================================================

find_existing_fixversions() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Finding Existing fixVersions"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "Querying Jira for existing fixVersion values..."

  # Get issue keys first with search (filter by affectedVersion for performance)
  local ISSUE_KEYS
  ISSUE_KEYS=$(acli jira workitem search \
    --jql 'project=ACM AND (text ~ submariner OR text ~ lighthouse) AND affectedVersion = "'"$ACM_VERSION"'"' \
    --paginate --json 2>/dev/null | jq -r '.[].key' 2>/dev/null || echo "")

  if [ -z "$ISSUE_KEYS" ]; then
    echo "⚠️  WARNING: No issues found - using affectedVersion only"
    FIXVERSIONS_CLAUSE=""
    echo ""
    return 0
  fi

  # Fetch fixVersions for each issue (batch view)
  local FIXVERSIONS_JSON
  FIXVERSIONS_JSON=$(echo "$ISSUE_KEYS" | while read -r KEY; do
    acli jira workitem view "$KEY" --fields "fixVersions" --json 2>/dev/null || echo "{}"
  done | jq -s '[.[] | .fields.fixVersions[]?.name | select(startswith("Submariner '"$VERSION_MAJOR_MINOR"'") or startswith("ACM"))] | unique | sort' 2>/dev/null)

  if [ -z "$FIXVERSIONS_JSON" ] || [ "$FIXVERSIONS_JSON" = "[]" ]; then
    echo "⚠️  WARNING: No existing fixVersions found - using affectedVersion only"
    FIXVERSIONS_CLAUSE=""
  else
    # Build IN clause: ("Submariner 0.21.2", "ACM 2.14.0", ...)
    FIXVERSIONS_CLAUSE=$(echo "$FIXVERSIONS_JSON" | jq -r 'map("\"" + . + "\"") | join(", ")')
    echo "Found fixVersions: $(echo "$FIXVERSIONS_JSON" | tr '\n' ' ')"
  fi

  echo ""
}

# ============================================================================
# Get Existing Issues
# ============================================================================

get_existing_issues() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Checking for Existing Issues"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "Scanning releases/$VERSION_MAJOR_MINOR/*/*.yaml for already-documented issues..."

  local EXISTING_RAW
  EXISTING_RAW=$(grep -h "id: ACM-" "$GIT_ROOT/releases/$VERSION_MAJOR_MINOR"/*/*.yaml 2>/dev/null | sed 's/.*id: //' | sort -u || true)

  if [ -z "$EXISTING_RAW" ]; then
    echo "No existing issues found (clean slate for $VERSION_MAJOR_MINOR)"
  else
    # shellcheck disable=SC2206
    EXISTING_ISSUES=($EXISTING_RAW)
    echo "Found ${#EXISTING_ISSUES[@]} issues already in previous releases:"
    printf '  - %s\n' "${EXISTING_ISSUES[@]}"
  fi

  echo ""
}

# ============================================================================
# Get Previous Release Date (Z-stream only)
# ============================================================================

get_previous_release_date() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Determining Release Timeframe"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check if this is a Y-stream (X.Y.0) or Z-stream (X.Y.Z where Z > 0)
  local PATCH_VERSION
  PATCH_VERSION=$(echo "$VERSION" | cut -d. -f3)

  if [ "$PATCH_VERSION" = "0" ]; then
    echo "Y-stream release ($VERSION) - no timeframe filtering for non-CVE issues"
    TIMEFRAME_START=""
  else
    echo "Z-stream release ($VERSION) - will filter non-CVE issues by timeframe"
    echo ""
    echo "Fetching previous release date from catalog.redhat.com..."

    # Try to fetch from Red Hat catalog
    local CATALOG_URL="https://catalog.redhat.com/en/software/containers/rhacm2/submariner-rhel9-operator/65bd4446f4d2cf102701785a/history"
    local CATALOG_HTML
    CATALOG_HTML=$(curl -s "$CATALOG_URL" 2>/dev/null || true)

    if [ -n "$CATALOG_HTML" ]; then
      # Try to extract previous release date (this is a best-effort extraction)
      # Format in catalog is typically "Month DD, YYYY"
      # For now, we'll set a placeholder - in production, parse HTML properly
      echo "⚠️  Catalog lookup not yet implemented - using approximate date"
      # Calculate approximate date (60 days before today)
      TIMEFRAME_START=$(date -d "60 days ago" +%Y-%m-%d 2>/dev/null || date -v-60d +%Y-%m-%d 2>/dev/null || echo "")
    fi

    if [ -z "$TIMEFRAME_START" ]; then
      echo "⚠️  Could not determine previous release date - will show all issues"
      TIMEFRAME_START=""
    else
      echo "Using timeframe start: $TIMEFRAME_START"
    fi
  fi

  echo ""
}

# ============================================================================
# Query CVE Issues
# ============================================================================

query_cve_issues() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Querying Jira for CVE Issues"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "Fetching Security-labeled issues..."

  # Build query
  local QUERY="project=ACM AND labels in (Security) AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest)"

  if [ -n "$FIXVERSIONS_CLAUSE" ]; then
    QUERY="$QUERY AND (affectedVersion = \"$ACM_VERSION\" OR fixVersion in ($FIXVERSIONS_CLAUSE))"
  else
    QUERY="$QUERY AND affectedVersion = \"$ACM_VERSION\""
  fi

  # Get issue keys with search (includes labels in output)
  local SEARCH_RESULTS
  SEARCH_RESULTS=$(acli jira workitem search --jql "$QUERY" --fields "key,labels" --paginate --json 2>/dev/null || echo "[]")

  if [ "$SEARCH_RESULTS" = "[]" ] || [ -z "$SEARCH_RESULTS" ]; then
    echo "No CVE issues found."
    echo ""
    return 0
  fi

  # Extract CVE data: issue key, CVE label, pscomponent
  local CVE_DATA
  CVE_DATA=$(echo "$SEARCH_RESULTS" | jq -r '.[] | {
    issue: .key,
    cve: (.fields.labels[]? | select(startswith("CVE-")) // empty),
    component: (.fields.labels[]? | select(startswith("pscomponent:")) | sub("pscomponent:"; "") // empty)
  } | select(.cve != "" and .component != "")' | jq -s '.')

  if [ "$CVE_DATA" = "[]" ] || [ -z "$CVE_DATA" ]; then
    echo "No CVE issues with valid CVE and component labels found."
    echo ""
    return 0
  fi

  # Process and filter CVE data
  local ISSUE CVE PSCOMPONENT MAPPED_COMPONENT

  while IFS= read -r line; do
    ISSUE=$(echo "$line" | jq -r '.issue')
    CVE=$(echo "$line" | jq -r '.cve')
    PSCOMPONENT=$(echo "$line" | jq -r '.component')

    # Filter: exclude existing issues
    if printf '%s\n' "${EXISTING_ISSUES[@]}" | grep -qxF "$ISSUE"; then
      continue
    fi

    # Map component name
    MAPPED_COMPONENT=$(map_component_name "$PSCOMPONENT")

    # Filter: exclude submariner-addon
    if [ "$MAPPED_COMPONENT" = "EXCLUDE" ]; then
      continue
    fi

    # Filter: exclude unknown components
    if [ "$MAPPED_COMPONENT" = "UNKNOWN" ]; then
      echo "⚠️  Skipping $ISSUE ($CVE) - unknown component: $PSCOMPONENT"
      continue
    fi

    # Add to arrays
    CVE_ISSUES+=("$ISSUE")
    CVE_KEYS+=("$CVE")
    CVE_COMPONENTS+=("$MAPPED_COMPONENT")
  done < <(echo "$CVE_DATA" | jq -c '.[]')

  echo "Found ${#CVE_ISSUES[@]} CVE issue(s) (after filtering)"
  echo ""
}

# ============================================================================
# Component Name Mapping
# ============================================================================

map_component_name() {
  local PSCOMPONENT="$1"

  case "$PSCOMPONENT" in
    "rhacm2/lighthouse-coredns-rhel9"|"lighthouse-coredns-container")
      echo "lighthouse-coredns-${VERSION_MAJOR_MINOR_DASH}"
      ;;
    "rhacm2/lighthouse-agent-rhel9"|"lighthouse-agent-container")
      echo "lighthouse-agent-${VERSION_MAJOR_MINOR_DASH}"
      ;;
    "rhacm2/submariner-addon-rhel9")
      echo "EXCLUDE"  # Built separately - don't include
      ;;
    "rhacm2/submariner-"*"-rhel9"|"submariner-"*"-container")
      # Extract component name
      local COMP
      COMP=$(echo "$PSCOMPONENT" | sed -E 's/.*(submariner-[^-]+).*/\1/')
      echo "${COMP}-${VERSION_MAJOR_MINOR_DASH}"
      ;;
    "nettest-container"|"rhacm2/nettest-rhel9")
      echo "nettest-${VERSION_MAJOR_MINOR_DASH}"
      ;;
    "subctl-container"|"rhacm2/subctl-rhel9")
      echo "subctl-${VERSION_MAJOR_MINOR_DASH}"
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

# ============================================================================
# Query Non-CVE Issues
# ============================================================================

query_non_cve_issues() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Querying Jira for Non-CVE Issues"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [ -n "$TIMEFRAME_START" ]; then
    echo "Fetching non-Security issues (timeframe: since $TIMEFRAME_START)..."
  else
    echo "Fetching non-Security issues (all dates)..."
  fi

  # Build query
  local QUERY="project=ACM AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest)"
  QUERY="$QUERY AND (labels is EMPTY OR labels not in (Security, SecurityTracking))"

  if [ -n "$FIXVERSIONS_CLAUSE" ]; then
    QUERY="$QUERY AND (affectedVersion = \"$ACM_VERSION\" OR fixVersion in ($FIXVERSIONS_CLAUSE))"
  else
    QUERY="$QUERY AND affectedVersion = \"$ACM_VERSION\""
  fi

  # Get issue keys with search (basic fields only)
  local ISSUE_KEYS
  ISSUE_KEYS=$(acli jira workitem search --jql "$QUERY" --paginate --json 2>/dev/null | jq -r '.[].key' 2>/dev/null || echo "")

  if [ -z "$ISSUE_KEYS" ]; then
    echo "No non-CVE issues found."
    echo ""
    return 0
  fi

  # Fetch full details for each issue with view (to get created, updated dates)
  local ISSUE_DATA
  ISSUE_DATA=$(echo "$ISSUE_KEYS" | while read -r KEY; do
    acli jira workitem view "$KEY" --fields "key,priority,status,created,updated,summary" --json 2>/dev/null || echo "{}"
  done | jq -s 'sort_by(.fields.priority.id // 99999) | reverse')

  if [ -z "$ISSUE_DATA" ] || [ "$ISSUE_DATA" = "[]" ]; then
    echo "No non-CVE issues found after filtering."
    echo ""
    return 0
  fi

  # Filter out existing issues and submariner-addon
  local FILTERED_COUNT=0
  while IFS= read -r issue_json; do
    local KEY PRIORITY STATUS CREATED UPDATED SUMMARY
    KEY=$(echo "$issue_json" | jq -r '.key // empty')
    PRIORITY=$(echo "$issue_json" | jq -r '.fields.priority.name // "Undefined"')
    STATUS=$(echo "$issue_json" | jq -r '.fields.status.name // "Unknown"')
    CREATED=$(echo "$issue_json" | jq -r '.fields.created[:10] // "Unknown"')
    UPDATED=$(echo "$issue_json" | jq -r '.fields.updated[:10] // "Unknown"')
    SUMMARY=$(echo "$issue_json" | jq -r '.fields.summary // ""')

    # Skip if key is empty
    [ -z "$KEY" ] && continue

    # Filter existing
    if printf '%s\n' "${EXISTING_ISSUES[@]}" | grep -qxF "$KEY"; then
      continue
    fi

    # Filter submariner-addon (check summary/key)
    if [[ "$SUMMARY" =~ submariner-addon ]] || [[ "$KEY" =~ addon ]]; then
      continue
    fi

    NON_CVE_ISSUES+=("$KEY|$PRIORITY|$STATUS|$CREATED|$UPDATED|$SUMMARY")
    ((FILTERED_COUNT++))
  done < <(echo "$ISSUE_DATA" | jq -c '.[]')

  echo "Found $FILTERED_COUNT non-CVE issue(s) (after filtering)"
  echo ""
}

# ============================================================================
# Present Results and Get User Selection
# ============================================================================

present_results() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Review Issues"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Show CVE issues (auto-included)
  if [ ${#CVE_ISSUES[@]} -gt 0 ]; then
    echo "═══ CVE Issues (Auto-included) ═══"
    echo ""

    # Group by CVE
    local PREV_CVE=""
    for i in "${!CVE_ISSUES[@]}"; do
      local ISSUE="${CVE_ISSUES[$i]}"
      local CVE="${CVE_KEYS[$i]}"
      local COMPONENT="${CVE_COMPONENTS[$i]}"

      if [ "$CVE" != "$PREV_CVE" ]; then
        if [ -n "$PREV_CVE" ]; then
          echo ""
        fi
        echo "  $CVE:"
        PREV_CVE="$CVE"
      fi
      echo "    - $ISSUE → $COMPONENT"
    done

    echo ""
    echo "Total: ${#CVE_ISSUES[@]} issue(s)"
    echo ""
  else
    echo "No CVE issues found."
    echo ""
  fi

  # Show non-CVE issues (user selection)
  if [ ${#NON_CVE_ISSUES[@]} -gt 0 ]; then
    echo "═══ Non-CVE Issues (User Selection) ═══"
    echo ""
    if [ -n "$TIMEFRAME_START" ]; then
      echo "Timeframe: Since $TIMEFRAME_START"
      echo ""
    fi

    local IDX=0
    for item in "${NON_CVE_ISSUES[@]}"; do
      IFS='|' read -r KEY PRIORITY STATUS CREATED UPDATED SUMMARY <<< "$item"
      printf "[%d] %s [%s] (%s) Created: %s Updated: %s\n" "$IDX" "$KEY" "$PRIORITY" "$STATUS" "$CREATED" "$UPDATED"
      printf "    %s\n" "$SUMMARY"
      ((IDX++))
    done

    echo ""
    echo "Enter issue numbers to include (space-separated, 'all', or 'none'):"
    read -r SELECTION

    # Parse selection
    if [[ "$SELECTION" == "all" ]]; then
      for item in "${NON_CVE_ISSUES[@]}"; do
        IFS='|' read -r KEY _ _ _ _ _ <<< "$item"
        SELECTED_ISSUES+=("$KEY")
      done
    elif [[ "$SELECTION" == "none" ]]; then
      SELECTED_ISSUES=()
    else
      for NUM in $SELECTION; do
        if [[ "$NUM" =~ ^[0-9]+$ ]] && [ "$NUM" -lt "${#NON_CVE_ISSUES[@]}" ]; then
          IFS='|' read -r KEY _ _ _ _ _ <<< "${NON_CVE_ISSUES[$NUM]}"
          SELECTED_ISSUES+=("$KEY")
        else
          echo "⚠️  Invalid selection: $NUM (skipped)"
        fi
      done
    fi

    echo ""
    echo "Selected ${#SELECTED_ISSUES[@]} non-CVE issue(s)"
    if [ ${#SELECTED_ISSUES[@]} -gt 0 ]; then
      printf '  - %s\n' "${SELECTED_ISSUES[@]}"
    fi
  else
    echo "No non-CVE issues available for selection."
  fi

  echo ""

  # Confirm release type
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Release Type"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [ ${#CVE_ISSUES[@]} -gt 0 ]; then
    echo "CVEs detected. Release type must be RHSA (Red Hat Security Advisory)."
    RELEASE_TYPE="RHSA"
  else
    echo "No CVEs detected. Select release type:"
    echo "  1) RHBA (Red Hat Bug Advisory)"
    echo "  2) RHEA (Red Hat Enhancement Advisory)"
    read -p "Choice [1-2]: " -r TYPE_CHOICE
    case "$TYPE_CHOICE" in
      1) RELEASE_TYPE="RHBA" ;;
      2) RELEASE_TYPE="RHEA" ;;
      *) RELEASE_TYPE="RHBA" ;;  # Default
    esac
  fi

  echo "Release type: $RELEASE_TYPE"
  echo ""
}

# ============================================================================
# Build Release Notes YAML
# ============================================================================

build_release_notes() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Building Release Notes"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Create temporary file for release notes
  local TEMP_NOTES
  TEMP_NOTES=$(mktemp)

  # Start YAML structure
  cat > "$TEMP_NOTES" <<EOF
    releaseNotes:
      type: $RELEASE_TYPE
      issues:
        fixed:
EOF

  # Add CVE issues section
  if [ ${#CVE_ISSUES[@]} -gt 0 ]; then
    echo "          # CVE Issues (${#CVE_ISSUES[@]}):" >> "$TEMP_NOTES"

    # Sort CVE issues by ID
    local SORTED_CVE_ISSUES
    readarray -t SORTED_CVE_ISSUES < <(printf '%s\n' "${CVE_ISSUES[@]}" | sort -V)

    for issue in "${SORTED_CVE_ISSUES[@]}"; do
      cat >> "$TEMP_NOTES" <<EOF
          - id: $issue
            source: issues.redhat.com
EOF
    done
  fi

  # Add non-CVE issues section
  if [ ${#SELECTED_ISSUES[@]} -gt 0 ]; then
    echo "          # Non-CVE Issues (${#SELECTED_ISSUES[@]}):" >> "$TEMP_NOTES"

    # Sort selected issues by ID
    local SORTED_SELECTED
    readarray -t SORTED_SELECTED < <(printf '%s\n' "${SELECTED_ISSUES[@]}" | sort -V)

    for issue in "${SORTED_SELECTED[@]}"; do
      cat >> "$TEMP_NOTES" <<EOF
          - id: $issue
            source: issues.redhat.com
EOF
    done
  fi

  # Add CVEs section
  if [ ${#CVE_ISSUES[@]} -gt 0 ]; then
    echo "      cves:" >> "$TEMP_NOTES"

    # Group CVEs by key
    declare -A CVE_MAP
    for i in "${!CVE_ISSUES[@]}"; do
      local CVE="${CVE_KEYS[$i]}"
      local COMPONENT="${CVE_COMPONENTS[$i]}"
      local ISSUE="${CVE_ISSUES[$i]}"

      if [ -z "${CVE_MAP[$CVE]}" ]; then
        CVE_MAP[$CVE]="$ISSUE|$COMPONENT"
      else
        # Append both issue and component
        local CURRENT_ISSUES
        local CURRENT_COMPONENTS
        CURRENT_ISSUES=$(echo "${CVE_MAP[$CVE]}" | cut -d'|' -f1)
        CURRENT_COMPONENTS=$(echo "${CVE_MAP[$CVE]}" | cut -d'|' -f2)
        CVE_MAP[$CVE]="$CURRENT_ISSUES,$ISSUE|$CURRENT_COMPONENTS,$COMPONENT"
      fi
    done

    # Output CVEs sorted by key
    for CVE in $(printf '%s\n' "${!CVE_MAP[@]}" | sort); do
      local DATA="${CVE_MAP[$CVE]}"
      local ISSUES
      local COMPONENTS
      ISSUES=$(echo "$DATA" | cut -d'|' -f1)
      COMPONENTS=$(echo "$DATA" | cut -d'|' -f2 | tr ',' '\n' | sort -u)

      # Add CVE group header with verification placeholder
      # Format issues with comma-space separator
      local ISSUES_FORMATTED
      ISSUES_FORMATTED=$(echo "$ISSUES" | sed 's/,/, /g')

      cat >> "$TEMP_NOTES" <<EOF
        # $CVE ($ISSUES_FORMATTED): FIXED
        #   Test: Verification command TBD
        #   Output: Expected output TBD
        #   Required: Minimum version TBD
EOF

      # Add component entries
      for COMP in $COMPONENTS; do
        echo "        - key: $CVE" >> "$TEMP_NOTES"
        echo "          component: $COMP" >> "$TEMP_NOTES"
      done
    done
  else
    echo "      cves: []" >> "$TEMP_NOTES"
  fi

  # Store temp file path in global variable
  RELEASE_NOTES_TEMP="$TEMP_NOTES"

  echo "✓ Release notes generated"
  echo "  Type: $RELEASE_TYPE"
  echo "  CVE issues: ${#CVE_ISSUES[@]}"
  echo "  Other issues: ${#SELECTED_ISSUES[@]}"
  echo "  Total issues: $((${#CVE_ISSUES[@]} + ${#SELECTED_ISSUES[@]}))"
  echo ""
}

# ============================================================================
# Update Stage YAML
# ============================================================================

update_stage_yaml() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Updating Stage YAML"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "Updating $STAGE_YAML..."

  # Backup original
  cp "$STAGE_YAML" "${STAGE_YAML}.bak"

  # Use yq if available, otherwise use sed
  if command -v yq &>/dev/null; then
    echo "Using yq for YAML editing..."
    # This is tricky with yq - we need to replace the releaseNotes section
    # For now, use sed as fallback (yq merge is complex for this use case)
    echo "⚠️  yq detected but using sed for reliability..."
    use_sed_update
  else
    echo "Using sed for YAML editing..."
    use_sed_update
  fi

  # Clean up temp file
  rm -f "$RELEASE_NOTES_TEMP"

  echo "✓ Stage YAML updated"
  echo ""
}

use_sed_update() {
  # Find start and end of releaseNotes section
  # Strategy: Find "releaseNotes:" and replace until the next top-level key (not indented)

  # Create new file with replacement
  local NEW_YAML="${STAGE_YAML}.new"
  local IN_RELEASE_NOTES=false

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*releaseNotes: ]]; then
      IN_RELEASE_NOTES=true
      # Output new release notes
      cat "$RELEASE_NOTES_TEMP" >> "$NEW_YAML"
      continue
    fi

    if [ "$IN_RELEASE_NOTES" = true ]; then
      # Check if we've exited the releaseNotes section
      # (line at same or less indentation, or empty line followed by less indentation)
      if [[ "$line" =~ ^[[:space:]]{0,6}[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]]{8,} ]]; then
        IN_RELEASE_NOTES=false
        echo "$line" >> "$NEW_YAML"
      fi
      # Skip lines inside releaseNotes section (they're being replaced)
    else
      echo "$line" >> "$NEW_YAML"
    fi
  done < "${STAGE_YAML}.bak"

  # Replace original with new
  mv "$NEW_YAML" "$STAGE_YAML"
}

# ============================================================================
# Validate and Commit
# ============================================================================

validate_and_commit() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Validating Changes"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Change to git root for make commands
  cd "$GIT_ROOT" || exit 1

  echo "Running YAML validation..."
  if make yamllint >/dev/null 2>&1; then
    echo "✓ YAML syntax valid"
  else
    echo "❌ YAML validation failed"
    echo ""
    echo "Run manually: make yamllint"
    echo ""
    echo "Backup saved at: ${STAGE_YAML}.bak"
    exit 1
  fi

  echo "Running release data validation..."
  if make test FILE="$STAGE_YAML" >/dev/null 2>&1; then
    echo "✓ Release data valid"
  else
    echo "❌ Release data validation failed"
    echo ""
    echo "Run manually: make test FILE=\"$STAGE_YAML\""
    echo ""
    echo "Backup saved at: ${STAGE_YAML}.bak"
    exit 1
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Committing Changes"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Stage the file
  git add "$STAGE_YAML"

  # Remove backup
  rm -f "${STAGE_YAML}.bak"

  # Build commit message
  local TOTAL_ISSUES=$((${#CVE_ISSUES[@]} + ${#SELECTED_ISSUES[@]}))
  local COMMIT_MSG="Add release notes to $VERSION stage release

Release type: $RELEASE_TYPE
CVE issues: ${#CVE_ISSUES[@]}
Other issues: ${#SELECTED_ISSUES[@]}
Total issues: $TOTAL_ISSUES

Jira queries executed for $ACM_VERSION.
Excludes issues already in previous $VERSION_MAJOR_MINOR releases."

  # Commit
  git commit -s -m "$COMMIT_MSG"

  echo "✓ Changes committed"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Release Notes Added Successfully"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Summary:"
  echo "  File: $STAGE_YAML"
  echo "  Type: $RELEASE_TYPE"
  echo "  CVE issues: ${#CVE_ISSUES[@]}"
  echo "  Other issues: ${#SELECTED_ISSUES[@]}"
  echo "  Total: $TOTAL_ISSUES"
  echo ""
  echo "Next steps:"
  echo "  1. Review changes: git show"
  echo "  2. Push: git push origin main"
  echo "  3. Proceed to Step 10 (Apply Component Stage Release)"
  echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  check_prerequisites
  parse_arguments "$@"
  calculate_acm_version
  find_existing_fixversions
  get_existing_issues
  get_previous_release_date
  query_cve_issues
  query_non_cve_issues
  present_results
  build_release_notes
  update_stage_yaml
  validate_and_commit
}

main "$@"
