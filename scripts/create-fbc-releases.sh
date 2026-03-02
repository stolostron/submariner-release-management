#!/bin/bash
# Create FBC releases for all OCP versions (stage or prod)
#
# Usage: create-fbc-releases.sh <version> [--stage|--prod]
#
# Arguments:
#   version: Submariner version (e.g., 0.22.1 or 0.22)
#   --stage/--prod: Release type (default: stage)
#
# Exit codes:
#   0: Success (releases created and committed)
#   1: Failure (prerequisites, validation, or commit failed)

set -euo pipefail

# Global variables (set by parse_arguments)
VERSION=""
RELEASE_TYPE="stage"
GIT_ROOT=""
SCRIPTS_DIR=""
RELEASES_DIR=""

# Global variables (set by verify_release)
declare -A SNAPSHOTS

# Global variables (set by generate_yamls)
declare -a CREATED_FILES

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
  local MISSING_TOOLS=()

  command -v oc &>/dev/null || MISSING_TOOLS+=("oc")
  command -v jq &>/dev/null || MISSING_TOOLS+=("jq")
  command -v curl &>/dev/null || MISSING_TOOLS+=("curl")
  command -v git &>/dev/null || MISSING_TOOLS+=("git")

  if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "❌ ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "Installation instructions:"
    for tool in "${MISSING_TOOLS[@]}"; do
      case "$tool" in
        oc) echo "  oc: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html" ;;
        jq) echo "  jq: https://jqlang.github.io/jq/download/" ;;
        curl) echo "  curl: included in most systems" ;;
        git) echo "  git: https://git-scm.com/downloads" ;;
      esac
    done
    exit 1
  fi

  # Check bash version
  local BASH_MAJOR
  BASH_MAJOR=$(bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)
  if [ -z "$BASH_MAJOR" ]; then
    BASH_MAJOR=$(bash --version 2>/dev/null | head -1 | sed -nE 's/.*version ([0-9]+).*/\1/p')
  fi

  if [ -z "$BASH_MAJOR" ] || [ "$BASH_MAJOR" -lt 4 ]; then
    local BASH_VER
    BASH_VER=$(bash --version 2>/dev/null | head -1 || echo "unknown")
    echo "❌ ERROR: bash 4.0+ required (current: $BASH_VER)"
    echo "This script uses associative arrays (declare -A) which require bash 4.0+."
    echo ""
    echo "macOS users: brew install bash"
    exit 1
  fi

  # Check oc authentication
  if oc whoami &>/dev/null; then
    :  # Already authenticated
  else
    echo ""
    echo "============================================"
    echo "ERROR: Not authenticated with Konflux"
    echo "============================================"
    echo "This script requires oc authentication."
    echo "Run: oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/"
    echo ""
    exit 1
  fi

  echo "✓ Prerequisites verified: bash 4.0+, oc, jq, curl, git"
  echo "✓ Authenticated with Konflux as: $(oc whoami)"
}

# ============================================================================
# Argument Parsing
# ============================================================================

