---
name: create-component-release
description: Create component release (stage or prod) with comprehensive verification
version: 2.0.0
argument-hint: "<version> [stage|prod]"
user-invocable: true
allowed-tools: Bash
---

# Create Component Release

Automates Step 8 (stage) and Step 15 (prod) of the Submariner release workflow.

**What it does:**

- Verifies latest component snapshot (event type, tests, 9 components)
- Generates 1 Release YAML (stage or prod)
- Validates YAML with make test-remote
- Automatically commits with descriptive message

**Usage:**

```bash
/create-component-release 0.22.1          # Stage (default)
/create-component-release 0.22.1 stage    # Stage (explicit)
/create-component-release 0.22.1 prod     # Prod (copies stage notes)
/create-component-release 0.22            # Auto-expands to 0.22.0
```

**Prerequisites:**

- oc login (required for snapshot queries)
- **For stage:** Step 7 complete (bundle SHAs updated)
- **For prod:** Stage YAML exists with release notes (Steps 8-9 complete)

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
if [ ! -x "$GIT_ROOT/scripts/create-component-release.sh" ]; then
  echo "❌ ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/create-component-release.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/create-component-release.sh" $ARGUMENTS
```
