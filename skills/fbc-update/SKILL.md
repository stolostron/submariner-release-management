---
name: fbc-update
description: Update FBC catalog with bundle from Konflux snapshot - automates scenario detection, template updates, catalog rebuild, and verification
version: 1.0.0
argument-hint: "<version> [--snapshot name] [--replace old-version]"
user-invocable: true
allowed-tools: [Bash]
---

# FBC Update Skill

Automates FBC (File-Based Catalog) updates for Submariner releases.

## Usage

```bash
/fbc-update <version> [--snapshot name] [--replace old-version]

# Examples:
/fbc-update 0.22.1                                  # UPDATE scenario (most common)
/fbc-update 0.22.0                                  # ADD scenario (new Y-stream)
/fbc-update 0.21.2 --replace 0.21.1                 # REPLACE scenario
/fbc-update 0.22.1 --snapshot submariner-0-22-xxxxx # Explicit snapshot
```

## Arguments

- `<version>` - Version to update (e.g., `0.22.1`)
- `--snapshot <name>` - Optional: Specific snapshot (default: latest passing)
- `--replace <old-version>` - Optional: Old version to replace (REPLACE scenario)

## Prerequisites

- oc login to Konflux cluster
- FBC repository at ~/konflux/submariner-operator-fbc

---

```bash
#!/bin/bash
set -euo pipefail

# Validate prerequisites
if ! oc auth can-i get snapshots -n submariner-tenant 2>/dev/null; then
  echo "❌ ERROR: Not logged into Konflux cluster"
  echo "Run: oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/"
  exit 1
fi

# Parse arguments
VERSION=""
SNAPSHOT=""
REPLACE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --replace) REPLACE="$2"; shift 2 ;;
    -*) echo "❌ ERROR: Unknown flag: $1"; exit 1 ;;
    *) VERSION="$1"; shift ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "❌ ERROR: Version required"
  echo ""
  echo "Examples:"
  echo "  /fbc-update 0.22.1"
  echo "  /fbc-update 0.22.0"
  echo "  /fbc-update 0.21.2 --replace 0.21.1"
  exit 1
fi

# Navigate to FBC repo
FBC_REPO="$HOME/konflux/submariner-operator-fbc"
if [ ! -d "$FBC_REPO" ]; then
  echo "❌ ERROR: FBC repository not found at $FBC_REPO"
  exit 1
fi

cd "$FBC_REPO"

# Check git status
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "❌ ERROR: FBC repository has uncommitted changes"
  echo "Run: git status"
  exit 1
fi

# Build make command
MAKE_CMD="make update-bundle VERSION=$VERSION"
[ -n "$SNAPSHOT" ] && MAKE_CMD="$MAKE_CMD SNAPSHOT=$SNAPSHOT"
[ -n "$REPLACE" ] && MAKE_CMD="$MAKE_CMD REPLACE=$REPLACE"

# Execute update
echo "🚀 Executing: $MAKE_CMD"
echo ""
exec $MAKE_CMD
```
