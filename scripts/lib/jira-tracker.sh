#!/bin/bash
# Shared library for Jira release tracker operations
# Used by: create-release-tracker.sh, release-status.sh, and release workflow scripts
#
# Provides structured Jira-based tracking for Submariner releases.
# Each release gets a parent Task with 15-19 Sub-task children (one per workflow step).
# Automation appends structured STEP_DATA comments as steps complete.
#
# Best-effort: tracker failures never crash calling scripts. Functions that are
# called as side-effects (update_step, get_step, etc.) return 0 on error.
# create_release_tracker is strict since it's a deliberate action.

# Include guard — prevent crash from re-sourcing readonly variables
if [ "${_JIRA_TRACKER_SOURCED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_JIRA_TRACKER_SOURCED=true

# Source shared Jira helpers (query_jira, view_jira, calculate_acm_version)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-notes-common.sh
source "$SCRIPT_DIR/release-notes-common.sh" 2>/dev/null || true

# ============================================================================
# Constants
# ============================================================================

# Step keys to subtask summary titles
declare -A STEP_TITLES=(
  ["createBranches"]="Create upstream release branches"
  ["configureDownstream"]="Configure Konflux downstream"
  ["tektonComponents"]="Tekton component setup"
  ["tektonBundle"]="Tekton bundle setup"
  ["cveFixes"]="CVE fixes"
  ["ecFixes"]="EC compliance fixes"
  ["rpmLockfiles"]="RPM lockfile updates"
  ["tektonTasks"]="Tekton task updates"
  ["versionLabels"]="Version label updates"
  ["upstreamRelease"]="Cut upstream release"
  ["bundleShas"]="Update bundle SHAs"
  ["componentStage"]="Component stage release"
  ["releaseNotes"]="Release notes"
  ["fbcCatalogUpdate"]="FBC catalog update"
  ["fbcStageReleases"]="FBC stage releases"
  ["qeValidation"]="QE testing"
  ["componentProd"]="Component prod release"
  ["fbcProdReleases"]="FBC prod releases"
  ["fbcProdUrls"]="FBC prod URL conversion"
)

# Step display order (workflow sequence)
readonly STEP_ORDER=(
  "createBranches" "configureDownstream" "tektonComponents" "tektonBundle"
  "cveFixes" "ecFixes" "rpmLockfiles" "tektonTasks" "versionLabels"
  "upstreamRelease" "bundleShas"
  "componentStage" "releaseNotes" "fbcCatalogUpdate" "fbcStageReleases"
  "qeValidation"
  "componentProd" "fbcProdReleases" "fbcProdUrls"
)

# Y-stream only steps (omitted for Z-stream)
readonly YSTREAM_STEPS=("createBranches" "configureDownstream" "tektonComponents" "tektonBundle")

# Phase groupings for display
declare -A STEP_PHASE=(
  ["createBranches"]="Branch Setup"
  ["configureDownstream"]="Branch Setup"
  ["tektonComponents"]="Branch Setup"
  ["tektonBundle"]="Branch Setup"
  ["cveFixes"]="Build Readiness"
  ["ecFixes"]="Build Readiness"
  ["rpmLockfiles"]="Build Readiness"
  ["tektonTasks"]="Build Readiness"
  ["versionLabels"]="Build Readiness"
  ["upstreamRelease"]="Build Readiness"
  ["bundleShas"]="Build Readiness"
  ["componentStage"]="Stage Release"
  ["releaseNotes"]="Stage Release"
  ["fbcCatalogUpdate"]="Stage Release"
  ["fbcStageReleases"]="Stage Release"
  ["qeValidation"]="QE Validation"
  ["componentProd"]="Production Release"
  ["fbcProdReleases"]="Production Release"
  ["fbcProdUrls"]="Production Release"
)

# Staleness rules: time-based (Nd) or snapshot-triggered
declare -A STALENESS_RULES=(
  ["cveFixes"]="3d"
  ["rpmLockfiles"]="3d"
  ["ecFixes"]="snapshot"
  ["bundleShas"]="snapshot"
  ["fbcCatalogUpdate"]="snapshot"
  ["qeValidation"]="snapshot"
  ["fbcProdUrls"]="75d"
)

# Step dependencies (comma-separated prerequisite step keys)
# shellcheck disable=SC2034  # Exported for use by callers (agentic automation, release-ls)
declare -A STEP_DEPENDENCIES=(
  ["createBranches"]=""
  ["configureDownstream"]="createBranches"
  ["tektonComponents"]="configureDownstream"
  ["tektonBundle"]="configureDownstream"
  ["cveFixes"]=""
  ["ecFixes"]=""
  ["rpmLockfiles"]=""
  ["tektonTasks"]=""
  ["versionLabels"]=""
  ["upstreamRelease"]="cveFixes,ecFixes,rpmLockfiles,tektonTasks"
  ["bundleShas"]="upstreamRelease"
  ["componentStage"]="bundleShas"
  ["releaseNotes"]="bundleShas"
  ["fbcCatalogUpdate"]="componentStage"
  ["fbcStageReleases"]="fbcCatalogUpdate"
  ["qeValidation"]="fbcStageReleases"
  ["componentProd"]="qeValidation,componentStage"
  ["fbcProdReleases"]="componentProd"
  ["fbcProdUrls"]="fbcProdReleases"
)

# Automation levels: auto, review, gate
# shellcheck disable=SC2034  # Exported for use by callers (agentic automation, release-ls)
declare -A AUTOMATION_LEVEL=(
  ["createBranches"]="review"
  ["configureDownstream"]="auto"
  ["tektonComponents"]="auto"
  ["tektonBundle"]="auto"
  ["cveFixes"]="auto"
  ["ecFixes"]="auto"
  ["rpmLockfiles"]="auto"
  ["tektonTasks"]="auto"
  ["versionLabels"]="auto"
  ["upstreamRelease"]="gate"
  ["bundleShas"]="auto"
  ["componentStage"]="auto"
  ["releaseNotes"]="review"
  ["fbcCatalogUpdate"]="auto"
  ["fbcStageReleases"]="review"
  ["qeValidation"]="gate"
  ["componentProd"]="review"
  ["fbcProdReleases"]="review"
  ["fbcProdUrls"]="auto"
)

# Jira status names (overridable via env for project-specific names)
readonly JIRA_STATUS_IN_PROGRESS="${JIRA_STATUS_IN_PROGRESS:-In Progress}"
readonly JIRA_STATUS_RESOLVED="${JIRA_STATUS_RESOLVED:-Resolved}"
readonly JIRA_STATUS_CLOSED="${JIRA_STATUS_CLOSED:-Closed}"

# ============================================================================
# Internal Helpers
# ============================================================================

# Normalize version: expand 2-segment (0.24) to 3-segment (0.24.0)
# Args: $1=version
# Output: normalized version
_normalize_version() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+\.[0-9]+$ ]] && v="${v}.0"
  echo "$v"
}

