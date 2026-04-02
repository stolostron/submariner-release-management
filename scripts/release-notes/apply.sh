#!/bin/bash
# Phase 4: Apply Claude's release notes decisions to stage YAML
# Input: /tmp/release-notes-decisions.json, /tmp/release-notes-data.json
# Output: Updated stage YAML + git commit
set -euo pipefail

# ============================================================================
# Initialize
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source shared library for banner function
# shellcheck source=../lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

DECISIONS_JSON="/tmp/release-notes-decisions.json"
DATA_JSON="/tmp/release-notes-data.json"

if [ ! -f "$DECISIONS_JSON" ]; then
  echo "❌ ERROR: Decisions file not found: '$DECISIONS_JSON'" >&2
  echo "Run skill analysis first to create decisions file" >&2
  exit 1
fi

if [ ! -f "$DATA_JSON" ]; then
  echo "❌ ERROR: Data file not found: '$DATA_JSON'" >&2
  echo "Run collect.sh first" >&2
  exit 1
fi

banner "Apply Release Notes to Stage YAML"

# Extract metadata and stage YAML path
STAGE_YAML=$(jq -r '.metadata.stage_yaml' "$DATA_JSON")
VERSION=$(jq -r '.metadata.version' "$DATA_JSON")

echo "Version: $VERSION"
echo "Stage YAML: $STAGE_YAML"
echo ""

if [ ! -f "$STAGE_YAML" ]; then
  echo "❌ ERROR: Stage YAML not found: '$STAGE_YAML'" >&2
  exit 1
fi

# ============================================================================
# Build releaseNotes Section
# ============================================================================

echo "Building releaseNotes YAML section..."

# Extract release type from decisions
RELEASE_TYPE=$(jq -r '.release_type' "$DECISIONS_JSON")

# Build issues.fixed[] array (CVE + selected non-CVE, sorted)
CVE_ISSUE_KEYS=$(jq -r '.cve_issues[].issue_key // empty' "$DATA_JSON" | sort)
SELECTED_NON_CVE_KEYS=$(jq -r '.non_cve_issues.selected[].issue_key // empty' "$DECISIONS_JSON" | sort)

# Count issues (handle empty case)
if [ -z "$CVE_ISSUE_KEYS" ]; then
  CVE_COUNT=0
else
  CVE_COUNT=$(echo "$CVE_ISSUE_KEYS" | wc -l)
fi

if [ -z "$SELECTED_NON_CVE_KEYS" ]; then
  NON_CVE_COUNT=0
else
  NON_CVE_COUNT=$(echo "$SELECTED_NON_CVE_KEYS" | wc -l)
fi

# Build issues.fixed YAML (with section headers)
ISSUES_FIXED_YAML=""
if [ "$CVE_COUNT" -gt 0 ]; then
  ISSUES_FIXED_YAML="${ISSUES_FIXED_YAML}          # CVE Issues ($CVE_COUNT):\n"
  for KEY in $CVE_ISSUE_KEYS; do
    ISSUES_FIXED_YAML="${ISSUES_FIXED_YAML}          - id: $KEY\n            source: issues.redhat.com\n"
  done
fi

if [ "$NON_CVE_COUNT" -gt 0 ]; then
  ISSUES_FIXED_YAML="${ISSUES_FIXED_YAML}          # Non-CVE Issues ($NON_CVE_COUNT):\n"
  for KEY in $SELECTED_NON_CVE_KEYS; do
    ISSUES_FIXED_YAML="${ISSUES_FIXED_YAML}          - id: $KEY\n            source: issues.redhat.com\n"
  done
fi