parse_arguments() {
  # Parse arguments (version, --stage/--prod - order-independent)
  local ARG1="$1"
  local ARG2="${2:-}"
  local REST="${3:-}"

  if [ -n "$REST" ]; then
    echo "❌ ERROR: Too many arguments"
    echo "Usage: $0 <version> [--stage|--prod]"
    exit 1
  fi

  for arg in "$ARG1" "$ARG2"; do
    [ -z "$arg" ] && continue

    case "$arg" in
      --stage|--prod)
        RELEASE_TYPE="${arg#--}"
        ;;
      [0-9].[0-9]|[0-9].[0-9].[0-9]|[0-9].[0-9][0-9]|[0-9].[0-9][0-9].[0-9]|[0-9].[0-9][0-9].[0-9][0-9])
        VERSION="$arg"
        ;;
      *)
        echo "❌ ERROR: Unknown argument: $arg"
        echo "Usage: $0 <version> [--stage|--prod]"
        echo "Example: $0 0.22.1 --stage"
        exit 1
        ;;
    esac
  done

  if [ -z "$VERSION" ]; then
    echo "❌ ERROR: Version required"
    echo "Usage: $0 <version> [--stage|--prod]"
    echo "Example: $0 0.22.1 --stage"
    exit 1
  fi

  # Validate version format
  if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+ ]]; then
    :  # Version format is valid
  else
    echo "❌ ERROR: Invalid version format: $VERSION"
    echo "Expected: 0.Y or 0.Y.Z (e.g., 0.22 or 0.22.1)"
    exit 1
  fi

  echo ""
  echo "============================================"
  echo "FBC $RELEASE_TYPE Release Creation"
  echo "============================================"
  echo "Version: $VERSION"
  echo "Release type: $RELEASE_TYPE"
  echo ""

  # Find git repository root (allows running from anywhere in repo)
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$GIT_ROOT" ]; then
    echo "❌ ERROR: Not in a git repository"
    exit 1
  fi

  # Set up paths relative to git root
  SCRIPTS_DIR="$GIT_ROOT/scripts"
  RELEASES_DIR="$GIT_ROOT/releases"

  # Verify this is the correct repository by checking for required scripts
  if [ -x "$SCRIPTS_DIR/verify-fbc-release.sh" ] && \
     [ -x "$SCRIPTS_DIR/generate-fbc-release.sh" ]; then
    :  # Scripts exist
  else
    echo "❌ ERROR: Required helper scripts not found"
    echo "This skill requires the submariner-release-management repository"
    echo "Looked in: $SCRIPTS_DIR"
    exit 1
  fi

  echo "Repository root: $GIT_ROOT"
  echo ""

  # Check git status (working tree should be clean)
  if git diff-index --quiet HEAD -- 2>/dev/null; then
    :  # Working tree is clean
  else
    echo "⚠️  WARNING: Working tree has uncommitted changes"
    echo "Proceeding anyway - you can review changes before pushing"
    echo ""
  fi
}

# ============================================================================
# Verify Release Readiness
# ============================================================================

verify_release() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Verifying FBC snapshots and component SHAs"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Call combined verification script (batched queries + parallel extraction)
  local COMBINED_JSON
  COMBINED_JSON=$("$SCRIPTS_DIR/verify-fbc-release.sh" "$VERSION" 2>&1)
  local VERIFY_EXIT=$?

  if [ $VERIFY_EXIT -ne 0 ]; then
    echo "$COMBINED_JSON"
    echo ""
    echo "❌ Verification failed"
    exit 1
  fi

  # Extract JSON (single line) and diagnostic output (everything else)
  local COMBINED_RESULT
  COMBINED_RESULT=$(echo "$COMBINED_JSON" | tail -1)

  # Show diagnostic output from script (all lines except JSON)
  echo "$COMBINED_JSON" | head -n -1

  # Parse JSON to verify status
  local STATUS
  STATUS=$(echo "$COMBINED_RESULT" | jq -r '.status' 2>/dev/null || echo "invalid")
  if [ "$STATUS" != "pass" ]; then
    echo "❌ Verification failed (invalid JSON output)"
    exit 1
  fi

  # Extract snapshot names for each OCP version
  for VERSION_NUM in 16 17 18 19 20 21; do
    local SNAPSHOT
    SNAPSHOT=$(echo "$COMBINED_RESULT" | jq -r ".snapshots[\"4-${VERSION_NUM}\"]")
    SNAPSHOTS["4-${VERSION_NUM}"]="$SNAPSHOT"
  done

  echo ""
}

# ============================================================================
# Generate Release YAMLs
# ============================================================================

