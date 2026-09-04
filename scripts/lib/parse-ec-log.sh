#!/bin/bash
# Parse a downloaded Konflux EC (Enterprise Contract) log file and extract
# actionable signal: failing rules, affected task names, and whether a task
# version bump can fix the failures.
#
# Usage:
#   parse-ec-log.sh <log-file>
#
# Output (stdout, structured text):
#
#   FAILING_RULES:
#     <rule-name> ...
#
#   AFFECTED_TASKS:
#     <task-name> ...
#
#   FIXABLE_BY_VERSION_BUMP: yes|no|unknown
#
# Exit codes:
#   0 — parsed; may have zero or more violations
#   1 — log file not found or unreadable
#   2 — no EC report section found (wrong file, or log from a passing run)
#
# Parsing strategy:
#   The EC log contains a "Success: " / "Failure: " summary block between the
#   marker lines produced by the ec-cli task. Within that block:
#     - Rule names appear after "msg=" or as "Name: <rule>" lines
#     - Task names appear after "Term:" — these are the tasks EC says are missing
#       or at the wrong version
#
# This is intentionally a dumb text-extractor. The caller (the agent or the
# tekton-task-version-bump.sh script) decides what to do with the output.

set -euo pipefail

LOG_FILE="${1:-}"

if [ -z "$LOG_FILE" ]; then
  echo "Usage: $0 <log-file>" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "Error: log file not found: $LOG_FILE" >&2
  exit 1
fi

if [ ! -r "$LOG_FILE" ]; then
  echo "Error: log file not readable: $LOG_FILE" >&2
  exit 1
fi

# ── Extract the EC report section ─────────────────────────────────────────────
# The ec-cli task emits a block starting with "Success: " or "Failure: " that
# contains the structured violation/warning counts. Extract lines between the
# first occurrence of that marker and the debug output footer.
# Use `|| true` to suppress SIGPIPE exit (141) when head -c closes early on large logs.
# set -euo pipefail treats the sed SIGPIPE as a fatal error without the guard.
EC_REPORT=$(sed -n '/^[[:space:]]*\(Success\|Failure\): /,/^----- DEBUG OUTPUT -----/p' "$LOG_FILE" 2>/dev/null | head -c 200000 || true)

if [ -z "$EC_REPORT" ]; then
  # Try the simpler marker used in some log variants
  EC_REPORT=$(sed -n '/^[[:space:]]*\(Passed\|Failed\)$/,/^$/p' "$LOG_FILE" 2>/dev/null | head -c 200000 || true)
fi

if [ -z "$EC_REPORT" ]; then
  echo "Error: no EC report section found in $(basename "$LOG_FILE")" >&2
  echo "  Expected markers: 'Success:' or 'Failure:' followed by '----- DEBUG OUTPUT -----'" >&2
  echo "  This may not be an EC log, or the log is from a passing run with no violations." >&2
  exit 2
fi

# ── Extract failing rule names ─────────────────────────────────────────────────
# Rule names appear in three formats depending on which EC log section is present:
#   1. JSON:   "msg":"rule.name" or msg="rule.name"
#   2. Text:   "Name: rule.name"
#   3. Text:   "✕ [Violation] rule.name"  (the primary format in STEP-VALIDATE output)
#   4. JSON:   "code":"rule.name"
# msg= fields contain human-readable text; filter to dotted rule-name tokens only
RULES_FROM_MSG=$(printf '%s' "$EC_REPORT" | grep -oP '(?<="msg"|msg=")[^"]+' 2>/dev/null \
  | grep -oE '^[a-z_]+\.[a-z_]+(\.[a-z_]+)*$' | sort -u || true)
# Filter Name: matches to exclude component names (sha256 digests, image refs) but keep rule names
RULES_FROM_NAME=$(printf '%s' "$EC_REPORT" | grep -oP '(?<=^|\s)Name:\s+\K\S+' 2>/dev/null \
  | grep -v '@sha256\|sha256:\|quay\.io\|registry\.' | sort -u || true)
# Primary format: "✕ [Violation] rule.name" lines in STEP-VALIDATE text output
RULES_FROM_VIOLATION=$(printf '%s' "$EC_REPORT" | grep -oP '(?<=✕ \[Violation\] )\S+' 2>/dev/null | sort -u || true)
# Also catch "code:" style rule identifiers (e.g. required_tasks.missing_required_task)
RULES_FROM_CODE=$(printf '%s' "$EC_REPORT" | grep -oP '(?<="code"|code=")[^"]+' 2>/dev/null \
  | grep '\.' | grep -v '@sha256\|sha256:' | sort -u || true)

