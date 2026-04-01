#!/bin/bash
# Shared library for release notes workflow
# Used by: collect.sh, prepare.sh, apply.sh
set -euo pipefail

# ============================================================================
# ACM Version Calculation
# ============================================================================
# Maps Submariner version to ACM version: 0.X → 2.(X-7).0
# Sets global variables: VERSION_MAJOR_MINOR, VERSION_MAJOR_MINOR_DASH, ACM_VERSION
# Requires: VERSION variable set by caller
calculate_acm_version() {
  # Extract version components (e.g., "0.23.1" → "0.23")
  VERSION_MAJOR_MINOR=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
  VERSION_MAJOR_MINOR_DASH="${VERSION_MAJOR_MINOR//./-}"

  # Submariner 0.X → ACM 2.(X-7)
  local MINOR_VERSION
  MINOR_VERSION=$(echo "$VERSION_MAJOR_MINOR" | cut -d. -f2)
  local ACM_MINOR=$((MINOR_VERSION - 7))

  if [ $ACM_MINOR -lt 0 ]; then
    echo "❌ ERROR: Cannot calculate ACM version for Submariner '$VERSION_MAJOR_MINOR'" >&2
    return 1
  fi

  # Always use base ACM version (not patch)
  ACM_VERSION="ACM 2.${ACM_MINOR}.0"
}

# ============================================================================
# Component Name Mapping
# ============================================================================
# Maps Jira pscomponent label to Konflux component name
# Args: $1=pscomponent (e.g., rhacm2/submariner-operator-rhel9)
#       $2=version-dash (e.g., 0-22)
# Returns: component-name (e.g., submariner-operator-0-22)
#          "EXCLUDE" for submariner-addon (built separately)
#          "UNKNOWN" for unrecognized components
map_component_name() {
  local PSCOMPONENT="$1"
  local VERSION_DASH="$2"

  case "$PSCOMPONENT" in
    "rhacm2/lighthouse-coredns-rhel9"|"lighthouse-coredns-container")
      echo "lighthouse-coredns-${VERSION_DASH}"
      ;;
    "rhacm2/lighthouse-agent-rhel9"|"lighthouse-agent-container")
      echo "lighthouse-agent-${VERSION_DASH}"
      ;;
    "rhacm2/submariner-addon-rhel9")
      echo "EXCLUDE"  # Built separately in ACM/MCE - don't include
      ;;
    "rhacm2/submariner-"*"-rhel9"|"submariner-"*"-container")
      # Extract component name (e.g., submariner-route-agent from rhacm2/submariner-route-agent-rhel9)
      # Remove rhacm2/ prefix and -rhel9/-container suffix
      local COMP
      COMP=$(echo "$PSCOMPONENT" | sed -E 's/^(rhacm2\/)?(.+)-(rhel9|container)$/\2/')
      echo "${COMP}-${VERSION_DASH}"
      ;;
    "nettest-container"|"rhacm2/nettest-rhel9")
      echo "nettest-${VERSION_DASH}"
      ;;
    "subctl-container"|"rhacm2/subctl-rhel9")
      echo "subctl-${VERSION_DASH}"
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

# ============================================================================
# Stage YAML Discovery
# ============================================================================
# Finds latest stage YAML for given version
# Args: $1=version (e.g., 0.22.1)
#       $2=stage_yaml_override (optional path to specific YAML)
# Returns: Sets STAGE_YAML global variable
# Exits: 1 if YAML not found
find_stage_yaml() {
  local VERSION="$1"
  local STAGE_YAML_ARG="$2"

  # Extract version components (e.g., "0.23.1" → "0.23", "0-23-1")
  local VERSION_MAJOR_MINOR
  VERSION_MAJOR_MINOR=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
  local VERSION_FULL_DASH="${VERSION//./-}"

  # Find git repository root
  local GIT_ROOT
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$GIT_ROOT" ]; then
    echo "❌ ERROR: Not in a git repository" >&2
    return 1
  fi

  # Find or verify stage YAML
  if [ -n "$STAGE_YAML_ARG" ]; then
    STAGE_YAML="$STAGE_YAML_ARG"
    if [ ! -f "$STAGE_YAML" ]; then
      echo "❌ ERROR: Stage YAML not found: '$STAGE_YAML'" >&2
      return 1
    fi
  else
    # Find latest stage YAML for this version
    local STAGE_DIR="$GIT_ROOT/releases/$VERSION_MAJOR_MINOR/stage"

    if [ ! -d "$STAGE_DIR" ]; then
      echo "❌ ERROR: Stage directory not found: '$STAGE_DIR'" >&2
      echo "" >&2
      echo "Possible causes:" >&2
      echo "  - Step 8 not complete (create-component-release not run)" >&2
      echo "" >&2
      echo "Run: /create-component-release $VERSION" >&2
      return 1
    fi

    STAGE_YAML=$(find "$STAGE_DIR" -name "submariner-${VERSION_FULL_DASH}-stage-*.yaml" -type f | sort | tail -1)

    if [ -z "$STAGE_YAML" ] || [ ! -f "$STAGE_YAML" ]; then
      echo "❌ ERROR: No stage YAML found for version '$VERSION'" >&2
      echo "Expected: $STAGE_DIR/submariner-${VERSION_FULL_DASH}-stage-*.yaml" >&2
      echo "" >&2
      echo "Run: /create-component-release $VERSION" >&2
      return 1
    fi
  fi
}

# ============================================================================
# Jira Query with Retry
# ============================================================================
# Wrapper for acli jira workitem search with retry logic
# Args: $@=all arguments passed to acli (typically --jql "...")
# Returns: JSON array from acli (stdout)
# Exits: 1 if both attempts fail
query_jira() {
  local OUTPUT
  local RETRY=0

  while [ $RETRY -lt 2 ]; do
    if OUTPUT=$(acli jira workitem search "$@" --paginate --json </dev/null 2>&1); then
      echo "$OUTPUT"
      return 0
    fi

    : $((RETRY++))
    if [ $RETRY -lt 2 ]; then
      echo "⚠️  Jira query failed, retrying..." >&2
      sleep 2
    fi
  done

  echo "❌ ERROR: Jira query failed after 2 attempts" >&2
  echo "$OUTPUT" >&2
  return 1
}

# ============================================================================
# Jira Issue View with Retry
# ============================================================================
# Wrapper for acli jira workitem view with retry logic
# Args: $1=issue_key, $@=additional arguments (e.g., --fields "...")
# Returns: JSON object from acli (stdout)
# Exits: 1 if both attempts fail
view_jira() {
  local ISSUE_KEY="$1"
  shift
  local OUTPUT
  local RETRY=0

  while [ $RETRY -lt 2 ]; do
    if OUTPUT=$(acli jira workitem view "$ISSUE_KEY" "$@" --json </dev/null 2>&1); then
      echo "$OUTPUT"
      return 0
    fi

    : $((RETRY++))
    if [ $RETRY -lt 2 ]; then
      echo "⚠️  Jira view failed for $ISSUE_KEY, retrying..." >&2
      sleep 2
    fi
  done

  echo "❌ ERROR: Jira view failed for '$ISSUE_KEY' after 2 attempts" >&2
  echo "$OUTPUT" >&2
  return 1
}