# Validate version format (must be X.Y.Z with 3 segments)
# Args: $1=version
# Returns: 0 if valid, 1 if invalid
_validate_version() {
  local version="$1"
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ ERROR: Version must be X.Y.Z format (e.g., 0.24.0), got '$version'" >&2
    echo "   Two-segment versions (e.g., 0.24) would create label collisions across patches" >&2
    return 1
  fi
}

# Convert version to Jira label (dots → dashes)
# Args: $1=version (e.g., 0.24.0)
# Output: label (e.g., release-0-24-0)
_version_to_label() {
  echo "release-$(echo "$1" | tr '.' '-')"
}

# Detect release type from version
# Args: $1=version (X.Y.Z)
# Output: "y-stream" or "z-stream"
_detect_release_type() {
  local patch="${1##*.}"
  if [ "$patch" = "0" ]; then
    echo "y-stream"
  else
    echo "z-stream"
  fi
}

# Find a subtask by parent key and step key
# Args: $1=parent_key (e.g., ACM-54321)
#       $2=step_key (e.g., cveFixes)
# Output: subtask issue key or empty
_find_subtask() {
  local parent_key="$1"
  local step_key="$2"
  local title="${STEP_TITLES[$step_key]:-}"

  if [ -z "$title" ]; then
    echo "⚠️  Unknown step key: $step_key" >&2
    return 1
  fi

  local result
  result=$(query_jira --jql "parent = $parent_key AND summary ~ \"$title\"" --fields "key" 2>/dev/null) || return 1

  echo "$result" | jq -r '.[0].key // empty' 2>/dev/null
}