ALL_RULES=$(printf '%s\n%s\n%s\n%s\n' "$RULES_FROM_MSG" "$RULES_FROM_NAME" "$RULES_FROM_VIOLATION" "$RULES_FROM_CODE" \
  | grep -v "^$" | sort -u || true)

# ── Extract affected task names ────────────────────────────────────────────────
# EC reports task names after "Term:" — these are tasks that are missing or at
# the wrong version. Scope to Term: lines following Violation markers only, not
# Warning blocks (which also have Term: lines for outdated-but-not-blocking tasks).
AFFECTED_TASKS=$(printf '%s' "$EC_REPORT" \
  | awk '/✕ \[Violation\]/{in_v=1} in_v && /^[[:space:]]*Term:/{print $2} /^[[:space:]]*$/{in_v=0}' \
  | sort -u | grep -v "^$" || true)
# Fall back to all Term: lines if the violation-scoped extraction produced nothing
# (handles log variants that don't use the ✕ marker)
if [ -z "$AFFECTED_TASKS" ]; then
  AFFECTED_TASKS=$(printf '%s' "$EC_REPORT" | grep "Term:" | awk '{print $2}' | sort -u | grep -v "^$" || true)
fi

# ── Determine fixability ───────────────────────────────────────────────────────
# "Fixable by version bump" means the failing rules are about task versions or
# missing required tasks — the kinds ec-fix addresses. Rules about signatures,
# SBOM, Dockerfile, operator content, or custom policies need different fixes.
#
# trusted_task.trusted and slsa_build_scripted_build.image_built_by_trusted_task
# are also fixable by bumping the SHA reference — they mean an untrusted SHA is
# in the pipeline, which pipeline-patcher corrects.
TASK_RELATED_RULES=$(printf '%s' "$ALL_RULES" | grep -iE \
  "required_tasks|missing_required_task|missing_required_step_runner|task.*version|tasks\.|trusted_task|slsa_build_scripted_build" \
  2>/dev/null || true)
TASK_RELATED_RULES=$(printf '%s' "$TASK_RELATED_RULES" | grep -v "^$" || true)

NON_TASK_RULES=$(printf '%s' "$ALL_RULES" | grep -ivE \
  "required_tasks|missing_required_task|missing_required_step_runner|task.*version|tasks\.|trusted_task|slsa_build_scripted_build" \
  2>/dev/null || true)
NON_TASK_RULES=$(printf '%s' "$NON_TASK_RULES" | grep -v "^$" || true)

# Use AFFECTED_TASKS as a signal only when there are also rule violations to confirm it.
# A passing log can have Term: lines in Warning blocks — AFFECTED_TASKS alone without
# any failing rules should not cause a "yes" classification.
if [ -z "$ALL_RULES" ] && [ -z "$AFFECTED_TASKS" ]; then
  FIXABLE="unknown"
elif [ -n "$TASK_RELATED_RULES" ] || { [ -n "$AFFECTED_TASKS" ] && [ -n "$ALL_RULES" ]; }; then
  if [ -z "$NON_TASK_RULES" ]; then
    FIXABLE="yes"
  else
    FIXABLE="partial"  # some rules fixable, some need manual intervention
  fi
elif [ -n "$ALL_RULES" ]; then
  FIXABLE="no"
else
  FIXABLE="unknown"
fi

# ── Emit structured output ────────────────────────────────────────────────────
echo "FAILING_RULES:"
if [ -n "$ALL_RULES" ]; then
  printf '%s\n' "$ALL_RULES" | sed 's/^/  /'
else
  echo "  (none detected)"
fi

echo ""
echo "AFFECTED_TASKS:"
if [ -n "$AFFECTED_TASKS" ]; then
  printf '%s\n' "$AFFECTED_TASKS" | sed 's/^/  /'
else
  echo "  (none detected)"
fi

echo ""
echo "FIXABLE_BY_VERSION_BUMP: $FIXABLE"

if [ "$FIXABLE" = "partial" ] || [ "$FIXABLE" = "no" ]; then
  echo ""
  echo "NON_TASK_RULES (require manual fix):"
  if [ -n "$NON_TASK_RULES" ]; then
    printf '%s\n' "$NON_TASK_RULES" | sed 's/^/  /'
  else
    echo "  (none identified — check FAILING_RULES above)"
  fi
fi
