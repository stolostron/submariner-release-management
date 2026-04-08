#!/bin/bash
# Add release notes to component stage release YAML
#
# Usage: add-release-notes.sh <version> [--stage-yaml PATH]
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
# Parse Arguments
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
  echo "❌ ERROR: Version required" >&2
  echo "Usage: $0 <version> [--stage-yaml PATH]" >&2
  exit 1
fi

# ============================================================================
# Source Shared Library
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"

# shellcheck source=lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

# ============================================================================
# Main Workflow
# ============================================================================

banner "Add Release Notes for $VERSION"

# Phase 1: Collect raw data from Jira and existing releases
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Collect raw data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -n "$STAGE_YAML_ARG" ]]; then
  "$SCRIPT_DIR/release-notes/collect.sh" "$VERSION" --stage-yaml "$STAGE_YAML_ARG"
else
  "$SCRIPT_DIR/release-notes/collect.sh" "$VERSION"
fi

if [[ ! -f /tmp/release-notes-data.json ]]; then
  echo "❌ ERROR: Phase 1 failed (no data file)" >&2
  exit 1
fi

echo ""

# Phase 2: Filter and group issues
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Filter and group issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/release-notes/prepare.sh"

if [[ ! -f /tmp/release-notes-topics.json ]]; then
  echo "❌ ERROR: Phase 2 failed (no topics file)" >&2
  exit 1
fi

echo ""

# Phase 3: Auto-apply ALL filtered issues to stage YAML
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3: Auto-apply release notes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/release-notes/auto-apply.sh"

echo ""

# Phase 4: Verify CVE fixes in Clair reports (if CVEs present)
CVE_COUNT=$(jq -r '.cve_topics | length' /tmp/release-notes-topics.json 2>/dev/null || echo "0")
if [[ "$CVE_COUNT" -gt 0 ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Phase 4: Verify CVE fixes in snapshot images"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  STAGE_YAML=$(jq -r '.metadata.stage_yaml' /tmp/release-notes-data.json)
  if ! "$SCRIPT_DIR/release-notes/verify-cve-fixes.sh" "$STAGE_YAML"; then
    echo ""
    echo "⚠️  Some CVEs are NOT actually fixed - see verification output above"
    echo "Remove unfixed CVEs from commit: git commit --amend"
  fi
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Release notes workflow complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