# Transition a Jira issue to a new status
# Args: $1=issue_key $2=target_status
_transition_issue() {
  local key="$1"
  local status="$2"

  # Try the transition directly — Jira auto-sets resolution for most workflows
  acli jira workitem transition --key "$key" --status "$status" --yes </dev/null 2>/dev/null
}

# Write a structured comment on a Jira issue
# Args: $1=issue_key $2=comment_body (markdown string)
_add_comment() {
  local key="$1"
  local body="$2"

  local body_file
  body_file=$(mktemp)
  printf '%s\n' "$body" > "$body_file"

  local result=0
  acli jira workitem comment create --key "$key" --body-file "$body_file" </dev/null 2>/dev/null || result=$?

  rm -f "$body_file"
  return "$result"
}

# Generate parent task description markdown
# Args: $1=version $2=release_type $3=acm_version
_generate_parent_description() {
  local version="$1"
  local release_type="$2"
  local acm_version="$3"
  local major_minor="${version%.*}"

  local type_label
  if [ "$release_type" = "y-stream" ]; then
    type_label="Y-stream (new minor version)"
  else
    type_label="Z-stream (patch release)"
  fi

  cat <<DESC
## Release Info

- **Version:** $version
- **Type:** $type_label
- **ACM Version:** $acm_version
- **Release Branch:** release-$major_minor
- **Release Engineer:** $(git config user.name 2>/dev/null || echo "TBD")

## Key Artifacts

Updated by automation as the release progresses.

- **Snapshot:** _(pending)_
- **Stage Release:** _(pending)_
- **Prod Release:** _(pending)_
- **FBC Catalog URLs:** _(pending)_
- **Advisory:** _(pending)_

## Tracking

This issue tracks the Submariner $version release workflow.
Subtasks represent individual steps. Structured comments record
step completion data for automation.
DESC
}

# Generate subtask description based on step type
# Args: $1=step_key $2=version
_generate_subtask_description() {
  local step_key="$1"
  local version="$2"
  local major_minor="${version%.*}"

  case "$step_key" in
    cveFixes|ecFixes|rpmLockfiles|tektonTasks|versionLabels)
      cat <<DESC
## PRs

_(populated by automation when PRs are created)_

## Status

Waiting for skill to create PRs across repos on release-$major_minor branch.
DESC
      ;;
    createBranches)
      cat <<DESC
## Status

Create release-$major_minor branches across all upstream repos.

- **Repo:** submariner-io/releases
- **Branch:** release-$major_minor
DESC
      ;;
    configureDownstream)
      cat <<DESC
## Status

Configure Konflux for Submariner $version.

- **Repo:** konflux-release-data
- **Output:** Overlays, tenant config, RPAs for $major_minor
DESC
      ;;
    tektonComponents|tektonBundle)
      cat <<DESC
## Status

Setup Tekton pipelines on release-$major_minor branch.
DESC
      ;;
    upstreamRelease)
      cat <<DESC
## Release

- **Version:** v$version
- **Branch:** release-$major_minor
- **PR:** _(pending)_
- **Status:** _(pending)_

## Decision

_(record the decision to cut the release here)_
DESC
      ;;
    bundleShas)
      cat <<DESC
## Status

- **Snapshot:** _(pending)_
- **PR:** _(pending)_
- **Verification:** _(pending)_
DESC
      ;;
    componentStage|componentProd)
      cat <<DESC
## Release

- **Release Name:** _(pending)_
- **Snapshot:** _(pending)_
- **Attempt:** 1
- **Status:** _(pending)_

## Notes

_(automation will update with release pipeline results)_
DESC
      ;;
    releaseNotes)
      cat <<DESC
## Advisory

- **Type:** _(RHSA or RHBA, pending)_
- **Total issues:** _(pending)_
- **Review PR:** _(pending)_
DESC
      ;;
    fbcCatalogUpdate)
      cat <<DESC
## Status

Update FBC catalogs with bundle from stage release.

- **FBC Repo PR:** _(pending)_
- **OCP Versions:** 4.16 through 4.22
DESC
      ;;
    fbcStageReleases|fbcProdReleases)
      cat <<DESC
## Releases

One release per OCP version (4.16 through 4.22).

_(automation will populate with per-OCP-version release status)_
DESC
      ;;
    qeValidation)
      cat <<DESC
## Stage Catalog URLs

