---
name: bundle-image-update
description: Update bundle component image SHAs from Konflux snapshots - automates SHA extraction, config file updates, bundle regeneration, and verification
version: 1.0.0
argument-hint: "[X.Y|X.Y.Z] [--snapshot name]"
user-invocable: true
allowed-tools: Bash
---

# Bundle Image Update

Update bundle component image SHAs from Konflux snapshots.

**What this skill does:** Queries Konflux for latest passing snapshot, extracts 7 component SHAs,
updates config files, regenerates bundle with make bundle, updates Dockerfile labels (version bumps),
verifies all SHAs match, and creates a single commit.

**Usage:**

```bash
/bundle-image-update                              # Auto: latest snapshot, SHA-only
/bundle-image-update 0.21.2                       # Version bump to 0.21.2
/bundle-image-update --snapshot submariner-0-21-xxxxx  # Specific snapshot
make bundle-image-update VERSION=0.21.2
```

**Requirements:** `~/go/src/submariner-io/submariner-operator` must exist on a release branch.
Must be logged into Konflux cluster. Bash 4.0+.

**Arguments:** $ARGUMENTS

---

```bash
#!/bin/bash
set -euo pipefail

# Find git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "ERROR: Not in a git repository"
  exit 1
fi

# Verify orchestrator script exists
if [ ! -x "$GIT_ROOT/scripts/bundle-image-update.sh" ]; then
  echo "ERROR: Required orchestrator script not found"
  echo "This skill requires: scripts/bundle-image-update.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/bundle-image-update.sh" $ARGUMENTS
```
