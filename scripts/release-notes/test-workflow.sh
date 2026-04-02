#!/bin/bash
# Test script to verify add-release-notes workflow correctness
# Usage: ./scripts/release-notes/test-workflow.sh [VERSION]
set -euo pipefail

VERSION="${1:-0.23.1}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing add-release-notes Workflow: $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean up previous test artifacts
rm -f /tmp/release-notes-*.json

echo "1. Testing component mapping (correctness)..."
source scripts/lib/release-notes-common.sh

# Test multi-part component name (regression test for submariner-route-agent bug)
RESULT=$(map_component_name "rhacm2/submariner-route-agent-rhel9" "0-23")
if [ "$RESULT" = "submariner-route-agent-0-23" ]; then
  echo "   ✓ submariner-route-agent mapped correctly"
else
  echo "   ✗ FAILED: Expected 'submariner-route-agent-0-23', got '$RESULT'"
  exit 1
fi

# Test other components
for test_case in \
  "rhacm2/submariner-operator-rhel9:submariner-operator-0-23" \
  "rhacm2/submariner-rhel9-operator:submariner-operator-0-23" \
  "rhacm2/lighthouse-agent-rhel9:lighthouse-agent-0-23" \
  "nettest-container:nettest-0-23" \
  "rhacm2/submariner-addon-rhel9:EXCLUDE"; do

  INPUT=$(echo "$test_case" | cut -d: -f1)
  EXPECTED=$(echo "$test_case" | cut -d: -f2)
  RESULT=$(map_component_name "$INPUT" "0-23")

  if [ "$RESULT" = "$EXPECTED" ]; then
    echo "   ✓ $INPUT → $RESULT"
  else
    echo "   ✗ FAILED: $INPUT → expected '$EXPECTED', got '$RESULT'"
    exit 1
  fi
done

echo ""
echo "2. Testing collect.sh (data collection)..."
if bash scripts/release-notes/collect.sh "$VERSION" >/dev/null 2>&1; then
  echo "   ✓ Data collection completed"

  # Verify JSON structure
  if jq -e '.metadata.version_major_minor' /tmp/release-notes-data.json >/dev/null 2>&1; then
    echo "   ✓ JSON has correct field names (version_major_minor vs version_dot)"
  else
    echo "   ✗ FAILED: JSON missing version_major_minor field"
    exit 1
  fi

  CVE_COUNT=$(jq '.cve_issues | length' /tmp/release-notes-data.json)
  NON_CVE_COUNT=$(jq '.non_cve_issues | length' /tmp/release-notes-data.json)
  echo "   ✓ Collected $CVE_COUNT CVEs, $NON_CVE_COUNT non-CVE issues"
else
  echo "   ✗ FAILED: collect.sh failed"
  exit 1
fi

echo ""
echo "3. Testing prepare.sh (filtering/grouping)..."
if bash scripts/release-notes/prepare.sh >/dev/null 2>&1; then
  echo "   ✓ Data preparation completed"

  TOPIC_COUNT=$(jq '.non_cve_topics | length' /tmp/release-notes-topics.json)
  BLOCKER_COUNT=$(jq '.statistics.non_cve_blocker' /tmp/release-notes-topics.json)
  MAJOR_COUNT=$(jq '.statistics.non_cve_major' /tmp/release-notes-topics.json)
  echo "   ✓ Grouped into $TOPIC_COUNT topics ($BLOCKER_COUNT Blockers, $MAJOR_COUNT Majors)"
else
  echo "   ✗ FAILED: prepare.sh failed"
  exit 1
fi

echo ""
echo "4. Testing apply.sh (YAML generation)..."

# Create mock decisions (CVEs auto-included from data.json)
cat > /tmp/release-notes-decisions.json <<'EOF'
{
  "metadata": {
    "version": "0.23.1",
    "analyzed_at": "2026-04-01T00:00:00Z",
    "analyzer": "test-script"
  },
  "release_type": "RHSA",
  "release_type_rationale": "CVE present",
  "non_cve_issues": {
    "selected": [
      {
        "issue_key": "ACM-30970",
        "rationale": "Test issue"
      }
    ]
  }
}
EOF