_(populated by automation when stage releases complete)_

## Platform Testing Status

- **AWS:** _(pending)_
- **vSphere:** _(pending)_
- **ROSA:** _(pending)_
- **Azure:** _(pending)_
- **ARO:** _(pending)_
- **GCP:** _(pending)_
- **IBM Power (ppc64le):** _(pending)_
- **IBM Z (s390x):** _(pending)_

## Go/No-Go Decision

- **Decision:** _(pending)_
- **Approved by:** _(pending)_
- **Date:** _(pending)_
- **Known issues:** _(pending)_
- **Conditions:** _(pending)_
- **OCP versions tested:** _(pending)_

Assign this subtask to the QE engineer. Catalog URLs are
populated by automation when stage releases complete.
DESC
      ;;
    fbcProdUrls)
      cat <<DESC
## Status

Convert temporary quay.io bundle URLs to permanent registry.redhat.io
URLs in the FBC template.

- **Deadline:** ~90 days after prod release (quay.io URLs expire)
- **FBC Repo PR:** _(pending)_

Usually handled automatically during the next release's FBC catalog
update. Manual conversion needed if no next release within 90 days.
DESC
      ;;
    *)
      echo "_(no description template for $step_key)_"
      ;;
  esac
}

# ============================================================================
# Public API
# ============================================================================

# Find the Jira tracker task for a release version
# Args: $1=version (X.Y.Z)
# Output: Issue key (e.g., ACM-54321) or empty
# Returns: 0 always (best-effort)
find_release_tracker() {
  local version="$1"
  version=$(_normalize_version "$version")

  _validate_version "$version" || return 0

  local version_label
  version_label=$(_version_to_label "$version")

  local result
  result=$(query_jira --jql "project = ACM AND labels = release-tracking AND labels = $version_label AND issuetype = Task" --fields "key" 2>/dev/null) || {
    echo "⚠️  Could not query Jira for release tracker" >&2
    return 0
  }

  echo "$result" | jq -r '.[0].key // empty' 2>/dev/null || true
}

