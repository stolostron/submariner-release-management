---
name: add-team-member
description: Add user to Submariner team Konflux RBAC - updates permissions for Web UI and cluster access
version: 1.0.0
argument-hint: "<username> [admin|maintainer|contributor]"
user-invocable: true
allowed-tools: Bash
---

# Add Team Member to Submariner Konflux

Adds a user to the Submariner team's Konflux RBAC, granting them access to the Web UI and namespace.

**Usage:**

```bash
/add-team-member alice maintainer
/add-team-member bob admin
/add-team-member charlie  # Defaults to contributor (read-only)
```

**Permission Levels:**

- **admin**: Full CRUD on all resources, manage secrets/serviceaccounts
- **maintainer**: Create/update components, releases, snapshots (most users need this)
- **contributor**: Read-only access to Web UI and resources

**What it does:**

- Validates username format
- Checks if user already exists in role
- Adds user to appropriate RBAC file (alphabetically)
- Rebuilds auto-generated manifests
- Creates signed commit
- Shows review instructions

**Arguments:** $ARGUMENTS

```bash
set -euo pipefail

# Parse arguments
TARGET_USER=""
ROLE="contributor"  # Default (least privilege)

if [ -z "$ARGUMENTS" ]; then
  echo "❌ Error: Username required"
  echo "   Usage: /add-team-member <username> [admin|maintainer|contributor]"
  exit 1
fi

# Parse space-separated arguments
read -r TARGET_USER ROLE_ARG <<< "$ARGUMENTS"

# Override default role if provided
if [ -n "${ROLE_ARG:-}" ]; then
  ROLE="$ROLE_ARG"
fi

# ━━━ PREREQUISITES VALIDATION ━━━

# Validate role
case "$ROLE" in
  admin|maintainer|contributor)
    ;;
  admins|maintainers|contributors)
    # Allow plural form, convert to singular
    ROLE="${ROLE%s}"
    ;;
  *)
    echo "❌ Error: Invalid role '$ROLE'"
    echo "   Valid roles: admin, maintainer, contributor"
    exit 1
    ;;
esac

# Validate username format (Red Hat kerberos usernames)
echo "$TARGET_USER" | grep -qE '^[a-z][a-z0-9]{0,7}$' || {
  echo "❌ Error: Invalid username format '$TARGET_USER'"
  echo "   Expected: lowercase letters/numbers, 1-8 chars, starting with letter"
  echo "   Examples: dfarrell, vthapar, skitt"
  exit 1
}

echo "✓ Input validation:"
echo "  Username: $TARGET_USER"
echo "  Role:     $ROLE"
echo ""

# Change to konflux-release-data repository
cd ~/konflux/konflux-release-data || {
  echo "❌ Error: konflux-release-data repository not found at ~/konflux/konflux-release-data"
  exit 1
}

# Verify repository structure
test -f "tenants-config/build-single.sh" || {
  echo "❌ Error: Invalid konflux-release-data repository (missing build-single.sh)"
  exit 1
}

# Check git status
git diff-index --quiet HEAD -- 2>/dev/null || {
  echo "❌ Error: Working tree has uncommitted changes"
  echo "   Commit or stash changes before running this skill"
  git status --short
  exit 1
}

RBAC_FILE="tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/rbac-${ROLE}s.yaml"

# Verify RBAC file exists
if [ ! -f "$RBAC_FILE" ]; then
  echo "❌ Error: RBAC file not found: $RBAC_FILE"
  exit 1
fi

# ━━━ CHECK IF USER ALREADY EXISTS ━━━

# Match only user names (4-space indent), not metadata.name or roleRef.name
if grep -q "^    name: $TARGET_USER$" "$RBAC_FILE"; then
  echo "⚠️  User '$TARGET_USER' already exists in $ROLE role"
  echo ""
  echo "Current ${ROLE}s:"
  grep "^    name: " "$RBAC_FILE" | sed 's/.*name: /  - /'
  echo ""
  echo "No changes needed."
  exit 0
fi

# Create feature branch (delete if exists from previous run)
BRANCH="add-${TARGET_USER}-${ROLE}"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  # Branch exists - check if it's safe to delete
  if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    echo "❌ Error: Branch $BRANCH exists locally and on remote"
    echo "   Please delete manually: git branch -D $BRANCH"
    exit 1
  fi

  # Local branch only - safe to delete and recreate
  git branch -D "$BRANCH" >/dev/null 2>&1
fi

git checkout -b "$BRANCH" || {
  echo "❌ Error: Failed to create branch $BRANCH"
  exit 1
}

# ━━━ ADD USER TO RBAC FILE ━━━

echo "Adding $TARGET_USER to rbac-${ROLE}s.yaml..."

# Add user to subjects array and sort all entries alphabetically by name
yq eval '.subjects += [{"apiGroup": "rbac.authorization.k8s.io", "kind": "User", "name": "'$TARGET_USER'"}] | .subjects |= sort_by(.name)' -i "$RBAC_FILE"

# Verify user was added
if ! grep -q "^    name: $TARGET_USER$" "$RBAC_FILE"; then
  echo "❌ Error: Failed to add user to $RBAC_FILE"
  exit 1
fi

# Validate YAML structure
if ! command -v yamllint >/dev/null 2>&1; then
  echo "❌ Error: yamllint not found (required for validation)"
  echo "   Install: pip install yamllint"
  exit 1
fi

yamllint "$RBAC_FILE" || {
  echo "❌ Error: YAML validation failed for $RBAC_FILE"
  exit 1
}

echo "   ✓ User added to $RBAC_FILE"

# ━━━ REBUILD AUTO-GENERATED MANIFESTS ━━━

echo "Rebuilding auto-generated manifests..."

# Use subshell to avoid cd back
(cd tenants-config && ./build-single.sh submariner-tenant) >/dev/null 2>&1 || {
  echo "❌ Error: build-single.sh failed"
  exit 1
}

# Verify auto-generated file was updated (uses 2-space indent, not 4)
AUTO_GEN_FILE="tenants-config/auto-generated/cluster/kflux-prd-rh02/tenants/submariner-tenant/rbac.authorization.k8s.io_v1_rolebinding_submariner-tenant-konflux-${ROLE}s.yaml"

if ! grep -q "^  name: $TARGET_USER$" "$AUTO_GEN_FILE"; then
  echo "❌ Error: Auto-generated file not updated: $AUTO_GEN_FILE"
  exit 1
fi

echo "   ✓ Auto-generated manifests rebuilt"

# ━━━ CREATE COMMIT ━━━

git add "$RBAC_FILE"
git add "tenants-config/auto-generated/cluster/kflux-prd-rh02/tenants/submariner-tenant/"

git commit -s -m "Add $TARGET_USER to submariner-tenant ${ROLE}s

Grants $ROLE access to Submariner Konflux namespace and Web UI."

echo ""
echo "✅ Successfully added $TARGET_USER as submariner-tenant $ROLE"
echo "   Branch: $BRANCH"
echo ""

# ━━━ SHOW CURRENT TEAM ━━━

echo "Current ${ROLE}s:"
grep "^    name: " "$RBAC_FILE" | sed 's/.*name: /  - /'
echo ""

# ━━━ SUMMARY ━━━

echo "━━━ SUMMARY ━━━"
echo ""
echo "📝 Changes committed:"
echo "   - Source: $RBAC_FILE"
echo "   - Auto-generated: $AUTO_GEN_FILE"
echo ""
echo "🔑 Permission level: $ROLE"
case "$ROLE" in
  admin)
    echo "   - Full CRUD on Applications, Components, Snapshots, Releases"
    echo "   - Manage Secrets, ConfigMaps, ServiceAccounts, RoleBindings"
    echo "   - Create/delete PipelineRuns"
    ;;
  maintainer)
    echo "   - Create/update Applications, Components, Snapshots, Releases"
    echo "   - View PipelineRuns, TaskRuns, logs"
    echo "   - Read ConfigMaps (no Secrets management)"
    ;;
  contributor)
    echo "   - Read-only access to all resources"
    echo "   - View Applications, Components, Snapshots, Releases"
    echo "   - View PipelineRuns, TaskRuns, logs"
    ;;
esac
echo ""
echo "🌐 Web UI: https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/"
echo "   Access granted after push + ArgoCD deploy (~5-10 min)"
echo ""
echo "🚀 Next steps:"
echo "   1. Review: git show"
echo "   2. Push: git push origin $BRANCH"
echo "   3. Create MR in GitLab (auto-opens in browser after push)"
echo "   4. After merge, verify: oc get rolebinding submariner-tenant-konflux-${ROLE}s -n submariner-tenant -o yaml"
```
