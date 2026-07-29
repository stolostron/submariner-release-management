#!/bin/bash
# Tests for scripts/lib/jira-tracker.sh
# Run: make test-tracker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library (once — readonly arrays crash on re-source)
unset _JIRA_TRACKER_SOURCED
source "$SCRIPT_DIR/jira-tracker.sh"

# Stub external calls
query_jira() { echo "[]"; }
acli() { :; }
# shellcheck disable=SC2034  # ACM_VERSION used by library after mock returns
calculate_acm_version() { ACM_VERSION="ACM 2.17.0"; }

# Assertion helpers
PASS=0 FAIL=0
assert_eq() {
  if [ "$2" = "$3" ]; then echo "  ✓ $1"; PASS=$((PASS + 1))
  else echo "  ✗ $1 (got: '$2', want: '$3')"; FAIL=$((FAIL + 1)); fi
}
# ============================================================================
echo "=== 1. Input Validation ==="
# ============================================================================

# _normalize_version
assert_eq "normalize 2-seg" "$(_normalize_version "0.24")" "0.24.0"
assert_eq "normalize 3-seg unchanged" "$(_normalize_version "0.24.1")" "0.24.1"
assert_eq "normalize empty" "$(_normalize_version "")" ""

# Valid versions
_validate_version "0.24.0" 2>/dev/null && rc=0 || rc=$?
assert_eq "0.24.0 valid" "$rc" "0"

_validate_version "0.0.0" 2>/dev/null && rc=0 || rc=$?
assert_eq "0.0.0 valid" "$rc" "0"

# Invalid versions
_validate_version "0.24" 2>/dev/null && rc=0 || rc=$?
assert_eq "0.24 rejected (2-segment)" "$rc" "1"

_validate_version "" 2>/dev/null && rc=0 || rc=$?
assert_eq "empty rejected" "$rc" "1"

_validate_version "v0.24.0" 2>/dev/null && rc=0 || rc=$?
assert_eq "v-prefix rejected" "$rc" "1"

_validate_version "0.24.0-rc1" 2>/dev/null && rc=0 || rc=$?
assert_eq "suffix rejected" "$rc" "1"

_validate_version "0.24.0.1" 2>/dev/null && rc=0 || rc=$?
assert_eq "4-segment rejected" "$rc" "1"

# ============================================================================
echo ""
echo "=== 2. Constants ==="
# ============================================================================

assert_eq "STEP_ORDER has 19 entries" "${#STEP_ORDER[@]}" "19"
assert_eq "YSTREAM_STEPS has 4 entries" "${#YSTREAM_STEPS[@]}" "4"

# Every STEP_ORDER key in STEP_TITLES and STEP_PHASE
missing_titles=0 missing_phases=0
for key in "${STEP_ORDER[@]}"; do
  [ -z "${STEP_TITLES[$key]:-}" ] && missing_titles=$((missing_titles + 1))
  [ -z "${STEP_PHASE[$key]:-}" ] && missing_phases=$((missing_phases + 1))
done
assert_eq "all STEP_ORDER keys in STEP_TITLES" "$missing_titles" "0"
assert_eq "all STEP_ORDER keys in STEP_PHASE" "$missing_phases" "0"

# YSTREAM_STEPS subset of STEP_ORDER
ys_missing=0
for ys in "${YSTREAM_STEPS[@]}"; do
  found=false
  for key in "${STEP_ORDER[@]}"; do [ "$key" = "$ys" ] && found=true && break; done
  [ "$found" = "false" ] && ys_missing=$((ys_missing + 1))
done
assert_eq "YSTREAM_STEPS subset of STEP_ORDER" "$ys_missing" "0"

# Dependency values reference valid step keys
dep_invalid=0
for step in "${!STEP_DEPENDENCIES[@]}"; do
  deps="${STEP_DEPENDENCIES[$step]:-}"
  [ -z "$deps" ] && continue
  IFS="," read -ra dep_arr <<< "$deps"
  for dep in "${dep_arr[@]}"; do
    found=false
    for sk in "${STEP_ORDER[@]}"; do [ "$sk" = "$dep" ] && found=true && break; done
    [ "$found" = "false" ] && dep_invalid=$((dep_invalid + 1))
  done