# Create a new release tracker with all subtasks
# Args: $1=version (X.Y.Z)
#       $2=release_type (y-stream|z-stream) [optional, auto-detected]
#       $3=qe_assignee (email) [optional]
# Output: Parent issue key
# Returns: 0 on success, 1 on failure
create_release_tracker() {
  local version="$1"
  version=$(_normalize_version "$version")
  local release_type="${2:-}"
  local qe_assignee="${3:-}"

  _validate_version "$version" || return 1

  # Auto-detect release type if not specified
  if [ -z "$release_type" ]; then
    release_type=$(_detect_release_type "$version")
  fi

  local version_label
  version_label=$(_version_to_label "$version")

  # Idempotency: check for existing tracker
  local existing
  existing=$(find_release_tracker "$version")
  if [ -n "$existing" ]; then
    echo "⚠️  Tracker already exists: $existing" >&2
    echo "$existing"
    return 0
  fi

  # Calculate ACM version (sets ACM_VERSION global)
  VERSION="$version" calculate_acm_version || {
    echo "❌ ERROR: Failed to calculate ACM version for $version" >&2
    return 1
  }

  echo "Creating release tracker for Submariner $version ($release_type)..." >&2

  # --- Create parent task ---

  local desc_file
  desc_file=$(mktemp)
  _generate_parent_description "$version" "$release_type" "$ACM_VERSION" > "$desc_file"

  local parent_output parent_key
  if [ "${JIRA_TRACKER_DRY_RUN:-}" = "true" ]; then
    echo "[DRY RUN] Would create: Task 'Release Submariner $version'" >&2
    parent_key="ACM-DRY-RUN"
  else
    parent_output=$(acli jira workitem create \
      --project ACM \
      --type Task \
      --summary "Release Submariner $version" \
      --label "release-tracking,submariner,$version_label" \
      --description-file "$desc_file" \
      --json </dev/null) || {
      echo "❌ ERROR: Failed to create parent task" >&2
      rm -f "$desc_file"
      return 1
    }
    parent_key=$(echo "$parent_output" | jq -r '.key // empty' 2>/dev/null) || parent_key=""
  fi

  rm -f "$desc_file"

  if [ -z "$parent_key" ]; then
    echo "❌ ERROR: Could not extract parent key from create response" >&2
    return 1
  fi

  echo "✓ Parent task created: $parent_key" >&2

  # Fix Version ($ACM_VERSION) must be set manually or via MCP — acli edit
  # doesn't support fixVersions (--key and --from-json are mutually exclusive,
  # and --from-json schema lacks fixVersions). The description includes the
  # ACM version for reference.

  # --- Create subtasks ---

  local subtask_count=0
  local failed_count=0

  for step_key in "${STEP_ORDER[@]}"; do
    # Skip Y-stream steps for Z-stream releases
    if [ "$release_type" = "z-stream" ]; then
      local is_ystream=false
      for ys in "${YSTREAM_STEPS[@]}"; do
        [ "$step_key" = "$ys" ] && is_ystream=true && break
      done
      [ "$is_ystream" = "true" ] && continue
    fi

    local title="${STEP_TITLES[$step_key]:-$step_key}"

    local sub_desc_file
    sub_desc_file=$(mktemp)
    _generate_subtask_description "$step_key" "$version" > "$sub_desc_file"

    # Build create command args
    local -a create_args=(
      --project ACM
      --type Sub-task
      --parent "$parent_key"
      --summary "$title"
      --label "release-tracking,$version_label"
      --description-file "$sub_desc_file"
      --json
    )

    # Assign QE subtask to QE engineer if specified
    if [ "$step_key" = "qeValidation" ] && [ -n "$qe_assignee" ]; then
      create_args+=(--assignee "$qe_assignee")
    fi

    if [ "${JIRA_TRACKER_DRY_RUN:-}" = "true" ]; then
      echo "[DRY RUN] Would create: Sub-task '$title' under $parent_key" >&2
      subtask_count=$((subtask_count + 1))
    else
      local sub_output
      if sub_output=$(acli jira workitem create "${create_args[@]}" </dev/null 2>/dev/null); then
        local sub_key
        sub_key=$(echo "$sub_output" | jq -r '.key // empty' 2>/dev/null) || sub_key=""
        echo "  ✓ $title ($sub_key)" >&2
        subtask_count=$((subtask_count + 1))
      else
        echo "  ❌ Failed to create: $title" >&2
        failed_count=$((failed_count + 1))
      fi
    fi

    rm -f "$sub_desc_file"
  done

  echo "" >&2
  echo "✓ Release tracker created: $parent_key" >&2
  echo "  Subtasks: $subtask_count created" >&2
  [ "$failed_count" -gt 0 ] && echo "  ⚠️  $failed_count subtask(s) failed to create" >&2

  echo "$parent_key"
}

# Update a step's status and add a structured comment
# Args: $1=version (X.Y.Z)
#       $2=step_key (e.g., "cveFixes")
#       $3=status ("in_progress"|"complete"|"failed")
#       $4=data (JSON string with step-specific results) [optional]
#       $5=parent_key [optional, avoids re-lookup]
# Returns: 0 always (best-effort)
update_step() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local status="$3"
  local data="${4:-"{}"}"
  local parent_key="${5:-}"

  _update_step_impl "$version" "$step_key" "$status" "$data" "$parent_key" || true
  return 0
}

_update_step_impl() {
  local version="$1"
  local step_key="$2"
  local status="$3"
  local data="$4"
  local parent_key="$5"

  _validate_version "$version" || return 0

  # Find tracker if not provided
  if [ -z "$parent_key" ]; then
    parent_key=$(find_release_tracker "$version")
    [ -z "$parent_key" ] && {
      echo "⚠️  No tracker found for $version (run /create-release-tracker $version)" >&2
      return 0
    }
  fi

  local title="${STEP_TITLES[$step_key]:-$step_key}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build structured comment
  local status_label
  case "$status" in
    in_progress) status_label="IN PROGRESS" ;;
    complete) status_label="COMPLETE" ;;
    failed) status_label="FAILED" ;;
    *) status_label="$status" ;;
  esac

  # Build STEP_DATA JSON safely via jq
  local step_json
  step_json=$(jq -n \
    --arg step "$step_key" \
    --arg ts "$timestamp" \
    --arg status "$status" \
    --argjson data "$data" \
    '{_t:"STEP_DATA",step:$step,timestamp:$ts,status:$status,data:$data}' \
    | jq -c .)

  local comment_body
  comment_body="## $title — $status_label

