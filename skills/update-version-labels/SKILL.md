---
name: update-version-labels
description: Update Konflux Dockerfile version labels across Submariner repositories
version: 1.0.0
argument-hint: "<version> [repo]"
user-invocable: true
allowed-tools: Bash
---

# Update Version Labels

Updates Dockerfile `version` labels across 5 upstream repos (9 Dockerfiles) so Konflux's `{{ labels.version }}` tag
expansion produces correct image tags. Required for Z-stream releases before cutting upstream release.

```bash
/update-version-labels 0.23.1                    # All 5 repos
/update-version-labels 0.23.1 subctl             # Single repo
make update-version-labels VERSION=0.23.1        # All 5 repos
make update-version-labels VERSION=0.23.1 REPO=subctl  # Single repo
```

**Repos:** submariner-operator, submariner, lighthouse, shipyard, subctl

**Requirements:** `git`, SSH key for git fetch

**Arguments:** $ARGUMENTS

---

```bash
#!/bin/bash
set -euo pipefail

# Find git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "❌ Not in a git repository"
  exit 1
fi

# Verify orchestrator script exists
if [ ! -x "$GIT_ROOT/scripts/update-version-labels.sh" ]; then
  echo "❌ Orchestrator script not found: scripts/update-version-labels.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/update-version-labels.sh" $ARGUMENTS
```
