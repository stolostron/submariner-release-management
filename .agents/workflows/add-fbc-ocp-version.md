# Add FBC Support for New OCP Version

**When:** Red Hat releases new OCP version and ACM announces support

**Note:** This is an async/maintenance task, not tied to Submariner version releases (0.21, 0.22, etc.).
It's triggered by Red Hat's OCP release schedule and ACM's announced OCP support matrix.

## Process

### 1. Update FBC Catalog Source

Add catalog directory and Tekton pipelines for new OCP version.

**Repo:** <https://github.com/stolostron/submariner-operator-fbc>
**Local:** `~/konflux/submariner-operator-fbc`

**Workflow:** `CLAUDE.md` → `.agents/workflows/add-ocp-version.md`

### 2. Update Konflux Tenant Config

Add overlay, tenant config, and RPA entries for new OCP version.

**Repo:** <https://gitlab.cee.redhat.com/releng/konflux-release-data>
**Local:** `~/konflux/konflux-release-data`

**Workflow:** `tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/CLAUDE.md` → "Add FBC Support for New OCP Version"

### 3. Update Release Workflows (this repo)

Update OCP version ranges in bash loops. Replace `4-XX` with new version in:

- `create-fbc-stage-release.md` - Snapshot verification loops
- `create-fbc-prod-release.md` - Copy instructions
- `check-fbc-releases.md` - Status check loops
- `apply-fbc-releases.md` - Apply instructions
- `share-with-qe.md` - URL extraction loops
- `update-fbc-stage.md` - OCP version ranges in Done When

```bash
# Example: Adding 4-21 to existing 4-16 through 4-20 range
# Change: for VERSION in 16 17 18 19 20
# To:     for VERSION in 16 17 18 19 20 21
```

## Done When

- FBC repo has `catalog-4-XX/` directory on main branch
- Konflux snapshots building for new OCP version:

  ```bash
  oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "submariner-fbc-4-XX" | tail -1
  # Should show snapshot name
  ```

- ArgoCD has deployed resources (requires `oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/`):

  ```bash
  oc get application -n submariner-tenant | grep fbc-4-XX
  # Should show: submariner-fbc-4-XX

  oc get releaseplans -n submariner-tenant | grep fbc.*4-XX
  # Should show: submariner-fbc-release-plan-{stage,prod}-4-XX
  ```

- Release workflows in this repo updated with new OCP version in loops