# Build cves[] array (grouped by CVE key, with verification comments)
CVES_YAML=""
if [ "$CVE_COUNT" -gt 0 ]; then
  # Group CVE data by cve_key (from data.json)
  CVE_GROUPS=$(jq -r '
    .cve_issues | group_by(.cve_key) | map({
      cve_key: .[0].cve_key,
      issue_keys: map(.issue_key) | join(", "),
      components: map(.component_mapped)
    })
  ' "$DATA_JSON")

  # Build YAML with verification comments (use process substitution to preserve variable)
  while IFS= read -r line; do
    CVES_YAML="${CVES_YAML}${line}\n"
  done < <(echo "$CVE_GROUPS" | jq -r '.[] | .cve_key as $cve_key |
    "        # \($cve_key) (\(.issue_keys)): FIXED\n" +
    "        #   Test: command to verify fix\n" +
    "        #   Output: expected output showing fixed version\n" +
    "        #   Required: minimum version needed\n" +
    (.components | map("        - key: \($cve_key)\n          component: \(.)") | join("\n"))
  ')
fi

# Build complete releaseNotes section
# Note: Add explicit newline before cves section (command substitution strips trailing newlines)
RELEASE_NOTES_YAML="  data:
    releaseNotes:
      type: $RELEASE_TYPE
      issues:
        fixed:
$(echo -e "$ISSUES_FIXED_YAML")"

if [ -n "$CVES_YAML" ]; then
  RELEASE_NOTES_YAML="${RELEASE_NOTES_YAML}
      cves:
$(echo -e "$CVES_YAML")"
fi

echo "✓ releaseNotes section built"
echo "  Type: $RELEASE_TYPE"
echo "  CVE issues: $CVE_COUNT"
echo "  Non-CVE issues: $NON_CVE_COUNT"
echo ""

# ============================================================================
# Update Stage YAML
# ============================================================================

echo "Updating stage YAML..."

# Validate YAML doesn't have duplicate data: sections (malformed)
DATA_COUNT=$(grep -c "^  data:" "$STAGE_YAML" || echo "0")
if [ "$DATA_COUNT" -gt 1 ]; then
  echo "❌ ERROR: YAML has $DATA_COUNT 'data:' sections (expected 0 or 1)" >&2
  echo "File is malformed. Fix manually before applying release notes." >&2
  exit 1
fi

# Backup original
cp "$STAGE_YAML" "${STAGE_YAML}.bak"
echo "✓ Backup created: ${STAGE_YAML}.bak"

# Replace data: section in YAML using sed (robust YAML parsing would use yq)
# Algorithm:
#   1. Extract lines before "  data:" (if exists) → tmpfile
#   2. Append new releaseNotes section → tmpfile
#   3. Append lines after old data section (next spec.* key onwards) → tmpfile
#
# Example transformations:
#   Input: spec:\n  snapshot: X\n  data:\n    old: Y\n  releasePlan: Z
#   Output: spec:\n  snapshot: X\n  data:\n    releaseNotes: {...}\n  releasePlan: Z
#
#   Input: spec:\n  snapshot: X\n  releasePlan: Y  (no data section)
#   Output: spec:\n  snapshot: X\n  releasePlan: Y\n  data:\n    releaseNotes: {...}

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT INT TERM

DATA_LINE=$(grep -n '^  data:' "$STAGE_YAML" | head -1 | cut -d: -f1 || echo "")

if [ -n "$DATA_LINE" ]; then
  # YAML has existing data: section - replace it

  # Extract everything before "  data:" (excluding the data: line itself)
  sed -n '1,/^  data:/p' "$STAGE_YAML" | head -n -1 > "$TMPFILE"

  # Add new releaseNotes section
  echo "$RELEASE_NOTES_YAML" >> "$TMPFILE"

  # Find next key at same indentation (e.g., "  releasePlan:" after "  data:")
  # This marks where the old data: section ends
  NEXT_KEY_LINE=$(tail -n +"$((DATA_LINE + 1))" "$STAGE_YAML" | \
    grep -n '^[[:space:]]\{0,2\}[a-zA-Z]' | head -1 | cut -d: -f1 || echo "")

  if [ -n "$NEXT_KEY_LINE" ]; then
    # Append everything from next key onwards (preserves releasePlan, etc.)
    ABS_LINE=$((DATA_LINE + NEXT_KEY_LINE))
    tail -n +"$ABS_LINE" "$STAGE_YAML" >> "$TMPFILE"
  fi
  # If no next key found, data: was the last section (nothing to append)
else
  # YAML has no data: section - append new section at end
  cat "$STAGE_YAML" > "$TMPFILE"
  echo "$RELEASE_NOTES_YAML" >> "$TMPFILE"
fi

# Replace original with updated
mv "$TMPFILE" "$STAGE_YAML"
echo "✓ Stage YAML updated"
echo ""

# ============================================================================
# Validate
# ============================================================================

echo "Validating updated YAML..."

# YAML syntax check
if ! yq eval '.' "$STAGE_YAML" >/dev/null 2>&1; then
  echo "❌ ERROR: YAML syntax invalid" >&2
  echo "Restoring backup..." >&2
  mv "${STAGE_YAML}.bak" "$STAGE_YAML"
  exit 1
fi
echo "✓ YAML syntax valid"

# Find git root for make command
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "⚠️  WARNING: Not in git repository - skipping validation" >&2
else
  # Run file validation (yaml, fields, data - excludes gitlint/markdown)
  if (cd "$GIT_ROOT" && make validate-file FILE="$STAGE_YAML" 2>&1) | grep -q "ERROR"; then
    echo "❌ ERROR: Release data validation failed" >&2
    echo "Restoring backup..." >&2
    mv "${STAGE_YAML}.bak" "$STAGE_YAML"
    exit 1
  fi
  echo "✓ Release data validation passed"
fi
echo ""

# ============================================================================
# Commit
# ============================================================================

echo "Preparing commit..."

# Extract rationale from decisions
RATIONALE=$(jq -r '.release_type_rationale // "Updated release notes"' "$DECISIONS_JSON")

# Build commit message
COMMIT_MSG="Add release notes for $VERSION

Type: $RELEASE_TYPE
CVE issues: $CVE_COUNT
Non-CVE issues: $NON_CVE_COUNT

Rationale: $RATIONALE"

echo "Commit message:"
echo "$COMMIT_MSG"
echo ""

# Stage file
git add "$STAGE_YAML"

# Remove backup
rm -f "${STAGE_YAML}.bak"

# Commit
git commit -s -m "$COMMIT_MSG"

echo "✓ Changes committed"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Release notes applied successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Review changes: git show"
echo "  2. Push when ready: git push"
