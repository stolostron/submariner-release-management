#!/bin/bash
# Review a single Jira issue for release notes inclusion
# Pre-fetches all evidence, then asks Claude to evaluate it
# Args: ISSUE_KEY VERSION STAGE_YAML
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 ISSUE_KEY VERSION STAGE_YAML" >&2
  exit 1
fi

ISSUE_KEY="$1"
VERSION="$2"
STAGE_YAML="$3"
VERSION_MAJOR_MINOR="${VERSION%.*}"
MINOR_VERSION="${VERSION_MAJOR_MINOR##*.}"
ACM_VERSION="ACM 2.$((MINOR_VERSION - 7)).0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/review-prompt.md"

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
  echo "❌ ERROR: Prompt template not found: $PROMPT_TEMPLATE" >&2
  exit 1
fi

# ============================================================================
# Pre-fetch all evidence (deterministic, no LLM needed)
# ============================================================================

# Jira details (including comments — often contain PR/commit links)
JIRA_JSON=$(acli jira workitem view "$ISSUE_KEY" \
  --fields "summary,status,resolution,components,labels,fixVersions,issuelinks,description,comment" \
  --json </dev/null 2>/dev/null) || JIRA_JSON="{}"

SUMMARY=$(jq -r '.fields.summary // ""' <<< "$JIRA_JSON")
COMPONENTS=$(jq -r '[.fields.components[]?.name] | join(", ")' <<< "$JIRA_JSON")

# Extract keywords from summary + description (remove stopwords and noise)
DESCRIPTION=$(jq -r '[.fields.description | .. | .text? // empty] | join(" ")' <<< "$JIRA_JSON" 2>/dev/null)
KEYWORDS=$(echo "$SUMMARY $DESCRIPTION" | tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9 ]/ /g' | tr ' ' '\n' | \
  grep -vxE '.{0,2}|the|and|for|not|with|from|that|this|are|was|has|have|been|able|after|between|all|old|new|add|update|remove|review|ensure|create|issues|known|support|submariner|version|release|number|selected|component|applicable|problem|description|reproducible|steps|reproduce|actual|expected|additional|info|environment|cluster|clusters|managed|error|failed|following|getting|output|using|should|would|could|does|also' | \
  grep -vxE '[0-9a-f]{5,}' | \
  sort | uniq -c | sort -rn | awk '{print $2}' | head -10 || true)

# Extract GitHub/PR links from Jira comments (often the best evidence source)
COMMENT_LINKS=$(jq -r '[.fields.comment.comments[]? | [.body | .. | .text? // empty] | join(" ")] | join(" ")' <<< "$JIRA_JSON" 2>/dev/null | \
  grep -oE "https://github\.com/[^ \"')>]+" | sort -u || echo "")

# GitHub PR search
GH_PRS_SUBMARINER=$(gh search prs "$ISSUE_KEY" --owner submariner-io --json title,url,repository --limit 5 2>/dev/null || echo "[]")
GH_PRS_STOLOSTRON=$(gh search prs "$ISSUE_KEY" --owner stolostron --json title,url,repository --limit 5 2>/dev/null || echo "[]")
GH_PRS_DOCS=$(gh search prs "$ISSUE_KEY" --repo stolostron/rhacm-docs --json title,url --limit 5 2>/dev/null || echo "[]")

# DFBUGS link check — search issuelinks, description, and comments
# (developers often paste DFBUGS links in text without creating formal links)
ALL_TEXT=$(jq -r '([.fields.description | .. | .text? // empty] + [.fields.comment.comments[]? | .body | .. | .text? // empty]) | join(" ")' <<< "$JIRA_JSON" 2>/dev/null || echo "")
DFBUGS_KEY=$(jq -r '[.fields.issuelinks[]? | (.outwardIssue.key // .inwardIssue.key // "") | select(startswith("DFBUGS-"))] | first // ""' <<< "$JIRA_JSON")
if [[ -z "$DFBUGS_KEY" ]]; then
  # Check description and comments for DFBUGS references
  DFBUGS_KEY=$(echo "$ALL_TEXT" | grep -oE "DFBUGS-[0-9]+" | head -1 || true)
fi
DFBUGS_STATUS=""
if [[ -n "$DFBUGS_KEY" ]]; then
  DFBUGS_STATUS=$(acli jira workitem view "$DFBUGS_KEY" --fields "status" --json </dev/null 2>/dev/null | jq -r '.fields.status.name // ""' 2>/dev/null || echo "")
fi

# Git log search across repos (use keywords from summary)
GIT_EVIDENCE=""
for REPO in submariner submariner-operator lighthouse subctl shipyard cloud-prepare; do
  REPO_DIR="$HOME/go/src/submariner-io/$REPO"
  [[ -d "$REPO_DIR" ]] || continue

  HITS=""
  # Collect useful keywords (skip noisy ones with >15 hits in this repo)
  USEFUL_KWS=()
  NOISY_KWS=()
  for KW in $KEYWORDS; do
    HIT_COUNT=$(cd "$REPO_DIR" && git log "origin/release-${VERSION_MAJOR_MINOR}" --oneline -i --grep="$KW" 2>/dev/null | wc -l || true)
    if [[ "$HIT_COUNT" -gt 15 ]]; then
      NOISY_KWS+=("$KW")
      continue
    fi
    USEFUL_KWS+=("$KW")
    RESULT=$(cd "$REPO_DIR" && git log "origin/release-${VERSION_MAJOR_MINOR}" --oneline -i --grep="$KW" 2>/dev/null | head -3 || true)
    if [[ -n "$RESULT" ]]; then
      HITS+="  keyword '$KW' ($HIT_COUNT hits):
