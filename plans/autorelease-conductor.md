# Autorelease Conductor

Design plan for `/autorelease <version>` — a skill that finds the next ready release step
and runs it. One step per invocation. Re-run to advance.

Version 1.1 — 2026-08-01 (revised after 20-agent review)

## Problem

The release engineer manually runs `/release-ls`, reads "NEXT STEPS", picks the right
skill, runs it, repeats 15-19 times per release. The conductor automates this:
find next ready step → run it → stop.

## Prerequisites

**This work depends on PR #89** (Jira release tracker). The conductor uses `jira-tracker.sh`
constants (`STEP_ORDER`, `STEP_DEPENDENCIES`, `AUTOMATION_LEVEL`) and functions
(`get_step`, `find_release_tracker`). The conductor branch must be based on the
tracker branch, not main.

## Design

**Per invocation:**

1. Source `jira-tracker.sh`, find tracker for `$VERSION`
2. If no tracker: exit with "run `/create-release-tracker $VERSION` first"
3. Walk `STEP_ORDER`, skip non-applicable steps (Y/Z stream filtering)
4. For each step: check if done (`get_step` → status=complete), check deps
5. Find first step where all deps are complete but step is not done
6. Dispatch based on automation level + script availability:
   - Has backing script → run it, report result, stop
   - No script but has skill name → print "run `/skill-name` manually", stop
   - Gate (empty skill) → print what's blocking, stop
7. Stop after one step (user re-runs to advance)

**Architecture:** Pure script (`scripts/autorelease.sh`) + thin delegator SKILL.md.
The script exports `find_next_step()` as a testable function, separate from dispatch.

## Prerequisite DAG Fixes (jira-tracker.sh)

Three dependency fixes, plus new infrastructure:

### Fix 1: `versionLabels` must block `upstreamRelease`

```bash
["upstreamRelease"]="cveFixes,ecFixes,rpmLockfiles,tektonTasks,versionLabels"
```

### Fix 2: `cveFixes` level → `review`

```bash
["cveFixes"]="review"
```

### Fix 3: `componentStage` must depend on `releaseNotes`

```bash
["componentStage"]="bundleShas,releaseNotes"
```

### New: `ZSTREAM_STEPS` array + `step_applies_to_release()` helper

```bash
readonly ZSTREAM_STEPS=("versionLabels")

# Check if a step applies to the given release type
# Args: $1=step_key $2=release_type
# Returns: 0 if applicable, 1 if not
step_applies_to_release() {
  local step_key="$1" release_type="$2"
  if [ "$release_type" = "z-stream" ]; then
    for ys in "${YSTREAM_STEPS[@]}"; do
      [ "$step_key" = "$ys" ] && return 1
    done
  elif [ "$release_type" = "y-stream" ]; then
    for zs in "${ZSTREAM_STEPS[@]}"; do
      [ "$step_key" = "$zs" ] && return 1
    done
  fi
  return 0
}
```

Used by: conductor dep resolution, `create_release_tracker`, `get_release_summary`.

## Step-to-Script Mapping

The conductor dispatches to **scripts**, not skills. Skills that lack backing scripts
cannot be shell-dispatched — the conductor prints guidance instead.

```bash
# Scripts the conductor can execute directly
declare -A STEP_SCRIPT=(
  ["configureDownstream"]="scripts/configure-downstream.sh"
  ["rpmLockfiles"]="scripts/rpm-lockfile-update.sh"
  ["versionLabels"]="scripts/update-version-labels.sh"
  ["bundleShas"]="scripts/bundle-image-update.sh"
  ["componentStage"]="scripts/create-component-release.sh"
  ["releaseNotes"]="scripts/add-release-notes.sh"
  ["fbcStageReleases"]="scripts/create-fbc-releases.sh"
  ["componentProd"]="scripts/create-component-release.sh"
  ["fbcProdReleases"]="scripts/create-fbc-releases.sh"
)

# Skill names for guidance (shown when no script exists)
declare -A STEP_SKILL_HINT=(
  ["createBranches"]="See .agents/workflows/create-release-branch.md"
  ["tektonComponents"]="/konflux-component-setup"
  ["tektonBundle"]="/konflux-bundle-setup"
  ["cveFixes"]="See .agents/workflows/scan-cves.md"
  ["ecFixes"]="/konflux-ci-fix"
  ["tektonTasks"]="/konflux-ci-fix"
  ["upstreamRelease"]="See .agents/workflows/cut-upstream-release.md"
  ["fbcCatalogUpdate"]="/fbc-update"
  ["qeValidation"]="Share URLs with /get-fbc-urls, then await QE approval"
  ["fbcProdUrls"]="See .agents/workflows/update-fbc-templates-prod.md"
)

declare -A STEP_EXTRA_ARGS=(
  ["componentStage"]="stage"
  ["componentProd"]="prod"
  ["fbcStageReleases"]="--stage"
  ["fbcProdReleases"]="--prod"
)
```