done
assert_eq "dependency values are valid step keys" "$dep_invalid" "0"

# AUTOMATION_LEVEL values
al_invalid=0
for step in "${STEP_ORDER[@]}"; do
  level="${AUTOMATION_LEVEL[$step]:-}"
  case "$level" in auto|review|gate) ;; *) al_invalid=$((al_invalid + 1)) ;; esac
done
assert_eq "AUTOMATION_LEVEL values valid" "$al_invalid" "0"

# ============================================================================
echo ""
echo "=== 3. Subtask Counts ==="
# ============================================================================

export JIRA_TRACKER_DRY_RUN=true
query_jira() { echo "[]"; }
# shellcheck disable=SC2034  # ACM_VERSION used by library after mock returns
calculate_acm_version() { ACM_VERSION="ACM 2.17.0"; }

# Y-stream: 19 subtasks
output=$(create_release_tracker "0.24.0" 2>&1 >/dev/null)
count=$(printf '%s' "$output" | grep -c "Would create: Sub-task" || true)
assert_eq "y-stream: 19 subtasks" "$count" "19"

# Z-stream: 15 subtasks
output=$(create_release_tracker "0.24.1" 2>&1 >/dev/null)
count=$(printf '%s' "$output" | grep -c "Would create: Sub-task" || true)
assert_eq "z-stream: 15 subtasks" "$count" "15"

# Idempotent: existing tracker returns key, no subtasks
query_jira() { echo '[{"key":"ACM-EXISTING"}]'; }
key=$(create_release_tracker "0.24.0" 2>/dev/null)
assert_eq "idempotent: returns existing key" "$key" "ACM-EXISTING"

unset JIRA_TRACKER_DRY_RUN
query_jira() { echo "[]"; }

# ============================================================================
echo ""
echo "=== 4. check_freshness ==="
# ============================================================================

# Save original get_step before overriding
_SAVED_GET_STEP=$(declare -f get_step)

# No staleness rule
result=$(check_freshness "0.24.0" "createBranches" "ACM-99" 2>/dev/null)
assert_eq "no rule: fresh" "$result" "fresh"

# Time-based: 1 day ago, 3-day rule → fresh
get_step() {
  local ts
  ts=$(date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ")
  printf '%s' "{\"_t\":\"STEP_DATA\",\"step\":\"cveFixes\",\"timestamp\":\"$ts\",\"status\":\"complete\",\"data\":{}}"
}
result=$(check_freshness "0.24.0" "cveFixes" "ACM-99" 2>/dev/null)
assert_eq "1d ago, 3d rule: fresh" "$result" "fresh"

# Time-based: 5 days ago, 3-day rule → stale
get_step() {
  local ts
  ts=$(date -u -d "5 days ago" +"%Y-%m-%dT%H:%M:%SZ")
  printf '%s' "{\"_t\":\"STEP_DATA\",\"step\":\"cveFixes\",\"timestamp\":\"$ts\",\"status\":\"complete\",\"data\":{}}"
}
result=$(check_freshness "0.24.0" "cveFixes" "ACM-99" 2>/dev/null)
assert_eq "5d ago, 3d rule: stale" "$result" "stale"

# Status in_progress → fresh
get_step() {
  printf '%s' '{"_t":"STEP_DATA","step":"cveFixes","timestamp":"2026-01-01T00:00:00Z","status":"in_progress","data":{}}'
}
result=$(check_freshness "0.24.0" "cveFixes" "ACM-99" 2>/dev/null)
assert_eq "in_progress: fresh" "$result" "fresh"

# Snapshot: same → fresh
get_step() {
  case "$2" in
    ecFixes)    printf '%s' '{"_t":"STEP_DATA","step":"ecFixes","timestamp":"2026-07-01T00:00:00Z","status":"complete","data":{"snapshot":"snap-abc"}}' ;;
    bundleShas) printf '%s' '{"_t":"STEP_DATA","step":"bundleShas","timestamp":"2026-07-01T00:00:00Z","status":"complete","data":{"snapshot":"snap-abc"}}' ;;
  esac
}
result=$(check_freshness "0.24.0" "ecFixes" "ACM-99" 2>/dev/null)
assert_eq "same snapshot: fresh" "$result" "fresh"

