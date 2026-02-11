#!/bin/bash
# Check Submariner release status across all workflow steps

set -euo pipefail

# Parse arguments
VERSION="${1:-}"

if [ "$VERSION" = "help" ] || [ -z "$VERSION" ]; then
  echo "Usage: scripts/release-status.sh <version>"
  echo ""
  echo "Examples:"
  echo "  scripts/release-status.sh 0.22.1    Check Z-stream release"
  echo "  scripts/release-status.sh 0.22      Check Y-stream release"
  exit 0
fi

# Validate format
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
  echo "Error: Invalid version format"
  echo "Expected: X.Y or X.Y.Z (e.g., 0.22 or 0.22.1)"
  exit 1
fi

# Extract version components
MAJOR_MINOR=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
MAJOR_MINOR_DASH=$(echo "$MAJOR_MINOR" | tr '.' '-')
FULL_VERSION_DASH=$(echo "$VERSION" | tr '.' '-')

# Detect stream type
# Y-stream: X.Y or X.Y.0 (initial release)
# Z-stream: X.Y.Z where Z>0 (patch releases)
IS_ZSTREAM=false
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[1-9][0-9]*$'; then
  IS_ZSTREAM=true
fi

# Constants
readonly SECONDS_PER_DAY=86400
readonly FBC_DATE_MATCH_WINDOW_DAYS=3
readonly FBC_DATE_MATCH_WINDOW_SECS=$((FBC_DATE_MATCH_WINDOW_DAYS * SECONDS_PER_DAY))
readonly BUNDLE_CLOCK_SKEW_SECS=300  # 5 minutes tolerance for clock skew
readonly CURRENT_OCP_VERSION_COUNT=6
readonly OCP_VERSIONS="16 17 18 19 20 21"

# Submariner component repos (for branch checks)
readonly SUBMARINER_REPOS="submariner-operator submariner lighthouse shipyard subctl admiral cloud-prepare"

# Step Metadata: number|name|phase|stream|workflow|check-numbers
# stream: Y=Y-stream only, Z=Z-stream only, B=both
# check-numbers: optional, for multi-step checks (e.g., "12-13")
declare -a RELEASE_STEPS=(
  # Phase 1: Upstream Preparation (Y-stream only)
  "1|Upstream Release Branch|upstream-prep|Y|create-release-branch.md|"
  "2|Konflux ReleasePlans|upstream-prep|Y|configure-downstream.md|"

  # Phase 2: Component Preparation
  "3|Component Tekton Config|component-prep|Y|fix-tekton-prs.md|"
  "3b|Bundle Tekton Config|component-prep|Y|fix-tekton-bundle.md|"
  "4|Enterprise Contract|component-prep|B|fix-ec-violations.md|"
  "5|CVE Scanning|component-prep|B|scan-cves.md|"
  "5b|Version Labels|component-prep|Z|update-version-labels.md|"

  # Phase 3: Upstream Release
  "6|Upstream Release|upstream-release|B|cut-upstream-release.md|"
  "7|Bundle SHAs|upstream-release|B|update-bundle-shas.md|"

  # Phase 4: Component Stage
  "8_10|Component Stage Release|component-stage|B|create-release.md|8-10"
  "10b|Check Stage Build|component-stage|B|check-component-release.md|"

  # Phase 5: FBC Stage
  "11|FBC Catalog Update|fbc-stage|B|update-fbc-stage.md|"
  "12_13|FBC Stage Releases|fbc-stage|B|create-fbc-stage-release.md|12-13"
  "13b|Check FBC Stage|fbc-stage|B|check-fbc-releases.md|"
  "14|QE Approval|fbc-stage|B|share-with-qe.md|"

  # Phase 6: Component Prod
  "15_16|Component Prod Release|component-prod|B|create-prod-release.md|15-16"
  "16b|Check Prod Build|component-prod|B|check-component-release.md|"

  # Phase 7: FBC Prod
  "17_18|FBC Prod Releases|fbc-prod|B|create-fbc-prod-release.md|17-18"
  "18b|Check FBC Prod|fbc-prod|B|check-fbc-releases.md|"
  "19|Share Prod with QE|fbc-prod|B|share-with-qe.md|"
  "20|Update FBC Templates|fbc-prod|B|update-fbc-templates-prod.md|"
)

# Phase display names (for section headers)
declare -A PHASE_NAMES=(
  ["upstream-prep"]="BRANCH & CONFIGURATION SETUP"
  ["component-prep"]="CI/CD & QUALITY CHECKS"
  ["upstream-release"]="UPSTREAM & BUILD PREPARATION"
  ["component-stage"]="STAGE RELEASE"
  ["fbc-stage"]="FBC STAGE RELEASE"
  ["component-prod"]="PRODUCTION RELEASE"
  ["fbc-prod"]="FBC PRODUCTION RELEASE"
)

# ============================================================================
# Common Helper Functions
# ============================================================================

# Get snapshot test status annotation
# Args: $1=snapshot_name
# Returns: JSON test status or empty string
get_snapshot_test_status() {
  local snapshot=$1
  oc get snapshot "$snapshot" -n submariner-tenant \
    -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' 2>/dev/null || true
}

# Format date with fallback
# Args: $1=date_string $2=format (default: '%Y-%m-%d %H:%M')
# Returns: Formatted date or original string on error
format_date() {
  local date_str=$1
  local format=${2:-%Y-%m-%d %H:%M}
  date -d "$date_str" +"$format" 2>/dev/null || echo "$date_str"
}

# Count words in space-separated string (bash-native)
# Args: $1=space_separated_string
# Returns: word count
count_words() {
  local str=$1
  [ -z "$str" ] && { echo 0; return; }
  local -a arr
  read -ra arr <<< "$str"
  echo "${#arr[@]}"
}

# Helper function: Extract metadata field from step definition
# Args: $1=step_definition $2=field_index (1=num, 2=name, 3=phase, 4=stream, 5=workflow, 6=check-numbers)
get_step_field() {
  echo "$1" | cut -d'|' -f"$2"
}

# Helper function: Check if step applies to current release stream
# Args: $1=stream_code (Y/Z/B) $2=is_zstream_bool
step_applies_to_stream() {
  local stream=$1
  local is_z=$2

  case "$stream" in
    B) return 0 ;;  # Both streams
    Y) [ "$is_z" = "false" ] && return 0 ;;
    Z) [ "$is_z" = "true" ] && return 0 ;;
  esac
  return 1
}

# Helper function: Detect if release is completed, in-progress, or not-started
# Returns: "complete" | "in-progress" | "not-started"
#
# Uses component prod YAML existence as completion signal (permanent record).
# NOTE: Cannot rely on cluster state (Release CRs deleted after completion)
# NOTE: Cannot use FBC YAMLs (filenames don't contain Submariner version)
detect_release_state() {
  # Check for component prod YAML (permanent record, has version in filename)
  local prod_yaml
  prod_yaml=$(find "releases/$MAJOR_MINOR/prod/" -name "submariner-$FULL_VERSION_DASH-prod-*.yaml" 2>/dev/null | head -1)
  [ -n "$prod_yaml" ] && echo "complete" && return

  # Check for component stage YAML (release started but not complete)
  local stage_yaml
  stage_yaml=$(find "releases/$MAJOR_MINOR/stage/" -name "submariner-$FULL_VERSION_DASH-stage-*.yaml" 2>/dev/null | head -1)
  [ -n "$stage_yaml" ] && echo "in-progress" && return

  echo "not-started"
}

