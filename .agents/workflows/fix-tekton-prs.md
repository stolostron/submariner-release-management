# Fix Tekton Config PRs

**When:** Y-stream only (0.20 → 0.21), after branch creation and downstream config

## Process

Bot generates default `.tekton/` configs for new branches that need customization and EC violation fixes.

**Repos with components** (all in <https://github.com/submariner-io>):

- `submariner-operator` (1): submariner-operator
- `submariner` (3): submariner-gateway, submariner-globalnet, submariner-route-agent
- `lighthouse` (2): lighthouse-agent, lighthouse-coredns
- `shipyard` (1): nettest
- `subctl` (1): subctl

**Note:** The `submariner-bundle` component is handled separately in Step 3b after component builds complete.

**Local:** `~/go/src/submariner-io/`

**Workflow:** Each repo's `.agents/workflows/konflux-component-setup.md`

### Version Labels (Y-stream only)

When setting up Konflux for a new branch, set the initial Dockerfile `version` labels:

```bash
# In each repo's Konflux Dockerfile(s), change:
#   version="${BASE_BRANCH}"
# To (example for 0.22):
#   version="v0.22.0"

sed -i 's/version="${BASE_BRANCH}"/version="v0.22.0"/' package/Dockerfile.*.konflux

# Bundle (submariner-operator repo only) has 3 version labels:
sed -i \
  -e 's/^LABEL csv-version="[^"]*"/LABEL csv-version="0.22.0"/' \
  -e 's/^LABEL release="[^"]*"/LABEL release="v0.22.0"/' \
  -e 's/^LABEL version="[^"]*"/LABEL version="v0.22.0"/' \
  bundle.Dockerfile.konflux
```

This enables `{{ labels.version }}` tag expansion in Konflux releases. For Z-stream bumps, see Step 5b.

## Done When

- All repos have `.tekton/` directory with config files on `release-0.X` branch:

  ```bash
  for repo in submariner-operator submariner lighthouse shipyard subctl; do
    echo -n "$repo: "
    gh api "repos/submariner-io/$repo/contents/.tekton?ref=release-0.X" --jq 'length' 2>&1 | grep -E '^[0-9]+$' || echo "missing"
  done
  # Should show file count for each repo (not "missing")
  ```

- All component builds passing (wait ~15-30 min after PRs merge):

  ```bash
  oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "submariner-0-X" | tail -5
  # Pick latest snapshot, verify all components have passing tests
  oc get snapshot <snapshot-name> -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq -r '.[] | "\(.scenario): \(.status)"'
  # All should show: TestPassed
  ```

**Next:** Proceed to Step 3b for bundle setup.