$RESULT
"
    fi
  done

  # If all keywords were noisy, try combining pairs (--all-match)
  if [[ ${#USEFUL_KWS[@]} -eq 0 && ${#NOISY_KWS[@]} -ge 2 ]]; then
    KW1="${NOISY_KWS[0]}"
    KW2="${NOISY_KWS[1]}"
    RESULT=$(cd "$REPO_DIR" && git log "origin/release-${VERSION_MAJOR_MINOR}" --oneline -i --grep="$KW1" --grep="$KW2" --all-match 2>/dev/null | head -3 || true)
    if [[ -n "$RESULT" ]]; then
      HITS+="  combined '$KW1'+'$KW2':
$RESULT
"
    fi
  fi

  if [[ -n "$HITS" ]]; then
    GIT_EVIDENCE+="
$REPO (release-${VERSION_MAJOR_MINOR}):
$HITS"
  fi
done

# Cross-squad addon check (if multiple components)
ADDON_PRS="[]"
COMP_COUNT=$(jq '[.fields.components[]?.name] | length' <<< "$JIRA_JSON")
if [[ "$COMP_COUNT" -gt 1 ]]; then
  # Search addon repo by keywords
  for KW in $KEYWORDS; do
    RESULT=$(gh search prs "$KW" --repo stolostron/submariner-addon --json title,url --limit 3 2>/dev/null || echo "[]")
    if jq -e 'length > 0' <<< "$RESULT" >/dev/null 2>&1; then
      ADDON_PRS="$RESULT"
      break
    fi
  done
fi

# ============================================================================
# Build prompt with pre-fetched evidence
# ============================================================================

# Export variables for envsubst
export ISSUE_KEY VERSION STAGE_YAML VERSION_MAJOR_MINOR ACM_VERSION

# Build the evidence block
EVIDENCE="## Pre-fetched Evidence for ${ISSUE_KEY}

### Jira Details
\`\`\`json
$(jq '{summary: .fields.summary, status: .fields.status.name, resolution: (.fields.resolution.name // "Unresolved"), components: [.fields.components[]?.name], labels: .fields.labels, fixVersions: [.fields.fixVersions[]?.name], links: [.fields.issuelinks[]? | {type: .type.name, key: (.outwardIssue.key // .inwardIssue.key), summary: (.outwardIssue.fields.summary // .inwardIssue.fields.summary // "")[:70]}], description_excerpt: ([.fields.description | .. | .text? // empty] | join(" ") | .[:500])}' <<< "$JIRA_JSON" 2>/dev/null)
\`\`\`

### DFBUGS Tracker
$(if [[ -n "$DFBUGS_KEY" ]]; then echo "Found: $DFBUGS_KEY — status: $DFBUGS_STATUS"; else echo "None found in issue links."; fi)

### GitHub Links from Jira Comments
$(if [[ -n "$COMMENT_LINKS" ]]; then echo "$COMMENT_LINKS"; else echo "None found."; fi)

### GitHub PRs (by issue key)
submariner-io: $(jq -r 'if length == 0 then "none" else [.[] | "\(.repository.name): \(.title)"] | join("; ") end' <<< "$GH_PRS_SUBMARINER")
stolostron: $(jq -r 'if length == 0 then "none" else [.[] | "\(.repository.nameWithOwner // .repository.name): \(.title)"] | join("; ") end' <<< "$GH_PRS_STOLOSTRON")
rhacm-docs: $(jq -r 'if length == 0 then "none" else [.[] | .title] | join("; ") end' <<< "$GH_PRS_DOCS")

### Git History (keyword search on release-${VERSION_MAJOR_MINOR} branch)
$(if [[ -n "$GIT_EVIDENCE" ]]; then echo "$GIT_EVIDENCE"; else echo "No matching commits found for keywords: $KEYWORDS"; fi)

$(if [[ "$COMP_COUNT" -gt 1 ]]; then echo "### Cross-squad Addon Check
Components: $COMPONENTS (multi-component issue)
Addon PRs: $(jq -r 'if length == 0 then "none" else [.[] | .title] | join("; ") end' <<< "$ADDON_PRS")"; fi)
"

# Build full prompt
PROMPT_BASE=$(envsubst < "$PROMPT_TEMPLATE")
PROMPT="${PROMPT_BASE}

${EVIDENCE}"

# ============================================================================
# Invoke Claude to evaluate the evidence
# ============================================================================

OUTPUT=$(claude -p "$PROMPT" \
  --print \
  --model sonnet \
  --allowedTools "Bash" \
  --dangerously-skip-permissions \
  2>&1) || true

# Extract and display result (flexible matching — agent may indent, use markdown, etc.)
# Use tail -1 to prefer the agent's final decision line over prompt quotes in reasoning
if echo "$OUTPUT" | grep -qiE "^\*{0,2}REMOVE"; then
  REASON=$(echo "$OUTPUT" | grep -oiE "REMOVE:?\*{0,2} .*" | tail -1 | sed 's/^[*]*REMOVE:*[*]* *//')
  echo "  ✗ REMOVE $ISSUE_KEY - $REASON"
elif echo "$OUTPUT" | grep -qiE "KEEP:"; then
  REASON=$(echo "$OUTPUT" | grep -oiE "KEEP:?\*{0,2} .*" | tail -1 | sed 's/^[*]*KEEP:*[*]* *//')
  echo "  ✓ KEEP  $ISSUE_KEY - ${REASON:-issue passes review}"
elif echo "$OUTPUT" | grep -qiE "KEEP"; then
  echo "  ✓ KEEP  $ISSUE_KEY - issue passes review"
else
  echo "  ? KEEP  $ISSUE_KEY - agent output unclear, keeping by default"
fi
