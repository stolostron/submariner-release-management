---
name: konflux-component-setup
description: Automate Konflux component setup on new release branches - configures Tekton pipelines, Dockerfiles, RPM lockfiles, and hermetic builds for Submariner components. Supports 8 component types. Arguments are optional and order-independent.
version: 2.0.0
argument-hint: "[repo-shortcut] [component-name] [version]"
user-invocable: true
allowed-tools: Bash
context: fork
---

# Konflux Component Setup

Automate the setup of Konflux CI/CD builds on new release branches for Submariner components.

**Handles 8 components** across 5 repositories (NOT bundle):

| Repository          | Component(s)                                                     |
|---------------------|------------------------------------------------------------------|
| submariner-operator | submariner-operator                                              |
| submariner          | submariner-gateway, submariner-globalnet, submariner-route-agent |
| lighthouse          | lighthouse-agent, lighthouse-coredns                             |
| shipyard            | nettest                                                          |
| subctl              | subctl                                                           |

**Usage:**

```bash
/konflux-component-setup operator 0.23
/konflux-component-setup submariner submariner-gateway 0.23
/konflux-component-setup lighthouse lighthouse-agent 0.23
/konflux-component-setup                   # Auto-detect from branch
make konflux-component-setup REPO=operator VERSION=0.23
```

**Shortcuts:** operator, submariner, lighthouse, shipyard, subctl

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
if [ ! -x "$GIT_ROOT/scripts/konflux-component-setup.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/konflux-component-setup.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/konflux-component-setup.sh" $ARGUMENTS
```
