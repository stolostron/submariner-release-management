---
name: add-fbc-ocp-version
description: Add FBC support for new OCP version in Konflux release data - creates overlays, tenant config, and RPA entries.
version: 1.0.0
argument-hint: "<ocp-version> <min-submariner-version>"
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# Add FBC OCP Version

Adds FBC (File-Based Catalog) support for a new OCP version in Konflux release data.

**Usage:**

```bash
/add-fbc-ocp-version 4.22 0.23
/add-fbc-ocp-version 4-22 0.23  # Hyphenated format also accepted
```

**What it does:**

- Auto-detects previous OCP version from existing overlays
- Creates feature branch (subm-fbc-configure-4-22) from main
- Creates 3 commits:
  - Commit 1: 8 YAML overlay files (FBC overlay structure)
  - Commit 2: 7 auto-generated Kustomize manifests + kustomization.yaml
  - Commit 3: 2 FBC RPA files updated (applications list)
- Verifies all changes before committing
- Outputs push command, MR instructions, and Phase 2 instructions

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
if [ ! -x "$GIT_ROOT/scripts/add-fbc-ocp-version.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/add-fbc-ocp-version.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/add-fbc-ocp-version.sh" $ARGUMENTS
```
