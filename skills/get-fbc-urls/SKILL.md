---
name: get-fbc-urls
description: Get FBC catalog URLs for QE sharing (Release CRs, snapshots, or prod index)
version: 2.0.0
argument-hint: "<version> [--ocp 4.XX] [--raw-url] [--prod-index]"
user-invocable: true
allowed-tools: Bash
---

# Get FBC URLs

Gets FBC catalog URLs for sharing with QE. Default mode extracts quay.io catalog URLs from Release CRs
on the cluster, falling back to snapshot lookup from local YAML files if Release CRs are garbage-collected.
Prod-index mode checks the Red Hat operator index at registry.redhat.io.

```bash
/get-fbc-urls 0.24.0                    # All OCP versions, full output
/get-fbc-urls 0.24.0 --ocp 4.21         # Single OCP version
/get-fbc-urls 0.24.0 --raw-url          # URLs only (for automation)
/get-fbc-urls 0.24.0 --prod-index       # Check prod operator index
/get-fbc-urls 0.24.0 --prod-index --raw-url  # Prod index URLs only
make get-fbc-urls VERSION=0.24.0        # Via make target
make get-fbc-urls VERSION=0.24.0 PROD_INDEX=true
```

**Requirements:** `oc login` (default mode), `skopeo` (prod-index mode)

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
if [ ! -x "$GIT_ROOT/scripts/get-fbc-urls.sh" ]; then
  echo "❌ Orchestrator script not found: scripts/get-fbc-urls.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/get-fbc-urls.sh" $ARGUMENTS
```