- **Timestamp:** $timestamp
- **Status:** $status

---
\`\`\`STEP_DATA
$step_json
\`\`\`"

  # Add comment on parent task
  _add_comment "$parent_key" "$comment_body" || {
    echo "⚠️  Failed to add tracker comment for $step_key" >&2
    return 0
  }

  # Transition subtask
  local subtask_key
  subtask_key=$(_find_subtask "$parent_key" "$step_key") || true

  if [ -n "$subtask_key" ]; then
    case "$status" in
      in_progress)
        _transition_issue "$subtask_key" "$JIRA_STATUS_IN_PROGRESS" || true
        ;;
      complete)
        _transition_issue "$subtask_key" "$JIRA_STATUS_RESOLVED" || true
        ;;
      failed)
        # Keep in current status (In Progress), failure recorded in comment
        ;;
    esac
  fi

  echo "✓ Tracker updated: $step_key → $status_label" >&2
}

# Get the latest step data from tracker comments
# Args: $1=version (X.Y.Z)
#       $2=step_key (e.g., "cveFixes")
#       $3=parent_key [optional]
# Output: JSON object with step data, or empty
# Returns: 0 always
get_step() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local parent_key="${3:-}"

  _validate_version "$version" || return 0

  if [ -z "$parent_key" ]; then
    parent_key=$(find_release_tracker "$version")
    [ -z "$parent_key" ] && return 0
  fi

  # Fetch comments from parent task
  local comments
  comments=$(acli jira workitem comment list --key "$parent_key" --json --paginate </dev/null 2>/dev/null) || return 0

  # Parse comments to find latest STEP_DATA matching step_key
  # Comments are in chronological order; we want the last match
  echo "$comments" | jq -r --arg step "$step_key" '
    [.[] | .body // empty |
     capture("```STEP_DATA\\n(?<json>\\{[^`]+)\\n```"; "g") // empty |
     .json] |
    map(fromjson? // empty) |
    map(select(._t == "STEP_DATA" and .step == $step)) |
    last // empty
  ' 2>/dev/null || true
}

# Check freshness of a completed step
# Args: $1=version (X.Y.Z)
#       $2=step_key
#       $3=parent_key [optional]
# Output: "fresh" or "stale"
# Returns: 0 always
check_freshness() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local parent_key="${3:-}"

  local rule="${STALENESS_RULES[$step_key]:-}"
  if [ -z "$rule" ]; then
    echo "fresh"
    return 0
  fi

  # Get step data
  local step_data
  step_data=$(get_step "$version" "$step_key" "$parent_key") || true
  if [ -z "$step_data" ]; then
    echo "fresh"
    return 0
  fi

  local step_status
  step_status=$(echo "$step_data" | jq -r '.status // empty' 2>/dev/null) || true
  if [ "$step_status" != "complete" ]; then
    echo "fresh"
    return 0
  fi

  local step_timestamp
  step_timestamp=$(echo "$step_data" | jq -r '.timestamp // empty' 2>/dev/null) || true
  if [ -z "$step_timestamp" ]; then
    echo "fresh"
    return 0
  fi

  case "$rule" in
    *d)
      # Time-based staleness (e.g., 3d, 75d)
      local days="${rule%d}"
      local step_epoch now_epoch age_secs max_secs
      step_epoch=$(date -d "$step_timestamp" +%s 2>/dev/null || echo 0)
      now_epoch=$(date +%s 2>/dev/null || echo 0)
      age_secs=$((now_epoch - step_epoch))
      max_secs=$((days * 86400))

      if [ "$age_secs" -gt "$max_secs" ]; then
        local age_days=$((age_secs / 86400))
        echo "stale"
        echo "  Completed ${age_days}d ago (limit: ${days}d)" >&2
      else
        echo "fresh"
      fi
      ;;
    snapshot)
      # Snapshot-triggered staleness
      # Compare step's snapshot against the latest known snapshot (from bundleShas)
      local step_snapshot
      step_snapshot=$(echo "$step_data" | jq -r '.data.snapshot // empty' 2>/dev/null) || true

      if [ -z "$step_snapshot" ]; then
        echo "fresh"
        return 0
      fi

      local bundle_data latest_snapshot
      bundle_data=$(get_step "$version" "bundleShas" "$parent_key") || true
      latest_snapshot=$(echo "$bundle_data" | jq -r '.data.snapshot // empty' 2>/dev/null) || true

      if [ -n "$latest_snapshot" ] && [ "$step_snapshot" != "$latest_snapshot" ]; then
        echo "stale"
        echo "  Snapshot changed: ${step_snapshot:0:30} → ${latest_snapshot:0:30}" >&2
      else
        echo "fresh"
      fi
      ;;
    *)
      echo "fresh"
      ;;
  esac
}

