---
name: configure-downstream
description: Configure Konflux for new Submariner version - creates overlays, tenant config, and RPAs for Y-stream releases.
version: 1.0.0
argument-hint: "<new-version>"
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# Configure Downstream Release

Configures Konflux CI/CD for a new Submariner minor version (Y-stream releases).

**Usage:**

```bash
/configure-downstream 0.23
/configure-downstream 0.23.0  # Extracts major.minor automatically
```

**What it does:**

- Auto-detects previous version from existing overlays
- Creates 3 commits with 49 total files:
  - Commit 1: 26 YAML overlay files
  - Commit 2: 22 auto-generated Kustomize manifests
  - Commit 3: 2 ReleasePlanAdmission files (stage + prod)
- Verifies all changes before committing
- Stops user before push for review

**Arguments:** $ARGUMENTS

```bash
set -euo pipefail

INPUT_VERSION="$ARGUMENTS"

# ━━━ PREREQUISITES VALIDATION ━━━

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

# Require main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "❌ Error: Must be on main branch"
  echo "   Current branch: $CURRENT_BRANCH"
  echo "   Run: git checkout main"
  exit 1
fi

# ━━━ VERSION AUTO-DETECTION ━━━

# Validate format: 0.Y or 0.Y.Z (Submariner major version is always 0)
echo "$INPUT_VERSION" | grep -qE '^0\.[0-9]+(\.[0-9]+)?$' || {
  echo "❌ Error: Invalid version format '$INPUT_VERSION'"
  echo "   Expected: 0.Y or 0.Y.Z (e.g., 0.23 or 0.23.1)"
  exit 1
}

# Extract major.minor (0.23.1 → 0.23)
MAJOR_MINOR=$(echo "$INPUT_VERSION" | grep -oE '^[0-9]+\.[0-9]+')
NEW_MINOR=$(echo "$MAJOR_MINOR" | cut -d. -f2)

# Convert to hyphenated format (NEW version)
NEW="0-${NEW_MINOR}"

# Check if version already exists
OVERLAY_DIR="$HOME/konflux/konflux-release-data/tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/overlay/application-submariner"
if [ -d "${OVERLAY_DIR}/${NEW}-overlay" ]; then
  echo "❌ Error: Version ${MAJOR_MINOR} already configured"
  echo "   Overlay directory exists: ${NEW}-overlay"
  exit 1
fi

# Find all existing overlays and extract minor versions
EXISTING_VERSIONS=$(ls -1d "${OVERLAY_DIR}"/[0-9]*-overlay 2>/dev/null | \
  xargs -n1 basename | sed 's/-overlay$//' | sed 's/^0-//' | sort -n)

if [ -z "$EXISTING_VERSIONS" ]; then
  echo "❌ Error: No previous versions found"
  echo "   Cannot auto-detect without existing overlays"
  echo "   Expected at least one directory matching: ${OVERLAY_DIR}/0-*-overlay"
  exit 1
fi

# Get most recent (highest) version
PREV_MINOR=$(echo "$EXISTING_VERSIONS" | tail -1)
PREV="0-${PREV_MINOR}"

# Calculate ACM versions: Submariner 0.X → ACM 2.(X-7)
PREV_ACM="2.$((PREV_MINOR - 7))"
NEW_ACM="2.$((NEW_MINOR - 7))"

# Validate ACM versions are positive
if [ "$((NEW_MINOR - 7))" -lt 0 ]; then
  echo "❌ Error: ACM version would be negative: 2.$((NEW_MINOR - 7))"
  echo "   Minimum supported version is 0.7 (ACM 2.0)"
  exit 1
fi

echo "✓ Version detection:"
echo "  Previous: ${PREV} (ACM ${PREV_ACM})"
echo "  New:      ${NEW} (ACM ${NEW_ACM})"
echo ""

# ━━━ COMMIT 1: CREATE OVERLAY STRUCTURE (26 files) ━━━

cd "${OVERLAY_DIR}"

# Copy overlay
cp -r "${PREV}-overlay" "${NEW}-overlay"
cd "${NEW}-overlay"

# Replace all version strings (3 patterns)
find . -name "*.yaml" -exec sed -i \
    -e "s/$PREV/$NEW/g" \
    -e "s/${PREV//-/.}/${NEW//-/.}/g" \
    -e "s/\/$PREV_ACM\//\/$NEW_ACM\//g" {} +

# Verify (5 checks with specific error messages)
FILE_COUNT=$(find . -name "*.yaml" | wc -l)
[ "$FILE_COUNT" -eq 26 ] || { echo "❌ Expected 26 YAML files, found $FILE_COUNT"; exit 1; }

grep -q "nameSuffix: -$NEW" kustomization.yaml || { echo "❌ nameSuffix not updated in kustomization.yaml"; exit 1; }

grep -q "value: submariner-$NEW" *.yaml || { echo "❌ Application name not updated to submariner-$NEW"; exit 1; }

grep -q "value: release-${NEW//-/.}" component-patch.yaml || { echo "❌ Git branch not updated to release-${NEW//-/.}"; exit 1; }

if grep -rEq "${PREV}|${PREV//-/.}|${PREV_ACM}" .; then
  echo "❌ Old version references still present:"
  grep -rE "${PREV}|${PREV//-/.}|${PREV_ACM}" . | head -3
  exit 1
fi

echo "   ✓ All verifications passed"

# Commit
cd "$(git rev-parse --show-toplevel)"
git add "tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/overlay/application-submariner/${NEW}-overlay"
git commit -s -m "Add Submariner v${NEW//-/.} overlay structure"

echo "✅ Commit 1: Created overlay structure (26 files)"
echo "   - Copied ${PREV}-overlay → ${NEW}-overlay"
echo "   - Updated version strings (${PREV} → ${NEW}, ${PREV_ACM} → ${NEW_ACM})"
echo "   - Verified: nameSuffix, application name, git branch, no old versions"
echo "   - Committed: Add Submariner v${NEW//-/.} overlay structure"
echo ""

# ━━━ COMMIT 2: ENABLE OVERLAY IN TENANT CONFIG (22 files) ━━━

cd ~/konflux/konflux-release-data/tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant

# Add to kustomization.yaml (idempotent)
grep -q "overlay/application-submariner/$NEW-overlay" kustomization.yaml || {
  sed -i "/overlay\\/application-submariner\\/$PREV-overlay/a\\  - overlay/application-submariner/$NEW-overlay" kustomization.yaml
}

# Build manifests
cd ~/konflux/konflux-release-data/tenants-config
./build-single.sh submariner-tenant

# Verify (auto-generated files use hyphenated names like submariner-0-23.yaml)
COUNT=$(ls "auto-generated/cluster/kflux-prd-rh02/tenants/submariner-tenant/"*"-${NEW}.yaml" 2>/dev/null | wc -l)
[ "$COUNT" -eq 22 ] || { echo "❌ Error: Expected 22 auto-generated files, found $COUNT"; exit 1; }

# Commit
cd "$(git rev-parse --show-toplevel)"
git add tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant/kustomization.yaml
git add tenants-config/auto-generated/cluster/kflux-prd-rh02/tenants/submariner-tenant/
git commit -s -m "Enable Submariner v${NEW//-/.} in tenant config"

echo "✅ Commit 2: Enabled overlay in tenant config (22 files)"
echo "   - Added overlay entry to kustomization.yaml"
echo "   - Ran build-single.sh submariner-tenant"
echo "   - Generated 22 auto-generated manifests"
echo "   - Committed: Enable Submariner v${NEW//-/.} in tenant config"
echo ""

# ━━━ COMMIT 3: ADD STAGE/PROD RPAs (2 files) ━━━

cd ~/konflux/konflux-release-data/config/kflux-prd-rh02.0fk9.p1/product/ReleasePlanAdmission/submariner

# Copy RPAs
cp "submariner-release-plan-admission-prod-$PREV.yaml" "submariner-release-plan-admission-prod-$NEW.yaml"
cp "submariner-release-plan-admission-stage-$PREV.yaml" "submariner-release-plan-admission-stage-$NEW.yaml"

# Replace version strings (4 patterns)
sed -i -e "s/$PREV/$NEW/g" \
       -e "s/${PREV//-/.}/${NEW//-/.}/g" \
       -e "s/\"$PREV_ACM\"/\"$NEW_ACM\"/g" \
       -e "s/\\/$PREV_ACM\\//\\/$NEW_ACM\\//g" \
       "submariner-release-plan-admission-"*"-$NEW.yaml"

# Verify (5 checks with specific error messages)
grep -q "intention: staging" "submariner-release-plan-admission-stage-$NEW.yaml" || { echo "❌ Stage RPA intention not 'staging'"; exit 1; }

grep -q "intention: production" "submariner-release-plan-admission-prod-$NEW.yaml" || { echo "❌ Prod RPA intention not 'production'"; exit 1; }

COMPONENT_COUNT=$(grep -c "url: registry" "submariner-release-plan-admission-prod-$NEW.yaml")
[ "$COMPONENT_COUNT" -eq 9 ] || { echo "❌ Expected 9 components in RPA, found $COMPONENT_COUNT"; exit 1; }

grep -q "product_version: \"$NEW_ACM\"" "submariner-release-plan-admission-prod-$NEW.yaml" || { echo "❌ Product version not set to \"$NEW_ACM\""; exit 1; }

PATCH_MATCHES=$(grep -E "v${NEW//-/.}\.[0-9]+-" "submariner-release-plan-admission-"*"-$NEW.yaml" 2>/dev/null)
if [ -n "$PATCH_MATCHES" ]; then
  echo "❌ Found patch version in RPA tags (should use minor version only)"
  echo "$PATCH_MATCHES" | head -3
  exit 1
fi

echo "   ✓ All verifications passed"

# Commit
cd "$(git rev-parse --show-toplevel)"
git add "config/kflux-prd-rh02.0fk9.p1/product/ReleasePlanAdmission/submariner/submariner-release-plan-admission-"*"-$NEW.yaml"
git commit -s -m "Add Submariner v${NEW//-/.} stage/prod RPAs"

echo "✅ Commit 3: Added stage/prod RPAs (2 files)"
echo "   - Copied RPA files (stage, prod)"
echo "   - Updated version strings and ACM version"
echo "   - Verified: intentions, component count (9), product version, tag format"
echo "   - Committed: Add Submariner v${NEW//-/.} stage/prod RPAs"
echo ""

# ━━━ SUMMARY ━━━

echo "━━━ SUMMARY ━━━"
echo ""
echo "✅ All 3 commits completed successfully"
echo "   - 26 overlay files created"
echo "   - 22 auto-generated manifests built"
echo "   - 2 RPA files configured"
echo "   - Total: 49 files added"
echo ""
echo "📋 Review commits:"
echo "   git log --oneline -3"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the 3 commits above"
echo "   2. Push to remote: git push"
echo "   3. Wait for ArgoCD to deploy ReleasePlans to cluster (~5-10 min)"
echo "   4. Verify: oc get releaseplans -n submariner-tenant | grep -E \"stage-${NEW}|prod-${NEW}\""
```
