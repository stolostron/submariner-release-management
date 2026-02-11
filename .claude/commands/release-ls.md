---
description: Check Submariner release status across all workflow steps
argument-hint: <version>
---

# Submariner Release Status Checker

Check release status across all 20 workflow steps.

**Usage:** `/release-ls <version>`

**Examples:**

- `/release-ls 0.22.1` - Z-stream
- `/release-ls 0.22.0` - Y-stream

**Shows:**

- Phase and next steps
- Status with ✅/❌/⚠️/ℹ️
- Tags, builds, releases, FBC catalogs

**Note:** Requires `oc login` to Konflux cluster.