generate_yamls() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Generating Release YAMLs"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Get release date
  local RELEASE_DATE
  RELEASE_DATE=$(date +%Y%m%d)

  # Change to git root so generate script can use relative paths
  cd "$GIT_ROOT" || exit 1

  for OCP_VERSION in 16 17 18 19 20 21; do
    # Get snapshot name from combined JSON
    local SNAPSHOT="${SNAPSHOTS[4-${OCP_VERSION}]}"

    echo "Generating 4-${OCP_VERSION} release..."

    # Call generate-fbc-release.sh using absolute path
    local YAML_FILE
    YAML_FILE=$("$SCRIPTS_DIR/generate-fbc-release.sh" "4-${OCP_VERSION}" "$SNAPSHOT" "$RELEASE_TYPE" "$RELEASE_DATE")
    local GENERATE_EXIT=$?

    if [ $GENERATE_EXIT -ne 0 ]; then
      echo "❌ Failed to generate YAML for 4-${OCP_VERSION}"
      exit 1
    fi

    echo "  ✓ Created: $YAML_FILE"
    CREATED_FILES+=("$YAML_FILE")
  done

  echo ""
  echo "✓ Created 6 FBC ${RELEASE_TYPE} Release YAMLs"
}

# ============================================================================
# Validate YAMLs
# ============================================================================

validate_yamls() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Validating Release YAMLs"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local VALIDATION_FAILED=0

  for YAML_FILE in "${CREATED_FILES[@]}"; do
    echo "Validating $(basename "$YAML_FILE")..."

    # Run make test-remote from git root using -C flag
    if make -C "$GIT_ROOT" test-remote FILE="$YAML_FILE" >/dev/null 2>&1; then
      echo "  ✓ Validation passed"
    else
      echo "  ✗ Validation failed"
      ((VALIDATION_FAILED++))
    fi
  done

  if [ $VALIDATION_FAILED -gt 0 ]; then
    echo ""
    echo "❌ $VALIDATION_FAILED YAML(s) failed validation"
    echo "Run 'make -C $GIT_ROOT test-remote FILE=<yaml>' for details"
    exit 1
  fi

  echo ""
  echo "✓ All YAMLs passed validation"
}

# ============================================================================
# Commit Changes
# ============================================================================

commit_changes() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Creating commit"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Stage all created files using absolute path
  git add "$RELEASES_DIR/fbc/" || {
    echo "❌ ERROR: Failed to stage files"
    exit 1
  }

  # Show what's being committed
  echo "Files to commit:"
  git status --short | grep "^A" | sed 's/^A  /  /'
  echo ""

  # Create commit message
  local COMMIT_MSG
  COMMIT_MSG="Add FBC ${RELEASE_TYPE} releases for $VERSION

Generated 6 Release CRs (OCP 4-16 through 4-21) with:
- Verified GitHub catalog consistency
- Verified FBC snapshots (push events, tests passed)
- Verified component SHAs across all sources
- Validated with make test-remote"

  # Create commit
  git commit -s -m "$COMMIT_MSG" || {
    echo "❌ ERROR: Failed to create commit"
    exit 1
  }

  local COMMIT_HASH
  COMMIT_HASH=$(git rev-parse --short HEAD)

  echo "✓ Commit created: $COMMIT_HASH"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SUCCESS - FBC ${RELEASE_TYPE} releases created"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Next steps:"
  echo ""
  echo "1. Review changes:"
  echo "   git show"
  echo ""
  echo "2. Push commit:"
  echo "   git push origin \$(git rev-parse --abbrev-ref HEAD)"
  echo ""
  echo "3. Apply releases to cluster:"
  for YAML_FILE in "${CREATED_FILES[@]}"; do
    local YAML_NAME
    YAML_NAME=$(basename "$YAML_FILE" .yaml)
    echo "   make apply FILE=$YAML_FILE"
    echo "   make watch NAME=$YAML_NAME"
  done
  echo ""
  echo "To undo this commit:"
  echo "   git reset HEAD~1"
  echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  check_prerequisites
  parse_arguments "$@"
  verify_release
  generate_yamls
  validate_yamls
  commit_changes
}

main "$@"