# Update a subtask's description
# Args: $1=version (X.Y.Z)
#       $2=step_key
#       $3=content (markdown string)
#       $4=parent_key [optional]
# Returns: 0 always (best-effort)
update_subtask_description() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local content="$3"
  local parent_key="${4:-}"

  _update_subtask_description_impl "$version" "$step_key" "$content" "$parent_key" >&2 2>&1 || true
  return 0
}

_update_subtask_description_impl() {
  local version="$1"
  local step_key="$2"
  local content="$3"
  local parent_key="$4"

  _validate_version "$version" || return 0

  if [ -z "$parent_key" ]; then
    parent_key=$(find_release_tracker "$version")
    [ -z "$parent_key" ] && return 0
  fi

  local subtask_key
  subtask_key=$(_find_subtask "$parent_key" "$step_key") || {
    echo "⚠️  Could not find subtask for $step_key" >&2
    return 0
  }

  [ -z "$subtask_key" ] && return 0

  local desc_file
  desc_file=$(mktemp)
  printf '%s\n' "$content" > "$desc_file"

  acli jira workitem edit --key "$subtask_key" --description-file "$desc_file" --yes </dev/null 2>/dev/null || {
    echo "⚠️  Failed to update description for $step_key ($subtask_key)" >&2
  }

  rm -f "$desc_file"
}

