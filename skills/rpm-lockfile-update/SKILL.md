---
name: rpm-lockfile-update
description: Update RPM lockfiles across Submariner repositories
version: 2.0.0
argument-hint: "[branch] [repo|component]"
user-invocable: true
allowed-tools: Bash
---

# RPM Lockfile Update

Regenerates RPM lockfiles in submariner and shipyard repositories by creating fix branches, running hermetic builds,
and committing updated lockfiles.

```bash
/rpm-lockfile-update                             # Auto-detect branch, all repos
/rpm-lockfile-update 0.21                        # Explicit branch, all repos
/rpm-lockfile-update gateway                     # Auto-detect branch, gateway only
/rpm-lockfile-update 0.21 submariner             # Explicit branch, repo filter
make rpm-lockfile-update                         # Auto-detect branch
make rpm-lockfile-update COMPONENT=gateway       # Auto-detect, component filter
make rpm-lockfile-update BRANCH=0.21 COMPONENT=gateway  # Explicit branch
```

**Filter options:** all, submariner, shipyard, gateway, globalnet, route-agent, nettest

**Requirements:** Red Hat entitlements, `podman login registry.redhat.io`, `gh auth login`, Bash 4.0+

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
if [ ! -x "$GIT_ROOT/scripts/rpm-lockfile-update.sh" ]; then
  echo "❌ Orchestrator script not found: scripts/rpm-lockfile-update.sh"
  exit 1
fi

# Delegate to orchestrator (passes all arguments)
exec "$GIT_ROOT/scripts/rpm-lockfile-update.sh" $ARGUMENTS
```
