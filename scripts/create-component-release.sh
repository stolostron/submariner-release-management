#!/bin/bash
# Create component release (stage or prod)
#
# Usage: create-component-release.sh <version> [stage|prod]
#
# Arguments:
#   version: Submariner version (e.g., 0.22.1 or 0.22)
#   [stage|prod]: Release type (default: stage)
#
# Exit codes:
#   0: Success (release created and committed)
#   1: Failure (prerequisites, validation, or commit failed)

set -euo pipefail

# Global variables (set by parse_arguments)
VERSION=""
RELEASE_TYPE="stage"
GIT_ROOT=""
SCRIPTS_DIR=""

# Global variables (set by verify_release)
SNAPSHOT_NAME=""

# Global variables (set by generate_yaml)
YAML_FILE=""

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
  local MISSING_TOOLS=()

  command -v oc &>/dev/null || MISSING_TOOLS+=("oc")
  command -v jq &>/dev/null || MISSING_TOOLS+=("jq")
  command -v git &>/dev/null || MISSING_TOOLS+=("git")

  if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "❌ ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "Installation instructions:"
    for tool in "${MISSING_TOOLS[@]}"; do
      case "$tool" in
        oc) echo "  oc: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html" ;;
        jq) echo "  jq: https://jqlang.github.io/jq/download/" ;;
        git) echo "  git: https://git-scm.com/downloads" ;;
      esac
    done
    exit 1
  fi

  # Check oc authentication (only for stage/prod that need snapshot)
  if [ "$RELEASE_TYPE" = "stage" ]; then
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
  fi

  echo "✓ Prerequisites verified: oc, jq, git"
  if oc whoami &>/dev/null; then
    echo "✓ Authenticated with Konflux as: $(oc whoami)"
  fi
}

# ============================================================================
# Argument Parsing
# ============================================================================

show_usage() {
  echo "Usage: $0 <version> [stage|prod]"
  echo "Example: $0 0.22.1"
  echo "Example: $0 0.22.1 stage"
  echo "Example: $0 0.22.1 prod"
}

parse_arguments() {
  local VERSION_ARG="${1:-}"
  local TYPE_ARG="${2:-}"

  if [ -z "$VERSION_ARG" ]; then
    echo "❌ ERROR: Version required"
    show_usage
    exit 1
  fi

  if [ $# -gt 2 ]; then
    echo "❌ ERROR: Too many arguments"
    show_usage
    exit 1
  fi

  # Parse version
  VERSION="$VERSION_ARG"

  # Validate version format and expand if needed
  if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    # X.Y format → default to X.Y.0
    VERSION="${VERSION}.0"
    echo "ℹ️  Defaulting to $VERSION (patch version 0)"
  elif ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ ERROR: Invalid version format: $VERSION"
    echo "Expected: X.Y or X.Y.Z (e.g., 0.22 or 0.22.1)"
    exit 1
  fi

  # Parse release type (default: stage)
  if [ -n "$TYPE_ARG" ]; then
    if [[ "$TYPE_ARG" = "stage" || "$TYPE_ARG" = "prod" ]]; then
      RELEASE_TYPE="$TYPE_ARG"
    else
      echo "❌ ERROR: Invalid release type: $TYPE_ARG"
      echo "Expected: stage or prod"
      show_usage
      exit 1
    fi
  fi

  echo ""
  echo "============================================"
  echo "Component $RELEASE_TYPE Release Creation"
  echo "============================================"
  echo "Version: $VERSION"
  echo "Release type: $RELEASE_TYPE"
  if [ "$RELEASE_TYPE" = "stage" ]; then
    echo "Release notes: Placeholder (fill via Step 9 workflow)"
  else
    echo "Release notes: Copied from stage"
  fi
  echo ""

  # Find git repository root (allows running from anywhere in repo)
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$GIT_ROOT" ]; then
    echo "❌ ERROR: Not in a git repository"
    exit 1
  fi

  # Set up paths relative to git root
  SCRIPTS_DIR="$GIT_ROOT/scripts"

  # Verify helper scripts exist
  if [ ! -x "$SCRIPTS_DIR/verify-component-release.sh" ] || \
     [ ! -x "$SCRIPTS_DIR/generate-component-release.sh" ]; then
    echo "❌ ERROR: Required helper scripts not found"
    echo "This script requires:"
    echo "  - scripts/verify-component-release.sh"
    echo "  - scripts/generate-component-release.sh"
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
  # Skip verification for prod (uses same snapshot as stage)
  if [ "$RELEASE_TYPE" = "prod" ]; then
    echo "Skipping snapshot verification for prod release"
    echo "(Prod uses same snapshot as stage - already verified)"
    echo ""
    # Extract snapshot from stage YAML for prod generation
    local VERSION_MAJOR_MINOR
    VERSION_MAJOR_MINOR=$(echo "$VERSION" | grep -oE '^[0-9]+\.[0-9]+')
    local VERSION_FULL_DASH
    VERSION_FULL_DASH="${VERSION//./-}"
    local STAGE_DIR="releases/${VERSION_MAJOR_MINOR}/stage"
    local STAGE_YAML
    STAGE_YAML=$(find "$STAGE_DIR" -name "submariner-${VERSION_FULL_DASH}-stage-*.yaml" -type f | sort | tail -1)
    if [ -z "$STAGE_YAML" ]; then
      echo "❌ ERROR: No stage YAML found"
      echo "Run stage creation first: $0 $VERSION stage"
      exit 1
    fi
    SNAPSHOT_NAME=$(grep "snapshot:" "$STAGE_YAML" | awk '{print $2}')
    echo "Using snapshot from stage: $SNAPSHOT_NAME"
    echo ""
    return 0
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Verifying component snapshot"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Call verification script
  local VERIFY_JSON VERIFY_EXIT
  VERIFY_JSON=$("$SCRIPTS_DIR/verify-component-release.sh" "$VERSION" 2>&1) && VERIFY_EXIT=0 || VERIFY_EXIT=$?

  if [ $VERIFY_EXIT -ne 0 ]; then
    echo "$VERIFY_JSON"
    echo ""
    echo "❌ Verification failed"
    exit 1
  fi

  # Extract JSON (last line) and diagnostic output (everything else)
  local VERIFY_RESULT
  VERIFY_RESULT=$(echo "$VERIFY_JSON" | tail -1)

  # Show diagnostic output from script
  echo "$VERIFY_JSON" | head -n -1

  # Parse JSON to verify status
  local STATUS
  STATUS=$(echo "$VERIFY_RESULT" | jq -r '.status' 2>/dev/null || echo "invalid")
  if [ "$STATUS" != "pass" ]; then
    echo "❌ Verification failed (invalid JSON output)"
    exit 1
  fi

  # Extract snapshot name
  SNAPSHOT_NAME=$(echo "$VERIFY_RESULT" | jq -r '.snapshot')

  echo ""
}

# ============================================================================
# Generate Release YAML
# ============================================================================

generate_yaml() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Generating Release YAML"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Get release date
  local RELEASE_DATE
  RELEASE_DATE=$(date +%Y%m%d)

  # Change to git root so generate script can use relative paths
  cd "$GIT_ROOT" || exit 1

  # Call generate script
  YAML_FILE=$("$SCRIPTS_DIR/generate-component-release.sh" "$VERSION" "$SNAPSHOT_NAME" "$RELEASE_TYPE" "$RELEASE_DATE" 2>&1)
  local GENERATE_EXIT=$?

  if [ $GENERATE_EXIT -ne 0 ]; then
    echo "$YAML_FILE"
    echo "❌ Failed to generate YAML"
    exit 1
  fi

  # Extract filename from output (last line should be the file path)
  YAML_FILE=$(echo "$YAML_FILE" | tail -1)

  if [ ! -f "$YAML_FILE" ]; then
    echo "❌ Generated file not found: $YAML_FILE"
    exit 1
  fi

  echo "✓ Created: $YAML_FILE"
  echo ""
}