# Get a structured summary of all step statuses
# Args: $1=version (X.Y.Z)
# Output: JSON summary with per-step status
# Returns: 0 always
get_release_summary() {
  local version="$1"
  version=$(_normalize_version "$version")

  _validate_version "$version" || { echo "{}"; return 0; }

  local parent_key
  parent_key=$(find_release_tracker "$version")
  if [ -z "$parent_key" ]; then
    echo "{}"
    return 0
  fi

  local release_type
  release_type=$(_detect_release_type "$version")

  # Fetch all subtasks with status
  local subtasks
  subtasks=$(query_jira --jql "parent = $parent_key" --fields "key,summary,status" 2>/dev/null) || {
    echo "{}"
    return 0
  }

  # Fetch all comments from parent for step data
  local comments
  comments=$(acli jira workitem comment list --key "$parent_key" --json --paginate </dev/null 2>/dev/null) || true

  # Build summary JSON using jq for safe construction
  local result
  result=$(jq -n --arg version "$version" --arg type "$release_type" --arg tracker "$parent_key" \
    '{version: $version, type: $type, tracker: $tracker, steps: {}}') || { echo "{}"; return 0; }

  for step_key in "${STEP_ORDER[@]}"; do
    # Skip Y-stream steps for Z-stream
    if [ "$release_type" = "z-stream" ]; then
      local is_ystream=false
      for ys in "${YSTREAM_STEPS[@]}"; do
        [ "$step_key" = "$ys" ] && is_ystream=true && break
      done
      [ "$is_ystream" = "true" ] && continue
    fi

    local title="${STEP_TITLES[$step_key]:-$step_key}"
    local phase="${STEP_PHASE[$step_key]:-unknown}"

    # Get subtask Jira status
    local jira_status
    jira_status=$(echo "$subtasks" | jq -r --arg title "$title" '
      [.[] | select(.fields.summary == $title)] | .[0].fields.status.name // "Unknown"
    ' 2>/dev/null) || true

    # Get latest step data from comments
    local step_data="{}"
    if [ -n "$comments" ]; then
      local extracted
      extracted=$(echo "$comments" | jq -r --arg step "$step_key" '
        [.[] | .body // empty |
         capture("```STEP_DATA\\n(?<json>\\{[^`]+)\\n```"; "g") // empty |
         .json] |
        map(fromjson? // empty) |
        map(select(._t == "STEP_DATA" and .step == $step)) |
        last // empty
      ' 2>/dev/null) || true
      [ -n "$extracted" ] && step_data="$extracted"
    fi

    # Check freshness
    local freshness="fresh"
    if [ -n "${STALENESS_RULES[$step_key]:-}" ] && [ "$step_data" != "{}" ]; then
      freshness=$(check_freshness "$version" "$step_key" "$parent_key" 2>/dev/null) || true
    fi

    # Merge step into result using jq (handles escaping safely)
    result=$(echo "$result" | jq \
      --arg key "$step_key" \
      --arg title "$title" \
      --arg phase "$phase" \
      --arg jiraStatus "${jira_status:-Unknown}" \
      --arg freshness "$freshness" \
      --argjson stepData "$step_data" \
      '.steps[$key] = {title: $title, phase: $phase, jiraStatus: $jiraStatus, freshness: $freshness, stepData: $stepData}') || true
  done

  echo "$result"
}

# Close a release tracker and all subtasks
# Args: $1=version (X.Y.Z)
#       $2=reason (string explaining why)
# Returns: 0 always (best-effort)
close_release_tracker() {
  local version="$1"
  version=$(_normalize_version "$version")
  local reason="$2"

  _close_release_tracker_impl "$version" "$reason" >&2 2>&1 || true
  return 0
}

_close_release_tracker_impl() {
  local version="$1"
  local reason="$2"

  _validate_version "$version" || return 0

  local parent_key
  parent_key=$(find_release_tracker "$version")
  if [ -z "$parent_key" ]; then
    echo "⚠️  No tracker found for $version" >&2
    return 0
  fi

  echo "Closing release tracker $parent_key ($version)..." >&2

  # Add closing comment on parent
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build STEP_DATA JSON safely via jq
  local step_json
  step_json=$(jq -n --arg ts "$timestamp" --arg reason "$reason" \
    '{_t:"STEP_DATA",step:"_close",timestamp:$ts,status:"closed",data:{reason:$reason}}' \
    | jq -c .)

  local comment
  comment="## Release Tracker Closed

- **Timestamp:** $timestamp
- **Reason:** $reason

---
\`\`\`STEP_DATA
$step_json
\`\`\`"

  _add_comment "$parent_key" "$comment" || true

  # Close all subtasks
  local subtasks
  subtasks=$(query_jira --jql "parent = $parent_key AND status != Closed" --fields "key,summary" 2>/dev/null) || true

  if [ -n "$subtasks" ]; then
    local keys
    keys=$(echo "$subtasks" | jq -r '.[].key // empty' 2>/dev/null)
    for key in $keys; do
      _transition_issue "$key" "$JIRA_STATUS_CLOSED" 2>/dev/null || true
    done
  fi

  # Close parent
  _transition_issue "$parent_key" "$JIRA_STATUS_CLOSED" 2>/dev/null || true

  echo "✓ Tracker closed: $parent_key" >&2
}

# ============================================================================
# Convenience Wrappers for Script Integration
# ============================================================================

# Record PR creation for a PR-tracked step
# Args: $1=version $2=step_key $3=repo $4=pr_url $5=parent_key [optional]
# Returns: 0 always
tracker_record_pr() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local repo="$3"
  local pr_url="$4"
  local parent_key="${5:-}"

  local data
  data=$(jq -n --arg repo "$repo" --arg pr "$pr_url" '{repo:$repo,pr:$pr}' | jq -c .) || data="{}"

  update_step "$version" "$step_key" "in_progress" "$data" "$parent_key"
}

# Record step completion with PR summary
# Args: $1=version $2=step_key $3=pr_summary_json $4=parent_key [optional]
# Returns: 0 always
tracker_complete_prs() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local pr_summary="$3"
  local parent_key="${4:-}"

  update_step "$version" "$step_key" "complete" "$pr_summary" "$parent_key"
}

# Record a human decision for a gate step
# Args: $1=version $2=step_key $3=decision $4=details $5=parent_key [optional]
# Returns: 0 always
tracker_record_decision() {
  local version="$1"
  version=$(_normalize_version "$version")
  local step_key="$2"
  local decision="$3"
  local details="${4:-}"
  local parent_key="${5:-}"

  local data
  data=$(jq -n --arg decision "$decision" --arg details "$details" \
    '{decision:$decision,details:$details}' | jq -c .) || data="{}"

  update_step "$version" "$step_key" "complete" "$data" "$parent_key"
}
