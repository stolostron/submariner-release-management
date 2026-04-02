---
name: add-release-notes
description: Query Jira for CVEs and issues, use AI to select notable items, update stage YAML
version: 2.0.0
argument-hint: "<version> [--stage-yaml PATH]"
user-invocable: true
allowed-tools: Bash, Read, Write
---

# Add Release Notes

Query Jira for CVEs and issues, use AI to select notable items, update stage YAML.

**Arguments:** $ARGUMENTS

---

```bash
set -euo pipefail

# Find repository root
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO" ]; then
  echo "❌ ERROR: Not in a git repository"
  exit 1
fi

echo "Phase 1: Collecting data from Jira..."
bash "$REPO/scripts/release-notes/collect.sh" $ARGUMENTS

echo ""
echo "Phase 2: Filtering and grouping issues..."
bash "$REPO/scripts/release-notes/prepare.sh"

echo ""
echo "Data ready for AI analysis."
echo "Topics file: /tmp/release-notes-topics.json"
```

---

## Phase 3: Analyze issues and make decisions

Read `/tmp/release-notes-topics.json` and make release note decisions.

**Your task:**

1. **Review CVE topics** - all CVEs are auto-included (verify they make sense)
2. **Select notable non-CVE issues** - choose 3-8 issues that are:
   - User-facing (not internal refactoring)
   - Fixed (status=Closed, resolution=Done)
   - Important (Blocker/Critical/Major priority OR significant features)
3. **Confirm release type**:
   - RHSA if CVEs present (required)
   - RHBA for bug fixes (no CVEs)
   - RHEA for enhancements (no CVEs)
4. **Write rationale** - explain why each issue is notable (1 sentence)

**Selection criteria:**

- Include: Customer-facing fixes, major features, performance improvements, security fixes
- Exclude: Internal changes, test-only updates, minor refactors, Won't Do resolutions

**Output:** Use the Write tool to create `/tmp/release-notes-decisions.json`:

```json
{
  "metadata": {
    "version": "X.Y.Z",
    "analyzed_at": "ISO-8601 timestamp",
    "analyzer": "claude-sonnet-4-5"
  },
  "release_type": "RHSA|RHBA|RHEA",
  "release_type_rationale": "Why this type (1 sentence)",
  "non_cve_issues": {
    "selected": [
      {
        "issue_key": "ACM-XXXXX",
        "rationale": "Why include (1 sentence)"
      }
    ]
  }
}
```

**Notes:**

- CVE issues are auto-included from `data.json` (no need to list in decisions)
- Review CVE topics in `topics.json` to verify they make sense
- Only select notable non-CVE issues for `selected` array
- Use Write tool to create the file (do NOT output text directly)

---

```bash
set -euo pipefail

# Find repository root
REPO=$(git rev-parse --show-toplevel 2>/dev/null)

echo ""
echo "Phase 4: Applying decisions to stage YAML..."
bash "$REPO/scripts/release-notes/apply.sh"

echo ""
echo "✓ Release notes applied and committed."
echo ""
echo "Next steps:"
echo "  1. Review: git show"
echo "  2. Push: git push"
```