# ============================================================================
# Validate YAML
# ============================================================================

validate_yaml() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Validating Release YAML"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "Validating $(basename "$YAML_FILE")..."

  if [ "$RELEASE_TYPE" = "prod" ]; then
    # For prod, run local validation only (snapshot not releasable yet)
    echo "Running local validation only (prod uses same snapshot as stage)..."
    if make -C "$GIT_ROOT" test FILE="$YAML_FILE" >/dev/null 2>&1; then
      echo "  ✓ Validation passed"
    else
      echo "  ✗ Validation failed"
      echo ""
      echo "❌ Validation failed"
      echo "Run 'make -C $GIT_ROOT test FILE=$YAML_FILE' for details"
      exit 1
    fi
  else
    # For stage with notes placeholder, run full validation
    echo "Running full validation (including cluster checks)..."
    if make -C "$GIT_ROOT" test-remote FILE="$YAML_FILE" >/dev/null 2>&1; then
      echo "  ✓ Validation passed"
    else
      echo "  ✗ Validation failed"
      echo ""
      echo "❌ Validation failed"
      echo "Run 'make -C $GIT_ROOT test-remote FILE=$YAML_FILE' for details"
      exit 1
    fi
  fi

  echo ""
  echo "✓ YAML validation passed"
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

  # Stage the created file
  git add "$YAML_FILE" || {
    echo "❌ ERROR: Failed to stage file"
    exit 1
  }

  # Show what's being committed
  echo "File to commit:"
  git status --short | grep "^A" | sed 's/^A  /  /'
  echo ""

  # Create commit message
  local COMMIT_MSG
  if [ "$RELEASE_TYPE" = "stage" ]; then
    COMMIT_MSG="Add component ${RELEASE_TYPE} release for $VERSION

Snapshot: $SNAPSHOT_NAME
Release notes: Fill placeholder via Step 9 workflow"
  else
    COMMIT_MSG="Add component ${RELEASE_TYPE} release for $VERSION

Snapshot: $SNAPSHOT_NAME (same as stage)
Release notes: Copied from stage (QE-verified)"
  fi

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
  echo "SUCCESS - Component ${RELEASE_TYPE} release created"
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
  if [ "$RELEASE_TYPE" = "stage" ]; then
    echo "3. Fill release notes placeholder (issues.fixed[], cves[])"
    echo ""
    echo "4. Apply release to cluster:"
  else
    echo "3. Apply release to cluster:"
  fi
  echo "   make apply FILE=$YAML_FILE"
  local RELEASE_NAME
  RELEASE_NAME=$(basename "$YAML_FILE" .yaml)
  echo "   make watch NAME=$RELEASE_NAME"
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
  generate_yaml
  validate_yaml
  commit_changes
}

main "$@"