# Snapshot: different → stale
get_step() {
  case "$2" in
    ecFixes)    printf '%s' '{"_t":"STEP_DATA","step":"ecFixes","timestamp":"2026-07-01T00:00:00Z","status":"complete","data":{"snapshot":"snap-old"}}' ;;
    bundleShas) printf '%s' '{"_t":"STEP_DATA","step":"bundleShas","timestamp":"2026-07-01T00:00:00Z","status":"complete","data":{"snapshot":"snap-new"}}' ;;
  esac
}
result=$(check_freshness "0.24.0" "ecFixes" "ACM-99" 2>/dev/null)
assert_eq "different snapshot: stale" "$result" "stale"

# Snapshot: missing → fresh
get_step() {
  printf '%s' '{"_t":"STEP_DATA","step":"ecFixes","timestamp":"2026-07-01T00:00:00Z","status":"complete","data":{}}'
}
result=$(check_freshness "0.24.0" "ecFixes" "ACM-99" 2>/dev/null)
assert_eq "no snapshot field: fresh" "$result" "fresh"

# Restore original get_step (saved before section 4 overrides)
eval "$_SAVED_GET_STEP"

# ============================================================================
echo ""
echo "=== 5. get_step Parser ==="
# ============================================================================

# Save original find_release_tracker before overriding
_SAVED_FIND_RELEASE_TRACKER=$(declare -f find_release_tracker)

# Mock acli comment list with hardcoded fixtures
acli() {
  if [[ "${*}" == *"comment list"* ]]; then
    cat <<'MOCK'
[
  {"body": "Just a comment"},
  {"body": "## CVE fixes\n\n---\n```STEP_DATA\n{\"_t\":\"STEP_DATA\",\"step\":\"cveFixes\",\"timestamp\":\"2026-07-01T10:00:00Z\",\"status\":\"complete\",\"data\":{}}\n```"},
  {"body": "## Bundle SHAs\n\n---\n```STEP_DATA\n{\"_t\":\"STEP_DATA\",\"step\":\"bundleShas\",\"timestamp\":\"2026-07-02T10:00:00Z\",\"status\":\"complete\",\"data\":{\"snapshot\":\"snap-123\"}}\n```"},
  {"body": "## CVE fixes attempt 2\n\n---\n```STEP_DATA\n{\"_t\":\"STEP_DATA\",\"step\":\"cveFixes\",\"timestamp\":\"2026-07-05T10:00:00Z\",\"status\":\"complete\",\"data\":{\"attempt\":2}}\n```"}
]
MOCK
  fi
}
find_release_tracker() { printf '%s' "ACM-99"; }

# Standard extraction
result=$(get_step "0.24.0" "cveFixes" "ACM-99")
ts=$(printf '%s' "$result" | jq -r '.timestamp' 2>/dev/null)
assert_eq "cveFixes: latest timestamp" "$ts" "2026-07-05T10:00:00Z"

# Different step filter
snap=$(printf '%s' "$(get_step "0.24.0" "bundleShas" "ACM-99")" | jq -r '.data.snapshot' 2>/dev/null)
assert_eq "bundleShas: correct snapshot" "$snap" "snap-123"

# Non-existent step → empty
result=$(get_step "0.24.0" "nonExistent" "ACM-99")
assert_eq "missing step: empty" "$result" ""

# Empty comments → empty
acli() { printf '%s' "[]"; }
result=$(get_step "0.24.0" "cveFixes" "ACM-99")
assert_eq "no comments: empty" "$result" ""

# Reset mocks (restore library function behavior)
eval "$_SAVED_FIND_RELEASE_TRACKER"
acli() { :; }

