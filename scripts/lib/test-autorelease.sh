#!/bin/bash
# Tests for autorelease DAG walk logic (sources the REAL find_next_step)
# Run: ./scripts/lib/test-autorelease.sh
# shellcheck disable=SC2034  # step_statuses is read by find_next_step as a global
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source jira-tracker.sh for constants + step_applies_to_release
unset _JIRA_TRACKER_SOURCED
source "$SCRIPT_DIR/jira-tracker.sh" 2>/dev/null || true

# Stub external calls
query_jira() { echo "[]"; }
acli() { :; }
# shellcheck disable=SC2034
calculate_acm_version() { ACM_VERSION="ACM 2.17.0"; }

# Source the real find_next_step (guarded by _AUTORELEASE_TESTING)
export _AUTORELEASE_TESTING=true
source "$SCRIPT_DIR/../autorelease.sh"

PASS=0 FAIL=0
assert_eq() {
  if [ "$2" = "$3" ]; then echo "  ✓ $1"; PASS=$((PASS + 1))
  else echo "  ✗ $1 (got: '$2', want: '$3')"; FAIL=$((FAIL + 1)); fi
}

echo "=== DAG Walk Tests (real find_next_step) ==="

# 1: Z-stream fresh → first no-dep step
declare -A step_statuses=()
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "z-stream fresh: cveFixes" "$NEXT_STEP" "cveFixes"

# 2: Build readiness partial → versionLabels next
step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "z-stream partial: versionLabels" "$NEXT_STEP" "versionLabels"

# 3: All upstream deps done → upstreamRelease
step_statuses[versionLabels]=complete
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "z-stream: upstreamRelease ready" "$NEXT_STEP" "upstreamRelease"

# 4: componentStage runs before releaseNotes (notes modify existing YAML)
step_statuses[upstreamRelease]=complete
step_statuses[bundleShas]=complete
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "componentStage before releaseNotes" "$NEXT_STEP" "componentStage"

# 5: After componentStage → releaseNotes (depends on componentStage)
step_statuses[componentStage]=complete
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "releaseNotes after componentStage" "$NEXT_STEP" "releaseNotes"

# 6: Y-stream starts with createBranches
declare -A step_statuses=()
find_next_step "0.99.0" "y-stream" "FAKE-123" 2>/dev/null
assert_eq "y-stream: createBranches first" "$NEXT_STEP" "createBranches"

# 7: Y-stream auto-satisfies versionLabels in upstreamRelease deps
step_statuses=([createBranches]=complete [configureDownstream]=complete [tektonComponents]=complete [tektonBundle]=complete [cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete)
find_next_step "0.99.0" "y-stream" "FAKE-123" 2>/dev/null
assert_eq "y-stream: upstreamRelease (vl skipped)" "$NEXT_STEP" "upstreamRelease"

# 8: All done
for step in "${STEP_ORDER[@]}"; do step_statuses[$step]=complete; done
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "all done" "$NEXT_STEP" ""
assert_eq "all done reason" "$NEXT_REASON" "all_done"

# 9: NEXT_REASON is correct for gate steps
declare -A step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete [versionLabels]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "gate step: upstreamRelease" "$NEXT_STEP" "upstreamRelease"
assert_eq "gate reason" "$NEXT_REASON" "gate"

# 10: NEXT_REASON is correct for hint steps (no script, has hint)
declare -A step_statuses=()
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "hint step: cveFixes" "$NEXT_STEP" "cveFixes"
assert_eq "hint reason (cveFixes has hint, no script)" "$NEXT_REASON" "hint"

# 11: NEXT_REASON="run" for steps with scripts
step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "run step: versionLabels (has script)" "$NEXT_STEP" "versionLabels"
assert_eq "run reason" "$NEXT_REASON" "run"

# 12: componentProd three-way join — blocked until all 3 deps satisfied
step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete [versionLabels]=complete [upstreamRelease]=complete [bundleShas]=complete [componentStage]=complete [releaseNotes]=complete [fbcCatalogUpdate]=complete [fbcStageReleases]=complete [qeValidation]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "componentProd ready (all 3 deps met)" "$NEXT_STEP" "componentProd"
assert_eq "componentProd reason" "$NEXT_REASON" "run"

# 13: componentProd blocked when releaseNotes incomplete
step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete [versionLabels]=complete [upstreamRelease]=complete [bundleShas]=complete [componentStage]=complete [fbcCatalogUpdate]=complete [fbcStageReleases]=complete [qeValidation]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "componentProd blocked (releaseNotes missing)" "$NEXT_STEP" "releaseNotes"

# 14: fbcCatalogUpdate after releaseNotes (both depend on componentStage)
step_statuses=([cveFixes]=complete [ecFixes]=complete [rpmLockfiles]=complete [tektonTasks]=complete [versionLabels]=complete [upstreamRelease]=complete [bundleShas]=complete [componentStage]=complete [releaseNotes]=complete)
find_next_step "0.99.1" "z-stream" "FAKE-123" 2>/dev/null
assert_eq "fbcCatalogUpdate after releaseNotes" "$NEXT_STEP" "fbcCatalogUpdate"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then echo "All $PASS tests passed"
else echo "$FAIL FAILED, $PASS passed"; fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ] || exit 1
