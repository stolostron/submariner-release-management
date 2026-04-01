#!/bin/bash
# Phase 2: Prepare release notes data for AI analysis
# Input: /tmp/release-notes-data.json
# Output: /tmp/release-notes-topics.json
set -euo pipefail

# ============================================================================
# Initialize
# ============================================================================

INPUT_JSON="/tmp/release-notes-data.json"
OUTPUT_JSON="/tmp/release-notes-topics.json"

if [ ! -f "$INPUT_JSON" ]; then
  echo "❌ ERROR: Input file not found: '$INPUT_JSON'" >&2
  echo "Run collect.sh first" >&2
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Prepare Release Notes Data for Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# Filter and Group with jq
# ============================================================================

jq '
# Extract metadata
.metadata as $meta |

# Extract existing issues array
.existing_issues as $existing |

# Filter non-CVE issues
(
  if $meta.timeframe_type == "z-stream" then
    # Z-stream: exclude existing + filter by timeframe
    .non_cve_issues | map(
      select(
        (.issue_key | IN($existing[]) | not) and
        (.created >= $meta.timeframe_start or .updated >= $meta.timeframe_start)
      )
    )
  else
    # Y-stream: exclude existing only (no timeframe filter)
    .non_cve_issues | map(
      select(.issue_key | IN($existing[]) | not)
    )
  end
) as $filtered_non_cve |

# CVE issues: no existing issue filtering (CVEs always included regardless)
.cve_issues as $filtered_cve |

# Group CVEs by CVE key
(
  $filtered_cve | group_by(.cve_key) | map({
    cve_key: .[0].cve_key,
    issue_count: length,
    issues: map({
      issue_key: .issue_key,
      component: .component_mapped
    }),
    summary: (
      .[0].cve_key + " affects " +
      (map(.component_mapped) | join(", "))
    ),
    auto_include: true
  })
) as $cve_topics |

# Categorize non-CVE issues by pattern (connectivity, performance, features, bugs)
# Add category field to each issue first, then group by that field
(
  $filtered_non_cve | map(
    . + {
      category: (
        if (.summary | test("connect|cable|gateway|route|nat"; "i")) then "connectivity"
        elif (.summary | test("performance|latency|slow|throughput"; "i")) then "performance"
        elif (.summary | test("feature|enhancement|add support|new"; "i")) then "features"
        else "bugs"
        end
      )
    }
  ) | group_by(.category) | map({
    category: .[0].category,
    count: length,
    priority_breakdown: (
      group_by(.priority) | map({
        key: .[0].priority,
        value: length
      }) | from_entries
    ),
    issues: map({
      issue_key: .issue_key,
      priority: .priority,
      status: .status,
      summary: .summary,
      notable_reason: (
        if .priority == "Blocker" then "Blocker severity"
        elif .priority == "Major" then "Major priority"
        elif (.summary | test("customer|user-facing|production"; "i")) then "Customer-facing"
        else "Standard fix"
        end
      )
    })
  })
) as $non_cve_topics |

# Calculate statistics
(
  {
    cve_count: ($filtered_cve | length),
    non_cve_total: ($filtered_non_cve | length),
    non_cve_blocker: ($filtered_non_cve | map(select(.priority == "Blocker")) | length),
    non_cve_major: ($filtered_non_cve | map(select(.priority == "Major")) | length)
  }
) as $statistics |

# Build recommendation
(
  {
    release_type: (if ($filtered_cve | length) > 0 then "RHSA" else "RHBA" end),
    reason: (
      if ($filtered_cve | length) > 0 then "CVEs present (RHSA required)"
      else "No CVEs (RHBA for bug fixes or RHEA for enhancements)"
      end
    ),
    suggested_non_cve_issues: (
      $filtered_non_cve |
      map(select(.priority == "Blocker" or .priority == "Major")) |
      map(.issue_key)
    )
  }
) as $recommendation |

# Build final output
{
  metadata: $meta,
  cve_topics: $cve_topics,
  non_cve_topics: $non_cve_topics,
  statistics: $statistics,
  recommendation: $recommendation
}
' "$INPUT_JSON" > "$OUTPUT_JSON"

echo "✓ Data prepared: $OUTPUT_JSON"
echo ""

# ============================================================================
# Display Summary
# ============================================================================

jq -r '
"Summary:",
"  CVE topics: \(.cve_topics | length)",
"  Non-CVE topics: \(.non_cve_topics | length)",
"  Total non-CVE issues: \(.statistics.non_cve_total)",
"  Blockers: \(.statistics.non_cve_blocker)",
"  Majors: \(.statistics.non_cve_major)",
"",
"Recommendation:",
"  Release type: \(.recommendation.release_type)",
"  Reason: \(.recommendation.reason)",
"  Suggested issues: \(.recommendation.suggested_non_cve_issues | length)"
' "$OUTPUT_JSON"
