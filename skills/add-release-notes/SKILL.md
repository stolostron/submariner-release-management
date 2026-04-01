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
REPO="/home/dfarrell07/konflux/submariner-release-management"

# Phase 1: Collect raw data from Jira
bash "$REPO/scripts/release-notes/collect.sh" $ARGUMENTS

# Phase 2: Group and prepare for analysis
bash "$REPO/scripts/release-notes/prepare.sh"

echo "Data collected and grouped. Ready for AI analysis."
```

---

Read `/tmp/release-notes-topics.json` and make release note decisions.

**Your task:**
1. **Review CVE topics** - all CVEs are auto-included (verify they make sense)
2. **Select notable non-CVE issues** - choose 3-8 issues that are:
   - User-facing (not internal refactoring)
   - Fixed (status=Closed, resolution=Done)
   - Important (Blocker/Major priority OR significant features)
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
    "analyzer": "claude-sonnet-4.5"
  },
  "release_type": "RHSA|RHBA|RHEA",
  "release_type_rationale": "Why this type",
  "cve_issues": {
    "all_included": true,
    "issue_keys": ["ACM-XXXXX", ...]
  },
  "non_cve_issues": {
    "selected": [
      {
        "issue_key": "ACM-XXXXX",
        "rationale": "Why include (1 sentence)"
      }
    ],
    "rejected": [
      {
        "issue_key": "ACM-YYYYY",
        "rationale": "Why exclude (1 sentence)"
      }
    ]
  }
}
```

**CRITICAL:** Use the Write tool. Do NOT output text directly.

---

```bash
# Phase 3: Apply decisions to stage YAML
bash "$REPO/scripts/release-notes/apply.sh"

echo "✓ Release notes applied. Review and push when ready."
```
