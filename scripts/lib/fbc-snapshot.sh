#!/bin/bash
# Both configured scenarios must have completed successfully; no empty/pending pass.
fbc_tests_passed() {
  local version="$1"
  jq -e --arg standard "submariner-fbc-standard-$version" --arg operator "submariner-fbc-operator-$version" '
    type == "array" and length >= 2 and
    all(.[]; .status == "TestPassed") and
    ([.[].scenario] | length == (unique | length)) and
    any(.[]; .scenario == $standard) and any(.[]; .scenario == $operator)
  ' >/dev/null 2>&1
}

# Event names alone cannot establish main-branch provenance: retests can be PRs.
declare -A _FBC_MERGED_REVISIONS=()
fbc_revision_on_main() {
  local revision="$1" comparison
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || return 1
  [ "${_FBC_MERGED_REVISIONS[$revision]:-}" != yes ] || return 0
  comparison=$(curl -fsS --connect-timeout 10 --max-time 30 \
    "https://api.github.com/repos/stolostron/submariner-operator-fbc/compare/${revision}...main?per_page=1") || return 1
  jq -e --arg revision "$revision" '
    .base_commit.sha == $revision and .merge_base_commit.sha == $revision and
    (.status == "ahead" or .status == "identical")
  ' <<< "$comparison" >/dev/null || return 1
  _FBC_MERGED_REVISIONS[$revision]=yes
}
