# Pipeline-Patcher Deny Rule Gap

## Problem

`pipeline-patcher bump-task-refs` only checks whether a task's current SHA is in
`data-acceptable-bundles` (trusted). It does not check EC deny rules from
`redhat-konflux/policy-data`. A task version can be trusted (SHA in the allowed
list) while simultaneously being denied (version below the deny rule minimum).

**Concrete example (2026-08-27):**

`task-prefetch-dependencies-oci-ta:0.3@sha256:92956e75` — trusted in
`data-acceptable-bundles`, but denied by:

```json
{
  "effective_on": "2026-08-13T06:00:00Z",
  "pattern": "oci://quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta",
  "versions": ["<0.7.1"]
}
```

The patcher found a valid SHA for `0.3`, declared it current, and made no change.
EC then failed with `trusted_task.trusted` / `deny_rule` on every FBC pipeline.
The fix required a manual PR bumping `0.3 → 0.10.1` in all 14 FBC `.tekton/` files.

## Fix Design

Add a post-patcher deny-rule check in both `tekton-task-refs-update.sh` and
`tekton-task-version-bump.sh`, called after `pipeline-patcher` runs but before
`git diff --cached --quiet`.

### Steps

1. **Fetch deny rules** from `quay.io/redhat-konflux/policy-data:latest` via `oras`:

   ```bash
   oras pull quay.io/redhat-konflux/policy-data:latest -o /tmp/policy-data/
   # Parses: .rule_data.trusted_task_rules.deny.konflux-defaults[]
   # Each entry: {pattern, versions: ["<X.Y.Z"], effective_on?}
   ```

2. **Filter to active deny rules** (effective_on ≤ today or absent).

3. **Scan `.tekton/` files** for each denied task pattern at a version below
   the minimum. Parse `quay.io/.../task-NAME:VERSION@sha256:SHA` refs.

4. **Find minimum non-denied version** from `data-acceptable-bundles` trusted
   list: find all trusted entries for that task at version `≥ min_version`, pick
   the highest.

5. **Sed in place**: replace the old `NAME:VERSION@SHA` with the new one in all
   matching `.tekton/` files.

6. **Re-stage**: `git add .tekton/` picks up the additional changes before the
   diff check and commit.

### Version Comparison

Deny rules use semver-style `<X.Y.Z`. Task versions in the catalog use formats
like `0.3`, `0.10.1`, `0.10.0-1787122491`. Need semver comparison that handles:

- `0.3` vs `0.7.1` (pad to `0.3.0`)
- `0.10.0` vs `0.9.0` (numeric, not lexicographic — `10 > 9`)
- Ignore build suffixes (`0.10.0-1787122491` → `0.10.0`)

### Implementation Location

New function `_apply_deny_rule_bumps()` in a shared lib or inlined into each
script, called after the patcher runs:

```bash
# In update_repo() / process_repo(), after pipeline-patcher:
patcher_out=$(printf '%s' "$PATCHER_SCRIPT" | bash -s bump-task-refs 2>&1)
_apply_deny_rule_bumps  # new: fix versions below deny rule minimums
git add .tekton/
if git diff --cached --quiet; then ...
```

### Notes

- `oras` is already a required prereq (used by pipeline-patcher itself)
- `redhat-konflux/policy-data:latest` is public (no auth needed)
- Only `konflux-defaults` deny group is relevant for our pipelines
- Should warn (not fail) if policy-data fetch fails — don't block the bump
- The data-acceptable-bundles digest used for the trusted SHA lookup should be
  the same one already fetched by pipeline-patcher (or re-fetch latest)

## Current Fix (0.24)

PR opened to add Submariner 0.24 to the exception list:
<https://github.com/release-engineering/rhtap-ec-policy/pull/268>

PR #4222 on submariner-operator (adding NetworkPolicy RBAC) should be closed —
adding RBAC for something the operator doesn't do is the wrong fix.

## Files to Change

- `scripts/tekton-task-refs-update.sh` — post-patcher deny check in `update_repo()`
- `scripts/tekton-task-version-bump.sh` — same, in `process_repo()`
- Possibly extract shared logic to `scripts/lib/pipeline-patcher.sh` or a new
  `scripts/lib/deny-rule-check.sh`
