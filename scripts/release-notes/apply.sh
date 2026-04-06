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

# shellcheck source=../lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

DECISIONS_JSON="/tmp/release-notes-decisions.json"
DATA_JSON="/tmp/release-notes-data.json"

if [[ ! -f "$DECISIONS_JSON" ]]; then
  echo "❌ ERROR: Decisions file not found: '$DECISIONS_JSON'" >&2
  echo "Run skill analysis first to create decisions file" >&2
  exit 1
fi

if [[ ! -f "$DATA_JSON" ]]; then
  echo "❌ ERROR: Data file not found: '$DATA_JSON'" >&2
  echo "Run collect.sh first" >&2
  exit 1
fi

banner "Apply Release Notes to Stage YAML"

extract_and_validate_metadata "$DATA_JSON"

# ============================================================================
# Build releaseNotes Section
# ============================================================================

echo "Building releaseNotes YAML section..."

RELEASE_TYPE=$(jq -r '.release_type' "$DECISIONS_JSON")

read -r CVE_COUNT CVE_ISSUE_KEYS < <(jq -r '.cve_issues | "\(length) \([.[].issue_key] | sort | join(" "))"' "$DATA_JSON")
read -r NON_CVE_COUNT SELECTED_NON_CVE_KEYS < <(jq -r '.non_cve_issues.selected | "\(length) \([.[].issue_key] | sort | join(" "))"' "$DECISIONS_JSON")

ISSUES_FIXED_YAML=$(build_issues_fixed_yaml "$CVE_COUNT" "$CVE_ISSUE_KEYS" "$NON_CVE_COUNT" "$SELECTED_NON_CVE_KEYS")

CVES_YAML=""
if [[ "$CVE_COUNT" -gt 0 ]]; then
  CVES_YAML=$(jq -r '
    .cve_issues | group_by(.cve_key) | map({
      cve_key: .[0].cve_key,
      issue_keys: map(.issue_key) | join(", "),
      components: map(.component_mapped)
    }) | .[] | .cve_key as $cve_key |
    "        # \($cve_key) (\(.issue_keys)): FIXED\n" +
    "        #   Test: command to verify fix\n" +
    "        #   Output: expected output showing fixed version\n" +
    "        #   Required: minimum version needed\n" +
    (.components | map("        - key: \($cve_key)\n          component: \(.)") | join("\n"))
  ' "$DATA_JSON")
fi

RELEASE_NOTES_YAML=$(build_release_notes_yaml "$RELEASE_TYPE" "$ISSUES_FIXED_YAML" "$CVES_YAML")

display_release_notes_summary "$RELEASE_TYPE" "$CVE_COUNT" "$NON_CVE_COUNT"

# ============================================================================
# Update Stage YAML
# ============================================================================

update_stage_yaml_data_section "$STAGE_YAML" "$RELEASE_NOTES_YAML"

# ============================================================================
# Validate
# ============================================================================

validate_stage_yaml "$STAGE_YAML"

# ============================================================================
# Commit
# ============================================================================

echo "Preparing commit..."

RATIONALE=$(jq -r '.release_type_rationale // "Updated release notes"' "$DECISIONS_JSON")

COMMIT_MSG="Add release notes for $VERSION

Type: $RELEASE_TYPE
CVE issues: $CVE_COUNT
Non-CVE issues: $NON_CVE_COUNT

Rationale: $RATIONALE"

commit_release_notes "$STAGE_YAML" "$COMMIT_MSG" "applied"

echo "Next steps:"
echo "  1. Review changes: git show"
echo "  2. Push when ready: git push"