Separation: `STEP_SCRIPT` = what the conductor can auto-run. `STEP_SKILL_HINT` = what to
tell the user when the conductor can't auto-run (agent-only skills, external repos, gates).

## Dep Resolution

When checking deps, use `step_applies_to_release()` to auto-satisfy deps that reference
steps not applicable to the current stream. This prevents Y-stream deadlock on
`versionLabels` and Z-stream deadlock on branch setup steps.

## Completion Detection (v1: Tracker-only)

`get_step` returns status. `"complete"` = done. Anything else (`"in_progress"`, empty) = not done.
Re-running the conductor re-checks and retries incomplete steps.

Steps without tracker integration (scripts that don't call `update_step`) will appear
permanently incomplete. These are all gate/manual steps where the conductor stops with
guidance anyway — the user manually marks them via the tracker or they're detected in v2
via infrastructure checks.

## What v1 Does NOT Do

- No multi-step advancement (one step per invocation)
- No apply step automation (`make apply` is manual)
- No `--dry-run` mode
- No staleness warnings
- No infrastructure fallback completion detection
- No cluster login pre-check

## Files

| File | Action | ~Lines |
| --- | --- | --- |
| `scripts/lib/jira-tracker.sh` | Fix 3 deps, add constants + helper | +55 |
| `scripts/lib/test-jira-tracker.sh` | Tests for new constants + dep fixes + `step_applies_to_release` | +35 |
| `scripts/autorelease.sh` | Create — `find_next_step()` + dispatch | ~70 |
| `scripts/lib/test-autorelease.sh` | Create — DAG walk tests with mocked `get_step` | ~60 |
| `skills/autorelease/SKILL.md` | Create — thin delegator | ~30 |
| `CLAUDE.md` | Add `/autorelease` reference | +3 |
| **Total** | | **~255** |

## Example Session (Z-stream 0.25.1)

```text
/autorelease 0.25.1

Submariner 0.25.1 (Z-stream)
Tracker: ACM-55000

  ✓ cveFixes: done
  ✓ ecFixes: done
  ✓ rpmLockfiles: done
  ✓ tektonTasks: done
  ✓ versionLabels: done

⏸ upstreamRelease: GATE
  All build-readiness steps complete.
  Cut the upstream release: see .agents/workflows/cut-upstream-release.md
  Re-run: /autorelease 0.25.1
```

After user cuts the release:

```text
/autorelease 0.25.1

  ✓ upstreamRelease: done
  → bundleShas: running scripts/bundle-image-update.sh 0.25.1...
    [script output]
  ✓ bundleShas: complete
  Re-run: /autorelease 0.25.1
```

Next invocation:

```text
/autorelease 0.25.1

  ✓ bundleShas: done
  → releaseNotes: running scripts/add-release-notes.sh 0.25.1... (review)
    [script output]
  ⏸ Review the release notes commit, then re-run: /autorelease 0.25.1
```

After review, componentStage deps (bundleShas + releaseNotes) are met:

```text
/autorelease 0.25.1

  ✓ releaseNotes: done
  → componentStage: running scripts/create-component-release.sh 0.25.1 stage...
    [script output]
  ✓ componentStage: complete
  Apply the release: make apply FILE=releases/0.25/stage/...
  Re-run: /autorelease 0.25.1
```

## Verification

```bash
make test-tracker      # Constant/dep fixes + step_applies_to_release
make test              # Full validation
scripts/lib/test-autorelease.sh  # DAG walk unit tests
/autorelease 0.25.1    # Live test on next release
```

## v2 Roadmap (deferred)

- Multi-step advancement (run consecutive auto steps without stopping)
- Auto-apply after create steps (`make apply` + non-blocking status check)
- `--dry-run` mode (show action plan without executing)
- Staleness warnings (advisory, from `check_freshness`)
- Infrastructure fallback completion detection (git tags, snapshots, YAMLs)
- Cluster login pre-check at conductor startup
