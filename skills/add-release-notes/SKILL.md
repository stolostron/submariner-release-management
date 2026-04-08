---
name: add-release-notes
description: Add release notes from Jira, then per-issue agent review
version: 3.0.0
argument-hint: "<version> [--stage-yaml PATH]"
user-invocable: true
allowed-tools: Bash, Read
---

# Add Release Notes

Auto-apply ALL filtered Jira issues to stage YAML, then spawn per-issue
agents to review each issue and remove any that don't belong.

**Arguments:** $ARGUMENTS

## Workflow

1. **Collect** — query Jira for CVE and non-CVE issues
2. **Filter** — exclude published issues, invalid resolutions, Z-stream date filter
3. **Auto-apply** — include ALL filtered issues in stage YAML and commit
4. **Verify CVEs** — check Clair reports for CVE fixes (if CVEs present)
5. **Per-issue review** — one agent per issue verifies it belongs, removes with justification if not

---

```bash
set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO" ]; then
  echo "❌ ERROR: Not in a git repository"
  exit 1
fi

echo "Phases 1-4: Collect, filter, auto-apply, verify CVEs..."
bash "$REPO/scripts/add-release-notes.sh" $ARGUMENTS

echo ""
echo "Phase 5: Per-issue agent review..."
bash "$REPO/scripts/release-notes/review.sh" $ARGUMENTS

echo ""
echo "Done. Review removals: git log --oneline"
echo "Push when satisfied: git push"
```
