# Fix Tekton Config PRs

**When:** Y-stream only (0.20 → 0.21), after branch creation

## Process

Bot generates default `.tekton/` configs for new branches that need customization and EC violation fixes.

**Repos with components** (all in <https://github.com/submariner-io>):

- `submariner-operator` (2): submariner-operator, submariner-bundle
- `submariner` (3): submariner-gateway, submariner-globalnet, submariner-route-agent
- `lighthouse` (2): lighthouse-agent, lighthouse-coredns
- `shipyard` (1): nettest
- `subctl` (1): subctl

**Local:** `~/go/src/submariner-io/`

**Workflow:** Each repo's `.agents/workflows/konflux-branch-setup.md`

## Done When

- All repos have `.tekton/` directory with config files on `release-0.X` branch:

  ```bash
  for repo in submariner-operator submariner lighthouse shipyard subctl; do
    echo -n "$repo: "
    gh api "repos/submariner-io/$repo/contents/.tekton?ref=release-0.X" --jq 'length' 2>&1 | grep -E '^[0-9]+$' || echo "missing"
  done
  # Should show file count for each repo (not "missing")
  ```
