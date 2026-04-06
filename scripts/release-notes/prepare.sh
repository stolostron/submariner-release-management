#!/bin/bash
# Phase 2: Filter and group release notes data
# Input: /tmp/release-notes-data.json
# Output: /tmp/release-notes-topics.json
set -euo pipefail

# ============================================================================
# Initialize
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/release-notes-common.sh
source "$LIB_DIR/release-notes-common.sh"

INPUT_JSON="/tmp/release-notes-data.json"
OUTPUT_JSON="/tmp/release-notes-topics.json"

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "❌ ERROR: Input file not found: '$INPUT_JSON'" >&2
  echo "Run collect.sh first" >&2
  exit 1
fi

banner "Filter and Group Release Notes Data"

# ============================================================================
# Filter and Group with jq
# ============================================================================
# Single jq pipeline to:
#   1. Filter issues by:
#      - Existing prod releases
#      - Invalid resolutions (Won't Do, Won't Fix, Duplicate, Cannot Reproduce)
#      - Resolution date (Z-streams: exclude issues resolved before last publish)
#   2. Group CVEs by CVE key (multiple issues can fix same CVE)
#   3. Categorize non-CVEs by pattern (connectivity, performance, features, bugs)
#   4. Calculate statistics (counts by priority)
#   5. Generate recommendation (RHSA if CVEs, else RHBA/RHEA)

jq '
# Extract metadata
.metadata as $meta |

# Extract existing issues array
.existing_issues as $existing |

# Define invalid resolutions to exclude
["Won\u0027t Do", "Won\u0027t Fix", "Duplicate", "Cannot Reproduce"] as $invalid_resolutions |

# Filter non-CVE issues
(
  .non_cve_issues | map(
    select(
      # Exclude existing issues (in prod releases)
      (.issue_key | IN($existing[]) | not) and
      # Exclude invalid resolutions
      (.resolution | IN($invalid_resolutions[]) | not) and
      # For Z-streams: exclude issues resolved before last published release
      # (these were likely fixed in pre-Konflux releases with no prod YAMLs)
      (if ($meta.last_published_date != "" and .resolved != "")
       then (.resolved >= $meta.last_published_date)
       else true
       end)
    )
  )
) as $filtered_non_cve |

# Filter CVE issues
(
  .cve_issues | map(
    select(
      # Exclude existing issues (in prod releases)
      (.issue_key | IN($existing[]) | not) and
      # For Z-streams: exclude issues resolved before last published release
      # (these were likely fixed in pre-Konflux releases with no prod YAMLs)
      (if ($meta.last_published_date != "" and .resolved != "")
       then (.resolved >= $meta.last_published_date)
       else true
       end)
    )
  )
) as $filtered_cve |

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

# Calculate statistics (single pass using group_by)
(
  ($filtered_non_cve | group_by(.priority) | map({key: .[0].priority, value: length}) | from_entries) as $priority_counts |
  ($filtered_cve | length) as $cve_count |
  {
    cve_count: $cve_count,
    non_cve_total: ($filtered_non_cve | length),
    non_cve_blocker: ($priority_counts.Blocker // 0),
    non_cve_critical: ($priority_counts.Critical // 0),
    non_cve_major: ($priority_counts.Major // 0)
  }
) as $statistics |

# Build recommendation
(
  {
    release_type: (if $statistics.cve_count > 0 then "RHSA" else "RHBA" end),
    reason: (
      if $statistics.cve_count > 0 then "CVEs present (RHSA required)"
      else "No CVEs (RHBA for bug fixes or RHEA for enhancements)"
      end
    ),
    suggested_non_cve_issues: (
      $filtered_non_cve |
      map(select(.priority | IN("Blocker", "Critical", "Major"))) |
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

# ============================================================================
# Display Summary
# ============================================================================

jq -r '
"Summary:",
"  CVE topics: \(.cve_topics | length)",
"  Non-CVE topics: \(.non_cve_topics | length)",
"  Total non-CVE issues: \(.statistics.non_cve_total)",
"  Blockers: \(.statistics.non_cve_blocker)",
"  Criticals: \(.statistics.non_cve_critical)",
"  Majors: \(.statistics.non_cve_major)",
"",
"Recommendation:",
"  Release type: \(.recommendation.release_type)",
"  Reason: \(.recommendation.reason)",
"  Suggested issues: \(.recommendation.suggested_non_cve_issues | length)"
' "$OUTPUT_JSON"
