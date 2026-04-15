---
name: konflux-bundle-setup
description: Automate Konflux bundle setup on new release branches - configures Tekton pipelines for bundle builds including infrastructure, OLM annotations, hermetic builds, and multi-platform support
version: 2.0.0
argument-hint: "[version]"
user-invocable: true
allowed-tools: Bash
---

# Konflux Bundle Setup

Automate the setup of Konflux CI/CD bundle builds on new release branches for Submariner.

**What this skill does:** Copies bundle infrastructure from previous release, adds OLM annotations,
configures hermetic builds, multi-platform support, file change filters, and updates task references.
Creates 6-9 commits.

**Usage:**

```bash
/konflux-bundle-setup              # Auto-detect version from branch
/konflux-bundle-setup 0.23         # Specify version explicitly
make konflux-bundle-setup VERSION=0.23
```

**Requirements:** `~/go/src/submariner-io/submariner-operator` must exist. Auto-navigates if needed.

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
if [ ! -x "$GIT_ROOT/scripts/konflux-bundle-setup.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/konflux-bundle-setup.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/konflux-bundle-setup.sh" $ARGUMENTS
```