# Helper function: Infer which OCP versions were in scope for this release
# Uses date heuristic to find FBC YAMLs created around component release time
# Args:
#   $1 - Environment type ("stage" or "prod")
# Returns: space-separated list (e.g., "16 17 18 19 20")
#
# This handles the case where new OCP versions are added over time.
# E.g., 0.22.0 released with OCP 4-16 through 4-20, then 4-21 support added later
#
# NOTE: FBC YAML filenames don't contain Submariner version (catalogs are cumulative),
# so we use date-matching to find FBC YAMLs created near the component release.
get_release_ocp_scope() {
  local env=$1
  local versions=""

  # Find first component YAML to get original release date
  # Use head -1 to get earliest (first release, not retries)
  local component_yaml
  component_yaml=$(find "releases/$MAJOR_MINOR/$env/" -name "submariner-$FULL_VERSION_DASH-$env-*.yaml" 2>/dev/null | head -1)
  [ -z "$component_yaml" ] && return  # No component YAML, can't determine scope

  # Extract date from component filename: submariner-0-22-0-stage-20251203-01.yaml → 20251203
  local component_date_str
  component_date_str=$(basename "$component_yaml" | grep -oP '\d{8}')
  local component_epoch
  component_epoch=$(date -d "$component_date_str" +%s 2>/dev/null || echo 0)

  [ "$component_epoch" -eq 0 ] && return  # Invalid date, can't determine scope

  # Find FBC YAMLs created within ±3 days of component release
  for ocp_version in $OCP_VERSIONS; do
    for yaml in releases/fbc/4-$ocp_version/$env/*.yaml; do
      [ ! -f "$yaml" ] && continue

      # Extract date from FBC filename: submariner-fbc-4-16-stage-20251204-01.yaml → 20251204
      local fbc_date_str
      fbc_date_str=$(basename "$yaml" | grep -oP '\d{8}')
      local fbc_epoch
      fbc_epoch=$(date -d "$fbc_date_str" +%s 2>/dev/null || echo 0)

      [ "$fbc_epoch" -eq 0 ] && continue

      # Calculate date difference (absolute value)
      local date_diff=$((fbc_epoch - component_epoch))
      local date_diff_abs=${date_diff#-}  # Remove leading minus if negative

      # Check if within ±3 days
      if [ "$date_diff_abs" -lt "$FBC_DATE_MATCH_WINDOW_SECS" ]; then
        versions="$versions $ocp_version"
        break  # Found match for this OCP version, move to next
      fi
    done
  done

  echo "$versions" | xargs  # Trim whitespace
}

# Helper function: Extract date from component release YAML filename
# Args: $1 = env ("stage" or "prod")
# Returns: YYYYMMDD date string or empty
# Uses globals: MAJOR_MINOR, FULL_VERSION_DASH
# Note: Uses head -1 to get earliest (first release, not retries) for historical matching
get_component_yaml_date() {
  local env=$1
  local yaml_file
  yaml_file=$(find "releases/$MAJOR_MINOR/$env/" -name "submariner-$FULL_VERSION_DASH-$env-*.yaml" 2>/dev/null | head -1)

  [ -z "$yaml_file" ] && return

  # Extract date from filename: submariner-0-22-0-stage-20251203-01.yaml → 20251203
  basename "$yaml_file" | grep -oP '\d{8}' | head -1
}

# Helper function: Find FBC YAML closest to component release date
# Args:
#   $1 = OCP version (e.g., "16" for 4-16)
#   $2 = env ("stage" or "prod")
#   $3 = target date (YYYYMMDD)
# Returns: YAML filename or empty
#
# Matches FBC YAMLs by date proximity (within ±3 days) since FBC filenames
# don't contain Submariner version (catalogs are cumulative across versions).
find_fbc_yaml_by_date() {
  local ocp_version=$1
  local env=$2
  local target_date=$3
  local target_epoch

  [ -z "$target_date" ] && return

  # Convert target date to epoch for math
  target_epoch=$(date -d "$target_date" +%s 2>/dev/null || echo 0)
  [ "$target_epoch" -eq 0 ] && return

  local best_yaml=""
  local best_diff=999999

  # Search all YAMLs in directory
  for yaml in releases/fbc/4-$ocp_version/$env/*.yaml; do
    [ ! -f "$yaml" ] && continue

    # Extract date from filename
    local yaml_date
    yaml_date=$(basename "$yaml" | grep -oP '\d{8}' | head -1)
    [ -z "$yaml_date" ] && continue

    local yaml_epoch
    yaml_epoch=$(date -d "$yaml_date" +%s 2>/dev/null || echo 0)
    [ "$yaml_epoch" -eq 0 ] && continue

    # Calculate absolute difference
    local diff=$((yaml_epoch - target_epoch))
    local abs_diff=${diff#-}  # Remove leading minus if negative (bash abs value)

    # Within 3 days and closer than previous best?
    if [ "$abs_diff" -lt "$FBC_DATE_MATCH_WINDOW_SECS" ] && [ "$abs_diff" -lt "$best_diff" ]; then
      best_yaml="$yaml"
      best_diff="$abs_diff"
    fi
  done

  echo "$best_yaml"
}

# Helper function: Calculate missing OCP versions
# Args:
#   $1 - Current scope (space-separated OCP versions, e.g., "16 17 18 19 20")
# Returns: space-separated list of missing versions compared to OCP_VERSIONS
#
# Example: If OCP_VERSIONS="16 17 18 19 20 21" and scope="16 17 18 19 20", returns "21"
get_missing_ocp_versions() {
  local scope=$1
  comm -13 <(echo "$scope" | tr ' ' '\n' | sort) <(echo "$OCP_VERSIONS" | tr ' ' '\n' | sort) | tr '\n' ' ' | xargs
}

# Helper function: Report FBC scope with context about OCP versions
# Args:
#   $1 - Environment (stage/prod)
#   $2 - YAML count
#   $3 - Scope (space-separated OCP versions)
#   $4 - Step number for "Next" messages
# Uses global: RELEASE_STATE, OCP_VERSIONS
report_fbc_scope() {
  local env=$1
  local yaml_count=$2
  local scope=$3
  local step_num=$4
  local current_total=$CURRENT_OCP_VERSION_COUNT

  if [ "$yaml_count" -lt "$current_total" ]; then
    if [ "$RELEASE_STATE" = "complete" ]; then
      # For completed releases, show what was released at the time
      echo "📄 FBC $env YAMLs: $yaml_count at release time (OCP 4-$scope)"
      # Calculate missing versions
      local missing_versions
      missing_versions=$(get_missing_ocp_versions "$scope")
      [ -n "$missing_versions" ] && echo "   ℹ️  OCP 4-$missing_versions support added after this release"
    else
      # For in-progress releases, incomplete scope is a blocker
      echo "⚠️  Incomplete: $yaml_count/$current_total FBC $env YAMLs"
      echo "   ⮕ Next: Create missing FBC $env releases (Step $step_num)"
    fi
  else
    echo "✅ All $yaml_count FBC $env YAMLs"
  fi
}

# Helper function: Check component release status on cluster
# Args:
#   $1 - Release name from YAML
#   $2 - Environment type ("stage" or "prod") for error messages
# Uses global: RELEASE_STATE for conditional reporting
#
# Note: Release CRs are created in submariner-tenant namespace but get archived
# after completion (visible in Konflux UI but not via 'oc get'). For completed
# prod releases, we verify via registry.redhat.io instead.
check_component_release_status() {
  local release_name=$1
  local env=$2
  local status
  local reason
  local env_type

  if [ -z "$release_name" ]; then
    return 1
  fi

  # Extract just "stage" or "prod" from env parameter (may include step numbers)
  env_type=$(echo "$env" | grep -oE '^(stage|prod)' || echo "")

  # Check submariner-tenant namespace (where Release CRs are created per ReleasePlanAdmission origin)
  status=$(oc get release "$release_name" -n submariner-tenant \
    -o jsonpath='{.status.conditions[?(@.type=="Released")].status}' 2>/dev/null || true)
  reason=$(oc get release "$release_name" -n submariner-tenant \
    -o jsonpath='{.status.conditions[?(@.type=="Released")].reason}' 2>/dev/null || true)

  if [ -z "$status" ]; then
    # Release CR not found - may be archived or not yet applied
    # For completed prod releases, verify via production registry
    if [ "$RELEASE_STATE" = "complete" ] && [ "$env_type" = "prod" ]; then
      # For completed prod releases, check production registry as source of truth
      local bundle_version
      bundle_version=$(skopeo inspect "docker://registry.redhat.io/rhacm2/submariner-operator-bundle:v$VERSION" 2>/dev/null | \
        jq -r '.Labels.version // empty' 2>/dev/null || true)

      if [ "$bundle_version" = "v$VERSION" ]; then
        echo "   ✅ Released to production (verified in registry)"
      else
        echo "   ⚠️  Not found on cluster or registry"
      fi
    elif [ "$RELEASE_STATE" = "complete" ]; then
      # For completed stage releases, Release CRs may be archived/deleted
      echo "   ℹ️  Not on cluster (release complete, CR may be archived)"
    else
      # For in-progress releases, missing CR is a blocker
      echo "   ⚠️  Not found on cluster"
      echo "   ⮕ Next: Apply $env release"
    fi
  elif [ "$status" = "True" ] && [ "$reason" = "Succeeded" ]; then
    echo "   ✅ Release succeeded"
  elif [ "$reason" = "Progressing" ]; then
    echo "   🔄 Release in progress"
  else
    echo "   ❌ Release failed: $reason"
    echo "   ⮕ Next: Debug failure"
  fi
}

# Helper function: Check if a version label in a Dockerfile matches expected value
# Args:
#   $1 - GitHub repo name (e.g., "submariner-operator")
#   $2 - Dockerfile path in repo
#   $3 - Label name to check ("version", "csv-version", etc.)
#   $4 - Expected value
# Uses globals: MAJOR_MINOR (for branch reference)
# Modifies global: INCORRECT array (appends mismatches)
check_version_label() {
  local repo=$1
  local file=$2
  local label_name=$3
  local expected=$4
  local content actual

  content=$(gh api "repos/submariner-io/$repo/contents/$file?ref=release-$MAJOR_MINOR" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)
  if [ -z "$content" ]; then
    echo "   ⚠️  Cannot fetch $repo/$file" >&2
    return
  fi

  # Bundle files use LABEL directives, others use bare version= lines
  if [ "$file" = "bundle.Dockerfile.konflux" ]; then
    # Extract from LABEL lines with quoted values: LABEL version="v0.22.0"
    actual=$(echo "$content" | grep "^LABEL $label_name=" | sed -n 's/.*="\([^"]*\)"/\1/p' | head -1 || true)
  else
    # Extract from version= lines (not ldflags): version="v0.22.0"
    # Exclude ldflags lines which also contain version= but for build-time injection
    actual=$(echo "$content" | grep '^ *version=' | grep -v ldflags | grep -oP 'v[0-9.]+' | head -1 || true)
  fi

  if [ "$actual" != "$expected" ]; then
    INCORRECT+=("$repo/$file ($label_name: $actual)")
  fi
}

# Helper function: Detect current release phase based on workflow state
# Returns one of: upstream-prep, component-prep, upstream-release, component-stage,
#                 fbc-stage, qe-approval, component-prod, fbc-prod, complete
#
# Uses globals (set by step check functions):
#   RELEASE_STATE, IS_ZSTREAM, VERSION, MAJOR_MINOR_DASH, SNAPSHOT
#   Y-stream: BRANCH_CHECK, STAGE_PLAN, MISSING_TEKTON
#   Build: TAG_EXISTS, WRONG_COUNT, IMAGE_VERSION
#   Stage: STAGE_YAML, FBC_STAGE_YAML_COUNT, FBC_SUCCEEDED
#   Prod: PROD_YAML, FBC_PROD_YAML_COUNT, FBC_PROD_SUCCEEDED
detect_current_phase() {
  # Use release state detection FIRST (most reliable signal)
  # Completed releases have prod YAML, so they return "complete" immediately
  # This prevents false phase detection based on missing/cleaned-up resources
  if [ "$RELEASE_STATE" = "complete" ]; then
    echo "complete"
    return
  fi

  # Not-started releases have no YAMLs
  if [ "$RELEASE_STATE" = "not-started" ]; then
    echo "not-started"
    return
  fi

  # For in-progress releases, check blockers in workflow order
  # Y-stream blockers first (early exit pattern)
  if [ "$IS_ZSTREAM" = "false" ]; then
    [ -z "$BRANCH_CHECK" ] && echo "upstream-prep" && return
    [ -z "$STAGE_PLAN" ] || [ -z "$PROD_PLAN" ] && echo "upstream-prep" && return
    [ "$MISSING_TEKTON" -gt 0 ] && echo "component-prep" && return
  fi

  # Common blockers (apply to both Y and Z streams)
  [ -z "$TAG_EXISTS" ] && echo "upstream-release" && return
  [ "$WRONG_COUNT" -gt 0 ] && echo "upstream-release" && return
  [ -z "$SNAPSHOT" ] && echo "upstream-release" && return

  # Reuse IMAGE_VERSION from test verification if available, otherwise fetch
  local image_version_local="$IMAGE_VERSION"
  if [ "$IMAGE_VERSION_FETCHED" != "true" ]; then
    local image
    image=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant \
      -o jsonpath="{.spec.components[?(@.name==\"lighthouse-agent-$MAJOR_MINOR_DASH\")].containerImage}" 2>/dev/null || true)
    if [ -n "$image" ]; then
      image_version_local=$(skopeo inspect "docker://$image" 2>/dev/null | jq -r '.Labels.version' 2>/dev/null || true)
    fi
  fi

  [ -n "$image_version_local" ] && [ "$image_version_local" != "v$VERSION" ] && echo "upstream-release" && return

  # Stage blockers
  [ -z "$STAGE_YAML" ] && echo "component-stage" && return
  [ "$FBC_STAGE_YAML_COUNT" -eq 0 ] && echo "fbc-stage" && return
  [ "$FBC_SUCCEEDED" -lt "$FBC_STAGE_YAML_COUNT" ] && echo "fbc-stage" && return

  # QE approval checkpoint
  [ -z "$PROD_YAML" ] && echo "qe-approval" && return

  # Prod blockers (should not reach here if RELEASE_STATE = "complete")
  [ "$FBC_PROD_YAML_COUNT" -eq 0 ] && echo "component-prod" && return
  [ "$FBC_PROD_SUCCEEDED" -lt "$FBC_PROD_YAML_COUNT" ] && echo "fbc-prod" && return

  # All in-progress conditions met (should match "complete" state)
  echo "complete"
}

# Helper function: Check FBC release status across OCP versions in scope
# Args:
#   $1 = environment (stage/prod)
#   $2 = full_version_dash
#   $3 = scope (space-separated OCP versions, e.g., "16 17 18 19 20") [optional, defaults to all]
# Sets globals: FBC_NOT_APPLIED, FBC_IN_PROGRESS, FBC_SUCCEEDED, FBC_FAILED (for stage)
#              FBC_PROD_NOT_APPLIED, FBC_PROD_IN_PROGRESS, FBC_PROD_SUCCEEDED, FBC_PROD_FAILED (for prod)
check_fbc_release_status() {
  local env=$1
  local version_dash=$2
  local scope="${3:-$OCP_VERSIONS}"  # Default to all if not specified

  # Determine variable prefix based on environment
  # Creates: FBC_* for stage, FBC_PROD_* for prod (using eval for dynamic names)
  local prefix=""
  [ "$env" = "prod" ] && prefix="PROD_"

  # Initialize counters using dynamic variable names
  eval "FBC_${prefix}NOT_APPLIED=0"
  eval "FBC_${prefix}IN_PROGRESS=0"
  eval "FBC_${prefix}SUCCEEDED=0"
  eval "FBC_${prefix}FAILED=0"

  # Loop through OCP versions in scope
  for ocp_version in $scope; do
    local fbc_release
    # More precise grep pattern - anchor version to avoid partial matches
    fbc_release=$(oc get release -n submariner-tenant --no-headers 2>/dev/null \
      | grep -E "submariner-fbc-4-$ocp_version-$env-[0-9]+-$version_dash-[0-9]+" | tail -1 | awk '{print $1}' || true)

    if [ -z "$fbc_release" ]; then
      eval "FBC_${prefix}NOT_APPLIED=\$((FBC_${prefix}NOT_APPLIED + 1))"
    else
      local fbc_status fbc_reason
      fbc_status=$(oc get release "$fbc_release" -n submariner-tenant \
        -o jsonpath='{.status.conditions[?(@.type=="Released")].status}' 2>/dev/null || true)
      fbc_reason=$(oc get release "$fbc_release" -n submariner-tenant \
        -o jsonpath='{.status.conditions[?(@.type=="Released")].reason}' 2>/dev/null || true)

      if [ "$fbc_status" = "True" ] && [ "$fbc_reason" = "Succeeded" ]; then
        eval "FBC_${prefix}SUCCEEDED=\$((FBC_${prefix}SUCCEEDED + 1))"
      elif [ "$fbc_reason" = "Progressing" ]; then
        eval "FBC_${prefix}IN_PROGRESS=\$((FBC_${prefix}IN_PROGRESS + 1))"
      else
        eval "FBC_${prefix}FAILED=\$((FBC_${prefix}FAILED + 1))"
      fi
    fi
  done
}

# ============================================================================
# Check Functions (one per workflow step)
# ============================================================================

# Step 1: Release Branch
check_step_1() {
  local missing_count=0
  local missing_repos=()

  for repo in $SUBMARINER_REPOS; do
    local branch_check
    branch_check=$(git ls-remote --heads "https://github.com/submariner-io/$repo" "refs/heads/release-$MAJOR_MINOR" 2>/dev/null | grep -o "refs/heads/release-$MAJOR_MINOR" || true)

    if [ -z "$branch_check" ]; then
      missing_repos+=("$repo")
      ((missing_count++))
    fi
  done

  local total_repos
  total_repos=$(count_words "$SUBMARINER_REPOS")

  if [ "$missing_count" -eq 0 ]; then
    echo "✅ release-$MAJOR_MINOR branches exist ($total_repos repos)"
  else
    echo "❌ Missing release-$MAJOR_MINOR: $missing_count/$total_repos repos"
    for repo in "${missing_repos[@]}"; do
      echo "   - $repo"
    done
    echo "   ⮕ Next: Create upstream release branches (Step 1)"
  fi

  BRANCH_CHECK=$( [ "$missing_count" -eq 0 ] && echo "all" || echo "" )
}

# Step 2: Konflux ReleasePlans
check_step_2() {
  STAGE_PLAN=$(oc get releaseplans -n submariner-tenant --no-headers 2>/dev/null | grep -E "submariner-release-plan-stage-$MAJOR_MINOR_DASH\s" | awk '{print $1}' || true)
  PROD_PLAN=$(oc get releaseplans -n submariner-tenant --no-headers 2>/dev/null | grep -E "submariner-release-plan-prod-$MAJOR_MINOR_DASH\s" | awk '{print $1}' || true)

  if [ -n "$STAGE_PLAN" ] && [ -n "$PROD_PLAN" ]; then
    echo "✅ ReleasePlans deployed"
  elif [ -n "$STAGE_PLAN" ] || [ -n "$PROD_PLAN" ]; then
    echo "⚠️  Partial: $([ -n "$STAGE_PLAN" ] && echo "stage" || echo "prod") only"
    echo "   ⮕ Next: Complete downstream configuration (Step 2)"
  else
    echo "❌ ReleasePlans not found"
    echo "   ⮕ Next: Configure downstream release (Step 2)"
  fi
}

# Step 3: Component Tekton Config
check_step_3() {
  local missing_repos=()
  local tekton_count

  for repo in submariner-operator submariner lighthouse shipyard subctl; do
    tekton_count=$(gh api "repos/submariner-io/$repo/contents/.tekton?ref=release-$MAJOR_MINOR" --jq 'length' 2>/dev/null || echo "0")

    if [ "$tekton_count" = "0" ] || ! echo "$tekton_count" | grep -qE '^[0-9]+$'; then
      missing_repos+=("$repo")
      MISSING_TEKTON=$((MISSING_TEKTON + 1))
    fi
  done

  if [ "$MISSING_TEKTON" -eq 0 ]; then
    echo "✅ All 5 repos configured"
  else
    echo "❌ Missing Tekton configs: $MISSING_TEKTON/5"
    for repo in "${missing_repos[@]}"; do
      echo "   - $repo"
    done
    echo "   ⮕ Next: Fix Tekton config PRs (Step 3)"
  fi
}

# Step 3b: Bundle Tekton Config
check_step_3b() {
  # Reuse snapshot from global scope (fetched before step checks)
  if [ -n "$SNAPSHOT" ]; then
    local bundle_in_snapshot
    bundle_in_snapshot=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant \
      -o jsonpath="{.spec.components[?(@.name==\"submariner-bundle-$MAJOR_MINOR_DASH\")].name}" 2>/dev/null || true)

    if [ -n "$bundle_in_snapshot" ]; then
      local test_status
      test_status=$(get_snapshot_test_status "$SNAPSHOT")

      if [ -n "$test_status" ]; then
        local ec_passed
        ec_passed=$(echo "$test_status" | jq -r '.[] | select(.scenario | contains("enterprise-contract")) | select(.status == "TestPassed") | .status' 2>/dev/null || true)

        if [ -n "$ec_passed" ]; then
          echo "✅ Bundle configured and passing EC"
        else
          echo "⚠️  Bundle in snapshot but EC tests failing"
          echo "   ⮕ Next: Fix bundle EC violations (Step 4)"
        fi
      else
        echo "⚠️  Bundle in snapshot, no test status"
      fi
    else
      echo "❌ Bundle not in snapshot"
      echo "   ⮕ Next: Fix bundle Tekton config (Step 3b)"
    fi
  else
    echo "⏭️  Skipped (no component snapshot)"
  fi
}

# Step 4: Enterprise Contract Validation
check_step_4() {
  if [ -z "$SNAPSHOT" ]; then
    echo "⏭️  Skipped (no snapshot)"
  else
    local test_status
    test_status=$(get_snapshot_test_status "$SNAPSHOT")

    if [ -n "$test_status" ]; then
      local ec_failed
      ec_failed=$(echo "$test_status" | jq -r '.[] | select(.scenario | contains("enterprise-contract")) | select(.status != "TestPassed") | "\(.scenario): \(.status)"' 2>/dev/null || true)

      if [ -z "$ec_failed" ]; then
        echo "✅ All EC validations passed"
      else
        echo "❌ EC violations detected:"
        echo "$ec_failed" | while IFS= read -r line; do
          echo "   - $line"
        done
        echo "   ⮕ Next: Fix EC violations (Step 4)"
      fi
    else
      echo "⚠️  No test status available"
    fi
  fi
}

# Step 5: CVE Scanning
check_step_5() {
  if [ -z "$SNAPSHOT" ]; then
    echo "⏭️  Skipped (no snapshot)"
  else
    echo "ℹ️  CVE scanning requires manual review"
    echo "   - Upstream: grype scan on release-$MAJOR_MINOR (7 repos)"
    echo "   - Downstream: Clair reports from snapshot $SNAPSHOT"
    echo "   ⮕ Next: Run CVE scans and triage results (Step 5)"
  fi
}

# Step 5b: Version Labels
check_step_5b() {
  # INCORRECT array is populated by check_version_label (not local - shared with helper)
  INCORRECT=()

  # Check all Dockerfiles
  check_version_label "submariner-operator" "package/Dockerfile.submariner-operator.konflux" "version" "v$VERSION"
  check_version_label "submariner-operator" "bundle.Dockerfile.konflux" "csv-version" "$VERSION"
  check_version_label "submariner-operator" "bundle.Dockerfile.konflux" "release" "v$VERSION"
  check_version_label "submariner-operator" "bundle.Dockerfile.konflux" "version" "v$VERSION"
  check_version_label "submariner" "package/Dockerfile.submariner-gateway.konflux" "version" "v$VERSION"
  check_version_label "submariner" "package/Dockerfile.submariner-globalnet.konflux" "version" "v$VERSION"
  check_version_label "submariner" "package/Dockerfile.submariner-route-agent.konflux" "version" "v$VERSION"
  check_version_label "lighthouse" "package/Dockerfile.lighthouse-agent.konflux" "version" "v$VERSION"
  check_version_label "lighthouse" "package/Dockerfile.lighthouse-coredns.konflux" "version" "v$VERSION"
  check_version_label "shipyard" "package/Dockerfile.nettest.konflux" "version" "v$VERSION"
  check_version_label "subctl" "package/Dockerfile.subctl.konflux" "version" "v$VERSION"

  WRONG_COUNT=${#INCORRECT[@]}
  if [ "$WRONG_COUNT" -eq 0 ]; then
    echo "✅ All 9 Dockerfiles (11 version labels) correct"
  else
    echo "❌ $WRONG_COUNT version label(s) need update:"
    for f in "${INCORRECT[@]}"; do
      echo "   - $f"
    done
    echo "   ⮕ Next: Update version labels (Step 5b)"
  fi
}

# Step 6: Upstream Release
check_step_6() {
  TAG_EXISTS=$(gh api repos/submariner-io/submariner-operator/tags \
    --jq ".[] | select(.name == \"v$VERSION\") | .name" 2>/dev/null || true)

  if [ -n "$TAG_EXISTS" ]; then
    # Get tag object URL, fetch tag details, extract date
    local tag_date
    tag_date=$(gh api "repos/submariner-io/submariner-operator/git/refs/tags/v$VERSION" \
      --jq '.object.url' 2>/dev/null | xargs gh api 2>/dev/null | jq -r '.tagger.date // .committer.date' || true)
    if [ -n "$tag_date" ]; then
      local formatted_date
      formatted_date=$(format_date "$tag_date" '%Y-%m-%d %H:%M UTC')
      echo "✅ v$VERSION tag exists (created $formatted_date)"
    else
      echo "✅ v$VERSION tag exists"
    fi
  else
    echo "❌ v$VERSION tag not found"
    echo "   ⮕ Next: Create upstream release (Step 6)"
  fi
}

# Step 7: Component Snapshots and Bundle SHAs
check_step_7() {
  # Reuse snapshot from global scope (fetched before step checks)
  if [ -z "$SNAPSHOT" ]; then
    echo "❌ No component snapshots found"
    echo "   ⮕ Next: Fix version labels, wait for rebuild"
  else
    local snapshot_age formatted_age
    snapshot_age=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)
    if [ -n "$snapshot_age" ]; then
      formatted_age=$(format_date "$snapshot_age")
      echo "📸 Latest: $SNAPSHOT ($formatted_age)"
    else
      echo "📸 Latest: $SNAPSHOT"
    fi

    local test_status
    test_status=$(get_snapshot_test_status "$SNAPSHOT")

    if [ -n "$test_status" ]; then
      local all_passed total_tests
      all_passed=$(echo "$test_status" | jq '[.[] | select(.status == "TestPassed")] | length' 2>/dev/null || echo 0)
      total_tests=$(echo "$test_status" | jq '. | length' 2>/dev/null || echo 0)

      if [ "$all_passed" -eq "$total_tests" ] && [ "$total_tests" -gt 0 ]; then
        echo "   ✅ All tests passed ($all_passed/$total_tests)"

        local image
        image=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant \
          -o jsonpath="{.spec.components[?(@.name==\"lighthouse-agent-$MAJOR_MINOR_DASH\")].containerImage}" 2>/dev/null || true)

        if [ -n "$image" ]; then
          IMAGE_VERSION=$(skopeo inspect "docker://$image" 2>/dev/null | jq -r '.Labels.version' 2>/dev/null || true)
          IMAGE_VERSION_FETCHED=true
          if [ "$IMAGE_VERSION" = "v$VERSION" ]; then
            echo "   ✅ Image labels: v$VERSION"
          else
            echo "   ⚠️  Image labels: $IMAGE_VERSION (expected v$VERSION)"
            echo "      Snapshot built before label update - needs rebuild"
            echo "   ⮕ Next: Wait for rebuild after version label PRs merge (~15-30 min)"
          fi
        fi
      else
        echo "   ❌ Tests: $all_passed/$total_tests passed"
        echo "   ⮕ Next: Fix test failures"
      fi
    else
      echo "   ⚠️  No test status available"
    fi
  fi

  echo ""
  echo "[Step 7] Bundle SHAs"

  # For completed releases: check bundle against snapshot in release YAML
  # For pre-release: check bundle against latest snapshot
  local release_snapshot=""
  if [ -n "$STAGE_YAML" ]; then
    release_snapshot=$(awk '/^  snapshot:/ {print $2}' "$STAGE_YAML" 2>/dev/null || true)
  fi

  # Use release snapshot if exists, otherwise latest
  local check_snapshot="${release_snapshot:-$SNAPSHOT}"

  if [ -n "$check_snapshot" ]; then
    local snapshot_time
    snapshot_time=$(oc get snapshot "$check_snapshot" -n submariner-tenant -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)

    if [ -n "$snapshot_time" ]; then
      local snapshot_epoch
      snapshot_epoch=$(date -d "$snapshot_time" +%s 2>/dev/null || echo 0)

      # Get bundle CSV last commit time
      local bundle_csv_date
      bundle_csv_date=$(gh api "repos/submariner-io/submariner-operator/commits?path=bundle/manifests/submariner.clusterserviceversion.yaml&sha=release-$MAJOR_MINOR" \
        --jq '.[0].commit.committer.date' 2>/dev/null || true)

      if [ -n "$bundle_csv_date" ] && [ "$snapshot_epoch" -gt 0 ]; then
        local bundle_epoch time_diff
        bundle_epoch=$(date -d "$bundle_csv_date" +%s 2>/dev/null || echo 0)

        # Bundle should be updated AFTER snapshot (allow small clock skew)
        time_diff=$((bundle_epoch - snapshot_epoch))
        if [ "$time_diff" -ge "-$BUNDLE_CLOCK_SKEW_SECS" ]; then
          local formatted_bundle_date
          formatted_bundle_date=$(format_date "$bundle_csv_date")
          if [ -n "$release_snapshot" ]; then
            echo "✅ Bundle matches release ($formatted_bundle_date)"
          else
            echo "✅ Bundle updated ($formatted_bundle_date)"
          fi
        else
          local formatted_bundle_date
          formatted_bundle_date=$(format_date "$bundle_csv_date" '%Y-%m-%d')
          echo "❌ Bundle outdated ($formatted_bundle_date, older than snapshot)"
          echo "   ⮕ Next: Update bundle SHAs (Step 7)"
        fi
      else
        echo "⚠️  Cannot verify bundle age"
      fi
    else
      echo "⚠️  Cannot get snapshot timestamp"
    fi
  else
    echo "⏭️  Skipped (no snapshot)"
  fi
}

# Step 8-10: Component Stage Release
check_step_8_10() {
  if [ -z "$STAGE_YAML" ]; then
    echo "❌ No stage release YAML"
    echo "   ⮕ Next: Create stage release (Step 8)"
  else
    echo "📄 Stage YAML: $(basename "$STAGE_YAML")"

    # Check if release notes present (Step 9)
    if grep -q "releaseNotes:" "$STAGE_YAML" 2>/dev/null; then
      echo "   ✅ Release notes present"
    else
      echo "   ⚠️  No release notes"
      echo "   ⮕ Next: Add release notes (Step 9)"
    fi

    # Check if applied to cluster (Step 10)
    local release_name
    release_name=$(awk '/^  name:/ {print $2}' "$STAGE_YAML" 2>/dev/null || true)
    check_component_release_status "$release_name" "stage (Step 10)"
  fi
}

# Step 10b: Check Stage Build
check_step_10b() {
  echo "⏭️  Skipped (status in Step 8-10)"
}

# Step 11: FBC Catalog Update
check_step_11() {
  # State-aware snapshot selection:
  # - Complete: Use historical snapshots (from YAMLs matched by date)
  # - In-progress: Use latest snapshots (current cluster state)
  FBC_MISSING=0
  FBC_FAILED=0

  # Get component YAML date for historical matching (completed releases only)
  local component_date=""
  if [ "$RELEASE_STATE" = "complete" ]; then
    component_date=$(get_component_yaml_date "stage")
  fi

  for ocp_version in $OCP_VERSIONS; do
    local fbc_snapshot=""

    # State-aware snapshot selection
    if [ "$RELEASE_STATE" = "complete" ] && [ -n "$component_date" ]; then
      # For completed releases: match FBC YAML by date proximity to component release
      local fbc_yaml
      fbc_yaml=$(find_fbc_yaml_by_date "$ocp_version" "stage" "$component_date")

      if [ -n "$fbc_yaml" ]; then
        fbc_snapshot=$(awk '/^  snapshot:/ {print $2}' "$fbc_yaml" 2>/dev/null || true)
      fi
    else
      # For in-progress or not-started: use latest snapshot (current verification)
      fbc_snapshot=$(oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp 2>/dev/null \
        | grep "^submariner-fbc-4-$ocp_version" | tail -1 | awk '{print $1}' || true)
    fi

    if [ -z "$fbc_snapshot" ]; then
      if [ "$FBC_MISSING" -eq 0 ]; then
        if [ "$RELEASE_STATE" = "complete" ]; then
          echo "ℹ️  OCP versions not supported at release time:"
        else
          echo "❌ Missing FBC snapshots:"
        fi
      fi
      echo "   - OCP 4.$ocp_version"
      FBC_MISSING=$((FBC_MISSING + 1))
    else
      # Check test status
      local fbc_test_status
      fbc_test_status=$(get_snapshot_test_status "$fbc_snapshot")

      if [ -n "$fbc_test_status" ]; then
        local fbc_all_passed fbc_total
        fbc_all_passed=$(echo "$fbc_test_status" | jq '[.[] | select(.status == "TestPassed")] | length' 2>/dev/null || echo 0)
        fbc_total=$(echo "$fbc_test_status" | jq '. | length' 2>/dev/null || echo 0)

        if [ "$fbc_all_passed" -ne "$fbc_total" ] || [ "$fbc_total" -eq 0 ]; then
          if [ "$FBC_FAILED" -eq 0 ]; then
            echo "❌ FBC snapshots with test failures:"
          fi
          echo "   - OCP 4.$ocp_version: $fbc_all_passed/$fbc_total passed"
          FBC_FAILED=$((FBC_FAILED + 1))
        fi
      fi
    fi
  done

  # State-aware reporting
  if [ "$RELEASE_STATE" = "complete" ]; then
    # Completed releases: show historical verification results
    if [ "$FBC_MISSING" -eq 0 ] && [ "$FBC_FAILED" -eq 0 ]; then
      echo "✅ All FBC stage releases succeeded (verified in catalog)"
    elif [ "$FBC_FAILED" -gt 0 ]; then
      echo "⚠️  FBC stage snapshots had test failures at release time"
      echo "   ℹ️  Note: Current FBC snapshots may differ (release is complete)"
    fi
    # Don't show warning for missing OCP versions - already reported above with ℹ️
  else
    # In-progress or not-started: show current verification with actionable next steps
    if [ "$FBC_MISSING" -eq 0 ] && [ "$FBC_FAILED" -eq 0 ]; then
      echo "✅ All FBC snapshots ready (OCP 4.16-4.21)"
    else
      if [ "$FBC_FAILED" -gt 0 ]; then
        echo "   ⮕ Next: Fix FBC tests and wait for rebuild"
      else
        echo "   ⮕ Next: Update FBC catalog (Step 11)"
      fi
    fi
  fi
}

# Step 12-13: FBC Stage Releases
check_step_12_13() {
  # FBC releases follow component releases - check if component release exists first
  if [ -z "$STAGE_YAML" ]; then
    echo "ℹ️  Not released via Konflux (no component release)"
    echo "   FBC releases follow component releases"
    # Initialize counters for summary section
    FBC_NOT_APPLIED=0
    FBC_IN_PROGRESS=0
    FBC_SUCCEEDED=0
    FBC_FAILED=0
    return
  fi

  # Get OCP version scope for this release (inferred from YAMLs created near component release)
  local scope_stage
  scope_stage=$(get_release_ocp_scope "stage")
  FBC_STAGE_YAML_COUNT=$(count_words "$scope_stage")

  if [ "$FBC_STAGE_YAML_COUNT" -eq 0 ]; then
    echo "❌ No FBC stage YAMLs"
    echo "   ⮕ Next: Create FBC stage releases (Step 12)"
    # Initialize counters for summary section
    FBC_NOT_APPLIED=0
    FBC_IN_PROGRESS=0
    FBC_SUCCEEDED=0
    FBC_FAILED=0
    return
  fi

  # Report scope with context about OCP versions
  report_fbc_scope "stage" "$FBC_STAGE_YAML_COUNT" "$scope_stage" "12"

  # Check cluster status using helper function (only check versions in scope)
  check_fbc_release_status "stage" "$FULL_VERSION_DASH" "$scope_stage"

  # Report status (conditional based on release state)
  if [ "$RELEASE_STATE" = "complete" ]; then
    # For completed releases, only show actual state without "Next" suggestions
    if [ "$FBC_SUCCEEDED" -gt 0 ]; then
      echo "   ✅ Releases succeeded: $FBC_SUCCEEDED/$FBC_STAGE_YAML_COUNT"
    elif [ "$FBC_NOT_APPLIED" -gt 0 ]; then
      echo "   ℹ️  Not on cluster: $FBC_NOT_APPLIED/$FBC_STAGE_YAML_COUNT (may be deleted)"
    fi
  else
    # For in-progress releases, report blockers with "Next" steps
    if [ "$FBC_SUCCEEDED" -eq "$FBC_STAGE_YAML_COUNT" ]; then
      echo "   ✅ All releases succeeded ($FBC_SUCCEEDED/$FBC_STAGE_YAML_COUNT)"
    elif [ "$FBC_NOT_APPLIED" -gt 0 ]; then
      echo "   ⏳ Not applied: $FBC_NOT_APPLIED/$FBC_STAGE_YAML_COUNT"
      echo "   ⮕ Next: Apply FBC stage releases (Step 13)"
    elif [ "$FBC_IN_PROGRESS" -gt 0 ]; then
      echo "   🔄 In progress: $FBC_IN_PROGRESS/$FBC_STAGE_YAML_COUNT"
    elif [ "$FBC_FAILED" -gt 0 ]; then
      echo "   ❌ Failed: $FBC_FAILED/$FBC_STAGE_YAML_COUNT"
      echo "   ⮕ Next: Debug failures (Step 13b)"
    fi
  fi
}

# Step 13b: Check FBC Stage
check_step_13b() {
  echo "⏭️  Skipped (status in Step 12-13)"
}

# Step 14: QE Approval
check_step_14() {
  echo "⏸️  Manual checkpoint"
  echo "   ⮕ Next: Share with QE, wait for approval"
}

# Step 15-16: Component Prod Release
check_step_15_16() {
  if [ -z "$PROD_YAML" ]; then
    echo "❌ No prod release YAML"
    echo "   ⮕ Next: Create prod release (Step 15)"
  else
    echo "📄 Prod YAML: $(basename "$PROD_YAML")"

    # Check if applied to cluster (Step 16)
    local prod_release_name
    prod_release_name=$(awk '/^  name:/ {print $2}' "$PROD_YAML" 2>/dev/null || true)
    check_component_release_status "$prod_release_name" "prod (Step 16)"
  fi
}

# Step 16b: Check Prod Build
check_step_16b() {
  echo "⏭️  Skipped (status in Step 15-16)"
}

# Step 17-18: FBC Prod Releases
check_step_17_18() {
  # FBC releases follow component releases - check if component release exists first
  if [ -z "$PROD_YAML" ]; then
    echo "ℹ️  Not released via Konflux (no component release)"
    echo "   FBC releases follow component releases"
    # Initialize counters for summary section
    FBC_PROD_NOT_APPLIED=0
    FBC_PROD_IN_PROGRESS=0
    FBC_PROD_SUCCEEDED=0
    FBC_PROD_FAILED=0
    return
  fi

  # Get OCP version scope for this release (inferred from YAMLs created near component release)
  local scope_prod
  scope_prod=$(get_release_ocp_scope "prod")
  FBC_PROD_YAML_COUNT=$(count_words "$scope_prod")

  if [ "$FBC_PROD_YAML_COUNT" -eq 0 ]; then
    echo "❌ No FBC prod YAMLs"
    echo "   ⮕ Next: Create FBC prod releases (Step 17)"
    # Initialize counters for summary section
    FBC_PROD_NOT_APPLIED=0
    FBC_PROD_IN_PROGRESS=0
    FBC_PROD_SUCCEEDED=0
    FBC_PROD_FAILED=0
    return
  fi

  # Report scope with context about OCP versions
  report_fbc_scope "prod" "$FBC_PROD_YAML_COUNT" "$scope_prod" "17"

  # Check cluster status using helper function (only check versions in scope)
  check_fbc_release_status "prod" "$FULL_VERSION_DASH" "$scope_prod"

  # Report status (conditional based on release state)
  if [ "$RELEASE_STATE" = "complete" ]; then
    # For completed releases, only show actual state without "Next" suggestions
    if [ "$FBC_PROD_SUCCEEDED" -gt 0 ]; then
      echo "   ✅ Releases succeeded: $FBC_PROD_SUCCEEDED/$FBC_PROD_YAML_COUNT"
      [ "$FBC_PROD_SUCCEEDED" -eq "$FBC_PROD_YAML_COUNT" ] && echo "   🎉 Release complete!"
    elif [ "$FBC_PROD_NOT_APPLIED" -gt 0 ]; then
      echo "   ℹ️  Not on cluster: $FBC_PROD_NOT_APPLIED/$FBC_PROD_YAML_COUNT (may be deleted)"
    fi
  else
    # For in-progress releases, report blockers with "Next" steps
    if [ "$FBC_PROD_SUCCEEDED" -eq "$FBC_PROD_YAML_COUNT" ]; then
      echo "   ✅ All releases succeeded ($FBC_PROD_SUCCEEDED/$FBC_PROD_YAML_COUNT)"
      echo "   🎉 Release complete!"
    elif [ "$FBC_PROD_NOT_APPLIED" -gt 0 ]; then
      echo "   ⏳ Not applied: $FBC_PROD_NOT_APPLIED/$FBC_PROD_YAML_COUNT"
      echo "   ⮕ Next: Apply FBC prod releases (Step 18)"
    elif [ "$FBC_PROD_IN_PROGRESS" -gt 0 ]; then
      echo "   🔄 In progress: $FBC_PROD_IN_PROGRESS/$FBC_PROD_YAML_COUNT"
    elif [ "$FBC_PROD_FAILED" -gt 0 ]; then
      echo "   ❌ Failed: $FBC_PROD_FAILED/$FBC_PROD_YAML_COUNT"
      echo "   ⮕ Next: Debug failures (Step 18b)"
    fi
  fi
}

# Step 18b: Check FBC Prod
check_step_18b() {
  echo "⏭️  Skipped (status in Step 17-18)"
}

# Step 19: Share Prod with QE
check_step_19() {
  echo "ℹ️  Manual step - share prod URLs with QE"
}

# Step 20: Update FBC Templates
check_step_20() {
  echo "ℹ️  Optional - update FBC templates with prod URLs"
}

# ============================================================================
# Main Execution
# ============================================================================

# Header
echo "=== Submariner $VERSION Release Status ==="
echo ""

# ============================================================================
# Initialize Global Variables
# ============================================================================

# Fetch latest component snapshot once for Steps 3b-7 (optimization)
SNAPSHOT=$(oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp 2>/dev/null \
  | grep "^submariner-$MAJOR_MINOR_DASH" | tail -1 | awk '{print $1}' || true)

# Find release YAMLs once (used across multiple steps and phase detection)
STAGE_YAML=$(find "releases/$MAJOR_MINOR/stage/" -name "submariner-$FULL_VERSION_DASH-stage-*.yaml" 2>/dev/null | tail -1 || true)
PROD_YAML=$(find "releases/$MAJOR_MINOR/prod/" -name "submariner-$FULL_VERSION_DASH-prod-*.yaml" 2>/dev/null | tail -1 || true)

# Step check results (used across multiple steps and phase detection)
BRANCH_CHECK=""              # Step 1: Branch existence check
STAGE_PLAN=""                # Step 2: Stage ReleasePlan
PROD_PLAN=""                 # Step 2: Prod ReleasePlan
MISSING_TEKTON=0             # Step 3: Missing Tekton configs count
TAG_EXISTS=""                # Step 6: Upstream tag existence
WRONG_COUNT=0                # Step 5b: Incorrect version labels count
IMAGE_VERSION=""             # Step 7: Container image version label
IMAGE_VERSION_FETCHED=false  # Step 7: Whether IMAGE_VERSION was fetched

# FBC counters (set by check_fbc_release_status, used in phase detection)
FBC_NOT_APPLIED=0
FBC_IN_PROGRESS=0
FBC_SUCCEEDED=0
FBC_FAILED=0
FBC_PROD_NOT_APPLIED=0
FBC_PROD_IN_PROGRESS=0
FBC_PROD_SUCCEEDED=0
FBC_PROD_FAILED=0
FBC_STAGE_YAML_COUNT=0       # Step 12-13: Number of stage FBC YAMLs
FBC_PROD_YAML_COUNT=0        # Step 17-18: Number of prod FBC YAMLs

# Detect release state (complete/in-progress/not-started) for conditional reporting
RELEASE_STATE=$(detect_release_state)

# Main loop: Iterate through steps
CURRENT_PHASE=""

for step_def in "${RELEASE_STEPS[@]}"; do
  step_num=$(get_step_field "$step_def" 1)
  step_name=$(get_step_field "$step_def" 2)
  step_phase=$(get_step_field "$step_def" 3)
  step_stream=$(get_step_field "$step_def" 4)
  step_check_nums=$(get_step_field "$step_def" 6)

  # Print phase header when phase changes
  if [ "$step_phase" != "$CURRENT_PHASE" ]; then
    CURRENT_PHASE="$step_phase"
    echo "━━━ ${PHASE_NAMES[$step_phase]} ━━━"
    echo ""
  fi

  # Print step header
  display_num="$step_num"
  [ -n "$step_check_nums" ] && display_num="$step_check_nums"
  echo "[Step $display_num] $step_name"

  # Check if step applies to current stream
  if ! step_applies_to_stream "$step_stream" "$IS_ZSTREAM"; then
    stream_name=$([ "$step_stream" = "Y" ] && echo "Y-stream" || echo "Z-stream")
    echo "⏭️  N/A ($stream_name only)"
    echo ""
    continue
  fi

  # Call check function
  check_step_${step_num}

  echo ""
done

# Summary
echo "━━━ SUMMARY ━━━"
echo ""

if [ "$IS_ZSTREAM" = "true" ]; then
  BASE_VERSION=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
  echo "Release Type: Z-stream ($BASE_VERSION → $VERSION)"
else
  # Y-stream: handle both X.Y and X.Y.0 formats
  if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    # Already has patch version (X.Y.0)
    echo "Release Type: Y-stream ($VERSION)"
  else
    # Just X.Y format
    echo "Release Type: Y-stream ($VERSION.0)"
  fi
fi

# Determine current phase and next steps
CURRENT_PHASE=$(detect_current_phase)

case "$CURRENT_PHASE" in
  not-started)
    echo "Current Phase: Not Started"
    echo "Status: No release artifacts found for $VERSION"
    echo ""
    echo "ℹ️  This version was not released via Konflux"
    echo ""
    echo "NEXT STEPS:"
    if [ "$IS_ZSTREAM" = "false" ]; then
      echo "1. [Step 1] Create release-$MAJOR_MINOR branches (for Y-stream $VERSION.0)"
      echo "2. [Step 2] Configure Konflux ReleasePlans"
    else
      echo "1. [Step 5b] Update version labels in Dockerfiles"
      echo "2. [Step 6] Cut upstream release tag v$VERSION"
    fi
    ;;

  upstream-prep)
    if [ -z "$BRANCH_CHECK" ]; then
      echo "Current Phase: Branch Setup"
      echo "Blocking: Release branch not created"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 1] Create release-$MAJOR_MINOR branches in all repos"
    elif [ -z "$STAGE_PLAN" ] || [ -z "$PROD_PLAN" ]; then
      echo "Current Phase: Downstream Configuration"
      if [ -z "$STAGE_PLAN" ] && [ -z "$PROD_PLAN" ]; then
        echo "Blocking: ReleasePlans not configured"
      elif [ -z "$STAGE_PLAN" ]; then
        echo "Blocking: Stage ReleasePlan missing"
      else
        echo "Blocking: Prod ReleasePlan missing"
      fi
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 2] Configure Konflux ReleasePlans"
    fi
    ;;

  component-prep)
    echo "Current Phase: Tekton Configuration"
    echo "Blocking: Component Tekton configs not set up"
    echo ""
    echo "NEXT STEPS:"
    echo "1. [Step 3] Fix Tekton config PRs for components"
    ;;

  upstream-release)
    if [ -z "$TAG_EXISTS" ]; then
      echo "Current Phase: Upstream Release"
      echo "Blocking: Upstream tag not created"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 6] Create upstream release (cut tag v$VERSION)"
    elif [ "$WRONG_COUNT" -gt 0 ]; then
      echo "Current Phase: Build Preparation"
      echo "Blocking: Version labels not updated"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 5b] Update $WRONG_COUNT Dockerfile version labels"
      echo "2. [Wait] Snapshot rebuild (~15-30 min after PRs merge)"
      echo "3. [Step 7] Update bundle SHAs"
    elif [ -z "$SNAPSHOT" ]; then
      echo "Current Phase: Build Preparation"
      echo "Blocking: No snapshots found"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Check] Verify builds are running"
      echo "2. [Wait] Wait for first snapshot (~15-30 min)"
    else
      # Reuse IMAGE_VERSION from test verification if available, otherwise fetch
      if [ "$IMAGE_VERSION_FETCHED" != "true" ]; then
        image=$(oc get snapshot "$SNAPSHOT" -n submariner-tenant \
          -o jsonpath="{.spec.components[?(@.name==\"lighthouse-agent-$MAJOR_MINOR_DASH\")].containerImage}" 2>/dev/null || true)
        if [ -n "$image" ]; then
          IMAGE_VERSION=$(skopeo inspect "docker://$image" 2>/dev/null | jq -r '.Labels.version' 2>/dev/null || true)
        fi
      fi

      echo "Current Phase: Build Preparation"
      echo "Blocking: Waiting for snapshot rebuild"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Wait] Snapshot rebuild in progress"
      echo "2. [Step 7] Update bundle SHAs after rebuild"
    fi
    ;;

  component-stage)
    echo "Current Phase: Stage Preparation"
    echo "Blocking: Ready for stage release"
    echo ""
    echo "NEXT STEPS:"
    echo "1. [Step 7] Update bundle SHAs with latest snapshot"
    echo "2. [Step 8] Create stage release YAML"
    ;;

  fbc-stage)
    if [ "$FBC_STAGE_YAML_COUNT" -eq 0 ]; then
      echo "Current Phase: Stage Release"
      echo "Blocking: Component stage in progress or complete"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 11] Update FBC catalog with stage bundle"
      echo "2. [Step 12] Create FBC stage releases (6 OCP versions)"
    else
      echo "Current Phase: Stage Release"
      echo "Blocking: FBC stage releases incomplete"
      echo ""
      echo "NEXT STEPS:"
      echo "1. [Step 13] Apply/monitor FBC stage releases"
      echo "2. [Step 14] Share with QE for approval"
    fi
    ;;

  qe-approval)
    echo "Current Phase: QE Approval"
    echo "Blocking: Awaiting QE approval"
    echo ""
    echo "NEXT STEPS:"
    echo "1. [Step 14] Share stage with QE"
    echo "2. [Step 15] Create prod release after QE approval"
    ;;

  component-prod)
    echo "Current Phase: Production Release"
    echo "Blocking: Component prod in progress or complete"
    echo ""
    echo "NEXT STEPS:"
    echo "1. [Step 17] Create FBC prod releases (6 OCP versions)"
    echo "2. [Step 18] Apply FBC prod releases"
    ;;

  fbc-prod)
    echo "Current Phase: Production Release"
    echo "Blocking: FBC prod releases incomplete"
    echo ""
    echo "NEXT STEPS:"
    echo "1. [Step 18] Apply/monitor FBC prod releases"
    echo "2. [Step 19] Share with QE when complete"
    ;;

  complete)
    echo "Current Phase: Complete"
    echo "Status: ✅ Release $VERSION deployed to production"
    echo ""

    # Show what was released (use prod scope, fall back to stage if no prod YAMLs)
    prod_scope=$(get_release_ocp_scope "prod")
    prod_count=$(count_words "$prod_scope")

    # If no prod FBC YAMLs, check stage (release might have completed before FBC was added)
    if [ "$prod_count" -eq 0 ]; then
      stage_scope=$(get_release_ocp_scope "stage")
      stage_count=$(count_words "$stage_scope")
      if [ "$stage_count" -gt 0 ]; then
        echo "RELEASED:"
        echo "- Component: submariner-$VERSION"
        echo "- FBC catalogs: $stage_count stage only (OCP 4-$stage_scope)"
        echo ""
        echo "ℹ️  No prod FBC releases found (release may predate FBC workflow)"
      else
        echo "RELEASED:"
        echo "- Component: submariner-$VERSION"
        echo "- FBC catalogs: None found"
      fi
    else
      echo "RELEASED:"
      echo "- Component: submariner-$VERSION"
      echo "- FBC catalogs: $prod_count (OCP 4-$prod_scope)"

      # Note if OCP versions were added since this release
      if [ "$prod_count" -lt "$CURRENT_OCP_VERSION_COUNT" ]; then
        missing_versions=$(get_missing_ocp_versions "$prod_scope")
        if [ -n "$missing_versions" ]; then
          echo ""
          echo "ℹ️  OCP 4-$missing_versions support added after this release"
        fi
      fi
    fi
    ;;

  *)
    echo "Current Phase: Unknown"
    echo "Status: Unable to determine release phase"
    ;;
esac
