# Fix Tekton Config PRs

**When:** Y-stream only (0.20 → 0.21), after branch creation

Bot generates default `.tekton/` configs for new branches that need customization and EC violation fixes.

**Repos with components** (all in <https://github.com/submariner-io>):

- `submariner-operator` (2): submariner-operator, submariner-bundle
- `submariner` (3): submariner-gateway, submariner-globalnet, submariner-route-agent
- `lighthouse` (2): lighthouse-agent, lighthouse-coredns
- `shipyard` (1): nettest
- `subctl` (1): subctl

**Local:** `~/go/src/submariner-io/`

**Workflow:** Each repo's `.agents/workflows/konflux-branch-setup.md`