# ============================================================================
echo ""
echo "=== 6. Contract Tests ==="
# ============================================================================

# Stub internals for update_step tests
query_jira() { echo '[{"key":"ACM-99"}]'; }
_find_subtask() { printf '%s' "ACM-98"; }
_add_comment() { return 0; }
_transition_issue() { return 0; }

# Returns 0
update_step "0.24.0" "cveFixes" "complete" "{}" "ACM-99" 2>/dev/null
assert_eq "update_step returns 0" "$?" "0"

# Returns 0 when _add_comment fails
_add_comment() { return 1; }
update_step "0.24.0" "cveFixes" "complete" "{}" "ACM-99" 2>/dev/null
assert_eq "update_step returns 0 on failure" "$?" "0"
_add_comment() { return 0; }

# No stdout
stdout=$(update_step "0.24.0" "cveFixes" "complete" "{}" "ACM-99" 2>/dev/null)
assert_eq "update_step: no stdout" "$stdout" ""

# Verify STEP_DATA comment contains valid JSON with data field
_ADD_COMMENT_BODY=""
_add_comment() { _ADD_COMMENT_BODY="$2"; return 0; }
_update_step_impl "0.24.0" "cveFixes" "complete" "{}" "ACM-99" 2>/dev/null || true
step_json=$(printf '%s\n' "$_ADD_COMMENT_BODY" | sed -n '/STEP_DATA/{n;p;}')
data_field=$(printf '%s' "$step_json" | jq -r '.data' 2>/dev/null) || data_field="PARSE_FAILED"
assert_eq "STEP_DATA has valid data field" "$data_field" "{}"

# find_release_tracker: invalid version → empty (not crash)
query_jira() { printf '%s' "SHOULD NOT BE CALLED"; }
result=$(find_release_tracker "bad" 2>/dev/null)
assert_eq "find_release_tracker: invalid version → empty" "$result" ""

# Reset
query_jira() { echo "[]"; }
_add_comment() { return 0; }

# find_release_tracker works with 2-segment version (normalized internally)
query_jira() { echo '[{"key":"ACM-222"}]'; }
result=$(find_release_tracker "0.24" 2>/dev/null)
assert_eq "find_release_tracker: 2-seg version works" "$result" "ACM-222"
query_jira() { echo "[]"; }

# ============================================================================
echo ""
echo "=== 7. Smoke Tests ==="
# ============================================================================

# get_release_summary: valid JSON
find_release_tracker() { printf '%s' "ACM-99"; }
query_jira() {
  echo '[{"key":"ACM-100","fields":{"summary":"CVE fixes","status":{"name":"New"}}}]'
}
acli() { [[ "${*}" == *"comment list"* ]] && echo "[]"; }

summary=$(get_release_summary "0.24.0" 2>/dev/null)
printf '%s' "$summary" | jq -e . >/dev/null 2>&1 && valid="yes" || valid="no"
assert_eq "get_release_summary: valid JSON" "$valid" "yes"

step_count=$(printf '%s' "$summary" | jq '.steps | keys | length' 2>/dev/null)
assert_eq "get_release_summary: 19 steps" "$step_count" "19"

# Template completeness
fallback_found=0
for key in "${STEP_ORDER[@]}"; do
  desc=$(_generate_subtask_description "$key" "0.24.0")
  if printf '%s' "$desc" | grep -qF "no description template"; then
    fallback_found=$((fallback_found + 1))
  fi
done
assert_eq "all step keys have templates" "$fallback_found" "0"

# create_release_tracker: ACM version failure
find_release_tracker() { :; }
query_jira() { echo "[]"; }
calculate_acm_version() { return 1; }
create_release_tracker "0.24.0" 2>/dev/null && crc=0 || crc=$?
assert_eq "create fails on ACM version error" "$crc" "1"
# shellcheck disable=SC2034  # ACM_VERSION used by library after mock returns
calculate_acm_version() { ACM_VERSION="ACM 2.17.0"; }

# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo "All $PASS tests passed"
else
  echo "$FAIL FAILED, $PASS passed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ] || exit 1
