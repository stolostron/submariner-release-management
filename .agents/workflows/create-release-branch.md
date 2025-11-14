# Create Upstream Release Branch

**When:** Y-stream only (0.20 → 0.21), during RC0 cut

## Process

Create `release-0.X` branches in upstream repos.

**Repo:** <https://github.com/submariner-io/releases>
**Local:** `~/go/src/submariner-io/releases`

**Workflow:** README.md in that repo

## Done When

- `release-0.X` branch exists on GitHub:

  ```bash
  # Check one repo - releases tool creates branches atomically across all repos
  git ls-remote --heads https://github.com/submariner-io/submariner-operator refs/heads/release-0.X
  # Should show: <commit-sha> refs/heads/release-0.X
  ```