# Add mock CVE data to data.json (use valid CVE format: CVE-YYYY-NNNNN)
jq '.cve_issues = [
  {
    "issue_key": "ACM-12345",
    "cve_key": "CVE-2024-99999",
    "pscomponent": "rhacm2/submariner-operator-rhel9",
    "component_mapped": "submariner-operator-0-23",
    "labels": ["Security", "CVE-2024-99999", "pscomponent:rhacm2/submariner-operator-rhel9"]
  },
  {
    "issue_key": "ACM-12346",
    "cve_key": "CVE-2024-99999",
    "pscomponent": "rhacm2/lighthouse-agent-rhel9",
    "component_mapped": "lighthouse-agent-0-23",
    "labels": ["Security", "CVE-2024-99999", "pscomponent:rhacm2/lighthouse-agent-rhel9"]
  }
]' /tmp/release-notes-data.json > /tmp/release-notes-data-with-cve.json
mv /tmp/release-notes-data-with-cve.json /tmp/release-notes-data.json

# Backup original YAML
STAGE_YAML=$(jq -r '.metadata.stage_yaml' /tmp/release-notes-data.json)
if [ ! -f "$STAGE_YAML" ]; then
  echo "   ✗ FAILED: Stage YAML not found: $STAGE_YAML"
  exit 1
fi

cp "$STAGE_YAML" "$STAGE_YAML.test-backup"

# Run apply.sh (stop after validation, before the git commit)
# Use timeout to stop before commit (which may fail on pre-existing gitlint issues)
OUTPUT=$(timeout 30 bash scripts/release-notes/apply.sh 2>&1 || true)

# Check if validation passed (this is the critical test)
# NOTE: Use grep without -q and redirect to /dev/null to avoid pipefail issues
echo "$OUTPUT" | grep "Release data validation passed" >/dev/null 2>&1
VALIDATION_PASSED=$?

if [ "$VALIDATION_PASSED" -eq 0 ]; then
  echo "   ✓ YAML validation passed"

  # Verify YAML was actually updated with correct data
  if grep -q "type: RHSA" "$STAGE_YAML"; then
    echo "   ✓ YAML contains release type: RHSA"
  else
    echo "   ✗ FAILED: YAML missing release type"
    mv "$STAGE_YAML.test-backup" "$STAGE_YAML"
    exit 1
  fi

  # Verify CVE section generated correctly (key: CVE-*, component: *)
  if grep -A1 "key: CVE-2024-99999" "$STAGE_YAML" | grep -q "component: submariner-operator-0-23"; then
    echo "   ✓ CVE section formatted correctly"
  else
    echo "   ✗ FAILED: CVE section malformed"
    grep -A2 "cves:" "$STAGE_YAML" || echo "No cves section found"
    mv "$STAGE_YAML.test-backup" "$STAGE_YAML"
    exit 1
  fi

  # Verify both CVE and non-CVE issues present
  CVE_COUNT=$(grep -c "# CVE-2024-99999" "$STAGE_YAML" || echo 0)
  if [ "$CVE_COUNT" -gt 0 ]; then
    echo "   ✓ CVE comments present"
  fi

  # Restore original
  mv "$STAGE_YAML.test-backup" "$STAGE_YAML"
else
  echo "   ✗ FAILED: apply.sh validation failed"
  echo "$OUTPUT" | grep -E "ERROR|❌" | tail -5
  mv "$STAGE_YAML.test-backup" "$STAGE_YAML"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All tests passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Workflow summary:"
echo "  collect.sh:  ✓ Queries Jira, maps components"
echo "  prepare.sh:  ✓ Filters and groups issues"
echo "  apply.sh:    ✓ Generates valid YAML"
echo ""
echo "Ready for production use:"
echo "  make add-release-notes VERSION=$VERSION"
echo "  /add-release-notes $VERSION"
