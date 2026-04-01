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

1. Validates prerequisites (acli, oc, jq, yq)
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

# Or using make:
make add-release-notes VERSION=0.22.1
make add-release-notes VERSION=0.22.1 STAGE_YAML=releases/0.22/stage/submariner-0-22-1-stage-20260316-01.yaml
```

**Prerequisites:**

- acli (Atlassian CLI) installed and authenticated
- Authentication: `acli jira auth login --web` (or with API token)
- Verify: `acli jira auth status` should show "Authenticated"
- oc login (for release date lookups)
- Step 8 complete (stage YAML with placeholder release notes)

```bash
~/konflux/submariner-release-management/scripts/add-release-notes.sh $ARGUMENTS
```
