#!/bin/bash
# Autorelease conductor: find the next ready release step and run it
#
# Usage: autorelease.sh <version>
#
# Walks the release dependency graph, finds the first step that is ready
# (all deps complete, step not done), and either runs it or prints guidance.
# Chains consecutive auto steps. Stops at gate, review, hint, or manual steps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/jira-tracker.sh
source "$SCRIPT_DIR/lib/jira-tracker.sh"

usage() {
  echo "Usage: $0 <version>"
  echo "  Run ready release steps, chaining consecutive auto steps"
  echo "  Stops at gate, review, or manual steps"
  echo ""
  echo "Example: $0 0.25.1"
  echo "         $0 0.25     # auto-expands to 0.25.0 (Y-stream)"
}

# --- Core logic: find_next_step ---
# Sets globals: NEXT_STEP, NEXT_REASON.
# Uses globals: step_statuses (associative array, pre-populated by caller or fetched here).
NEXT_STEP=""
NEXT_REASON=""

find_next_step() {
  # shellcheck disable=SC2034  # version kept for API consistency (version, release_type, tracker)
  local version="$1"
  local release_type="$2"
  local tracker="$3"

  # Single-fetch cache: fetch all comments once, parse all step statuses
  if [ "${_AUTORELEASE_TESTING:-}" != "true" ]; then
    local all_comments
    all_comments=$(acli jira workitem comment list --key "$tracker" --json --paginate </dev/null 2>/dev/null || true)

    step_statuses=()
    while IFS=$'\t' read -r skey sstatus; do
      [ -n "$skey" ] && step_statuses[$skey]="$sstatus"
    done < <(printf '%s' "$all_comments" | jq -r '
      [.[] | .body // empty |
       capture("```STEP_DATA\\n(?<json>\\{[^`]+)\\n```"; "g") // empty |
       .json] |
      map(fromjson? // empty) |
      map(select(._t == "STEP_DATA")) |
      group_by(.step) | map(last) |
      .[] | [.step, .status] | @tsv
    ' 2>/dev/null)
  fi

  for step in "${STEP_ORDER[@]}"; do
    step_applies_to_release "$step" "$release_type" || continue

    local status="${step_statuses[$step]:-}"

    if [ "$status" = "complete" ]; then
      [ "${_AUTORELEASE_QUIET:-}" != "true" ] && echo "  ✓ ${STEP_TITLES[$step]:-$step}: done" >&2
      continue
    fi

    # Check if all deps are satisfied
    local deps="${STEP_DEPENDENCIES[$step]:-}"
    local all_deps_met=true
    if [ -n "$deps" ]; then
      IFS=',' read -ra dep_arr <<< "$deps"
      for dep in "${dep_arr[@]}"; do
        [ -z "$dep" ] && continue
        step_applies_to_release "$dep" "$release_type" || continue
        local dep_status="${step_statuses[$dep]:-}"
        if [ "$dep_status" != "complete" ]; then
          all_deps_met=false
          break
        fi
      done
    fi

    if [ "$all_deps_met" = "false" ]; then
      continue
    fi

    # Found the next ready step
    NEXT_STEP="$step"
    local level="${AUTOMATION_LEVEL[$step]:-auto}"
    local script="${STEP_SCRIPT[$step]:-}"
    local hint="${STEP_SKILL_HINT[$step]:-}"

    if [ "$level" = "gate" ]; then
      NEXT_REASON="gate"
    elif [ -n "$script" ]; then
      NEXT_REASON="run"
    elif [ -n "$hint" ]; then
      NEXT_REASON="hint"
    else
      NEXT_REASON="manual"
    fi
    return 0
  done

  NEXT_STEP=""
  NEXT_REASON="all_done"
  return 0
}

# --- Main execution (guarded for testability) ---

if [ "${_AUTORELEASE_TESTING:-}" != "true" ]; then

  # Arg handling
  case "${1:-}" in --help|-h) usage; exit 0 ;; esac
  [ $# -gt 1 ] && { echo "ERROR: Too many arguments" >&2; usage >&2; exit 1; }

  VERSION="${1:-}"
  if [ -z "$VERSION" ]; then
    usage >&2
    exit 1
  fi

  VERSION=$(_normalize_version "$VERSION")
  _validate_version "$VERSION" || exit 1

  RELEASE_TYPE=$(_detect_release_type "$VERSION")
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

  # Find tracker (required for completion detection)
  TRACKER=$(find_release_tracker "$VERSION" 2>/dev/null || true)
  if [ -z "$TRACKER" ]; then
    echo "❌ No release tracker found for $VERSION" >&2
    echo "   Create one first: /create-release-tracker $VERSION" >&2
    exit 1
  fi

  echo "Submariner $VERSION ($RELEASE_TYPE)" >&2
  echo "Tracker: $TRACKER" >&2
  echo "" >&2

  # --- Multi-step loop with same-step guard ---
  declare -A step_statuses=()
  prev_step=""

  while true; do
    find_next_step "$VERSION" "$RELEASE_TYPE" "$TRACKER"

    case "$NEXT_REASON" in
      all_done)
        echo "" >&2
        echo "✅ All steps complete for $VERSION" >&2
        break
        ;;

      gate)
        echo "" >&2
        echo "⏸ ${STEP_TITLES[$NEXT_STEP]:-$NEXT_STEP}: GATE" >&2
        local_hint="${STEP_SKILL_HINT[$NEXT_STEP]:-Complete this step manually}"
        echo "  $local_hint" >&2
        echo "  Re-run: /autorelease $VERSION" >&2
        break
        ;;

      hint)
        echo "" >&2
        echo "→ ${STEP_TITLES[$NEXT_STEP]:-$NEXT_STEP}" >&2
        echo "  ${STEP_SKILL_HINT[$NEXT_STEP]:-Complete this step manually}" >&2
        echo "  Re-run: /autorelease $VERSION" >&2
        break
        ;;

      run)
        # Same-step guard: if the previous script didn't mark itself complete, stop
        if [ "$NEXT_STEP" = "$prev_step" ]; then
          echo "" >&2
          echo "⚠️  ${STEP_TITLES[$NEXT_STEP]:-$NEXT_STEP}: ran but didn't mark complete" >&2
          echo "  Re-run: /autorelease $VERSION" >&2
          break
        fi
        prev_step="$NEXT_STEP"

        local_script="${STEP_SCRIPT[$NEXT_STEP]:-}"
        local_args="${STEP_EXTRA_ARGS[$NEXT_STEP]:-}"
        local_title="${STEP_TITLES[$NEXT_STEP]:-$NEXT_STEP}"
        local_level="${AUTOMATION_LEVEL[$NEXT_STEP]:-auto}"

        echo "→ $local_title: running $local_script $VERSION $local_args..." >&2
        echo "" >&2

        local_exit=0
        if [ -n "$GIT_ROOT" ]; then
          # shellcheck disable=SC2086  # Intentional word splitting on local_args
          (cd "$GIT_ROOT" && "$GIT_ROOT/$local_script" "$VERSION" $local_args) >&2 || local_exit=$?
        else
          # shellcheck disable=SC2086
          "$local_script" "$VERSION" $local_args >&2 || local_exit=$?
        fi

        echo "" >&2
        if [ "$local_exit" -ne 0 ]; then
          echo "❌ ${local_title} failed (exit $local_exit)" >&2
          echo "  Fix the issue, then re-run: /autorelease $VERSION" >&2
          exit 1
        fi

        if [ "$local_level" = "review" ]; then
          echo "⏸ ${local_title}: REVIEW" >&2
          echo "  Review the output above, then re-run: /autorelease $VERSION" >&2
          break
        fi

        echo "✓ ${local_title}: complete" >&2
        _AUTORELEASE_QUIET=true
        # Continue loop — find_next_step will re-fetch comments
        ;;

      manual)
        echo "" >&2
        echo "→ ${STEP_TITLES[$NEXT_STEP]:-$NEXT_STEP}: manual step" >&2
        echo "  Complete this step manually, then re-run: /autorelease $VERSION" >&2
        break
        ;;

      *)
        echo "❌ Unknown dispatch reason: $NEXT_REASON" >&2
        exit 1
        ;;
    esac
  done
fi
