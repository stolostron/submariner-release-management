---
name: add-release-notes
description: Add Jira-sourced release notes to component stage release YAML - automates CVE and issue queries, filtering, and YAML updates
version: 1.0.0
argument-hint: "<version> [--stage-yaml path]"
user-invocable: true
allowed-tools: Bash
---

# Add Release Notes

Automates Step 9 of the Submariner release workflow: adding Jira-sourced release notes to component stage release YAMLs.

**What it does:**

1. Validates prerequisites (jira-cli, JIRA_API_TOKEN, oc, jq, yq)
2. Finds latest stage YAML (or uses --stage-yaml path)
3. Queries Jira for CVE issues (automatic inclusion)
4. Queries Jira for non-CVE issues (user selection)
5. Filters out issues already in previous releases
6. Maps component names (Jira pscomponent → Konflux component)
7. Builds releaseNotes YAML section with proper formatting
8. Updates stage YAML file
9. Validates changes (make yamllint, make test)
10. Commits with descriptive message

**Usage:**

```bash
/add-release-notes 0.22.1                    # Auto-find latest stage YAML
/add-release-notes 0.22                      # Auto-expands to 0.22.0
/add-release-notes 0.22.1 --stage-yaml releases/0.22/stage/submariner-0-22-1-stage-20260316-01.yaml
```

**Prerequisites:**

- jira-cli installed: `go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest`
- JIRA_API_TOKEN in ~/.zshrc: `export JIRA_API_TOKEN="your-token"`
- Jira init: `jira init --installation local --auth-type bearer \
  --server https://issues.redhat.com --login rhn-support-tiwillia --project ACM --board none`
- oc login (for release date lookups)
- Step 8 complete (stage YAML with placeholder release notes)

**Arguments:** $ARGUMENTS

---

```bash
#!/bin/bash
set -euo pipefail

# Find git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "❌ ERROR: Not in a git repository"
  exit 1
fi

# Verify orchestrator script exists
if [ ! -x "$GIT_ROOT/scripts/add-release-notes.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/add-release-notes.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/add-release-notes.sh" $ARGUMENTS
```
