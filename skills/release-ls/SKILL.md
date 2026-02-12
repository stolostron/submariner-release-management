---
name: release-ls
description: Check Submariner release status across 20 workflow steps - shows completed phases, current blockers, and next actions. Use when checking release progress, verifying builds, or debugging failed releases.
version: 1.0.0
argument-hint: "[version]"
user-invocable: true
allowed-tools: Bash, Read
---

# Usage

```bash
/release-ls 0.22.0
```

**Requires:** `oc login`

```bash
~/konflux/submariner-release-management/scripts/release-status.sh $ARGUMENTS
```
