---
name: configure-downstream
description: Configure Konflux for new Submariner version - creates overlays, tenant config, and RPAs for Y-stream releases.
version: 1.0.0
argument-hint: "<new-version>"
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# Configure Downstream Release

Configures Konflux CI/CD for a new Submariner minor version (Y-stream releases).

**Usage:**

```bash
/configure-downstream 0.23
/configure-downstream 0.23.0  # Extracts major.minor automatically
```

**What it does:**

- Auto-detects previous version from existing overlays
- Creates feature branch (subm-configure-v0.23) from main
- Creates 3 commits with 49 total files:
  - Commit 1: 26 YAML overlay files
  - Commit 2: 22 auto-generated Kustomize manifests
  - Commit 3: 2 ReleasePlanAdmission files (stage + prod)
- Verifies all changes before committing
- Outputs push command and MR instructions

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
if [ ! -x "$GIT_ROOT/scripts/configure-downstream.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/configure-downstream.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/configure-downstream.sh" $ARGUMENTS
```
