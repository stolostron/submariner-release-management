---
name: konflux-bundle-setup
description: Automate Konflux bundle setup on new release branches - configures Tekton pipelines for bundle builds including infrastructure, OLM annotations, hermetic builds, and multi-platform support
version: 1.0.0
argument-hint: "[version]"
user-invocable: true
allowed-tools: Bash
---

# Konflux Bundle Setup Workflow

Automate the setup of Konflux CI/CD bundle builds on new release branches for Submariner.

**What this skill does:**

1. Validates prerequisites (tools, repository state)
2. Detects version and checks out appropriate branch (bot PR or release)
3. Copies bundle infrastructure from previous release
4. Verifies infrastructure was copied correctly
5. Adds OLM annotations (7 feature annotations + subscription annotation)
6. Configures Tekton build parameters (hermetic, multi-platform, SBOM)
7. Updates file change filters (CEL expressions)
8. Updates task references to latest versions (affects all .tekton files)
9. Creates 6-9 commits with clear messages

**Usage:**

From submariner-operator repository:

```bash
/konflux-bundle-setup        # Auto-detect version from current branch
/konflux-bundle-setup 0.23   # Specify version explicitly
```

**Requirements:**

- `~/go/src/submariner-io/submariner-operator` repository must exist (auto-navigates if needed)
- `/configure-downstream` must be complete (bot PR branch created)
- Previous release branch must exist for reference (e.g., `release-0.20`)

**Note:** Bundle image SHAs are copied from previous release. Update them with bundle-sha-update workflow after component builds complete.

**ACM Version Mapping:** Submariner 0.X → ACM 2.(X-7)

- Example: 0.22 → 2.15, 0.23 → 2.16

---

## Step 0: Prerequisites Check

Validate tools and repository state. If this step fails, do not proceed to subsequent steps.

```bash
#!/bin/bash
MISSING_TOOLS=()

command -v git &>/dev/null || MISSING_TOOLS+=("git")
command -v sed &>/dev/null || MISSING_TOOLS+=("sed")
command -v awk &>/dev/null || MISSING_TOOLS+=("awk")
command -v curl &>/dev/null || MISSING_TOOLS+=("curl")
command -v jq &>/dev/null || MISSING_TOOLS+=("jq")
command -v sha256sum &>/dev/null || command -v shasum &>/dev/null || MISSING_TOOLS+=("sha256sum")

if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
  echo "❌ ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
  echo ""
  echo "Installation instructions:"
  for tool in "${MISSING_TOOLS[@]}"; do
    case "$tool" in
      git) echo "  git: https://git-scm.com/downloads" ;;
      sed|awk) echo "  $tool: included in most systems" ;;
      curl) echo "  curl: included in most systems" ;;
      jq) echo "  jq: https://jqlang.github.io/jq/download/" ;;
      sha256sum) echo "  sha256sum (Linux) or shasum -a 256 (macOS): included in most systems" ;;
    esac
  done
  exit 1
fi

# Check if we're in the correct repository, change to it if not
REPO_NAME=$(basename "$(pwd)" 2>/dev/null)
if [ "$REPO_NAME" != "submariner-operator" ]; then
  echo "ℹ️  Not in submariner-operator, changing directory..."
  OPERATOR_REPO="$HOME/go/src/submariner-io/submariner-operator"

  if [ ! -d "$OPERATOR_REPO" ]; then
    echo "❌ ERROR: Repository not found at $OPERATOR_REPO"
    echo "   Clone it first: git clone https://github.com/submariner-io/submariner-operator"
    exit 1
  fi

  cd "$OPERATOR_REPO" || {
    echo "❌ ERROR: Failed to change directory to $OPERATOR_REPO"
    exit 1
  }
  echo "✓ Changed to $(pwd)"
fi

# Validate it's a git repo
git rev-parse --git-dir &>/dev/null || {
  echo "❌ ERROR: Not a git repository: $(pwd)"
  exit 1
}

echo ""
echo "✓ Prerequisites verified: git, sed, awk, curl, jq, sha256sum/shasum"
echo "✓ Repository: submariner-operator at $(pwd)"
```

---

## Step 1: Parse Arguments and Detect Version

Extract version from branch name or use provided version. Set up state variables for subsequent steps.

```bash
#!/bin/bash
set -euo pipefail

# Parse optional version argument
read -r VERSION_ARG REST <<<"$ARGUMENTS"

if [ -n "$REST" ]; then
  echo "❌ ERROR: Too many arguments."
  echo "Usage: /konflux-bundle-setup [version]"
  echo "Example: /konflux-bundle-setup 0.23"
  exit 1
fi

# If version provided, validate format
if [ -n "$VERSION_ARG" ]; then
  # Validate format: 0.Y or 0.Y.Z
  if ! echo "$VERSION_ARG" | grep -qE '^0\.[0-9]+(\.[0-9]+)?$'; then
    echo "❌ ERROR: Invalid version format: $VERSION_ARG"
    echo "Expected: 0.Y or 0.Y.Z (e.g., 0.23 or 0.23.0)"
    exit 1
  fi

  # Extract major.minor (0.23.0 → 0.23)
  VERSION=$(echo "$VERSION_ARG" | grep -oE '^[0-9]+\.[0-9]+')
  echo "ℹ️  Using provided version: $VERSION"
else
  # Auto-detect from current branch
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "❌ ERROR: Not on a branch (detached HEAD)"
    echo "Provide version argument: /konflux-bundle-setup <version>"
    exit 1
  fi

  # Extract version from branch name
  case "$CURRENT_BRANCH" in
    konflux-submariner-bundle-*)
      # Bot branch format: konflux-submariner-bundle-0-23
      TEMP="${CURRENT_BRANCH#konflux-submariner-bundle-}"  # "0-23"
      VERSION_MINOR="${TEMP##*-}"                           # "23"
      VERSION_MAJOR="${TEMP%-*}"                            # "0"

      # Validate extraction worked
      case "$VERSION_MAJOR" in
        ''|*[!0-9]*)
          echo "❌ ERROR: Bot branch does not match expected pattern: $CURRENT_BRANCH"
          echo "Expected: konflux-submariner-bundle-{major}-{minor}"
          exit 1
          ;;
      esac
      case "$VERSION_MINOR" in
        ''|*[!0-9]*)
          echo "❌ ERROR: Bot branch does not match expected pattern: $CURRENT_BRANCH"
          echo "Expected: konflux-submariner-bundle-{major}-{minor}"
          exit 1
          ;;
      esac

      VERSION="${VERSION_MAJOR}.${VERSION_MINOR}"
      echo "ℹ️  Auto-detected version from bot branch: $VERSION"
      ;;
    release-*)
      # Release branch format: release-0.23
      VERSION="${CURRENT_BRANCH#release-}"
      if ! echo "$VERSION" | grep -qE '^0\.[0-9]+$'; then
        echo "❌ ERROR: Release branch does not match expected pattern: $CURRENT_BRANCH"
        echo "Expected: release-{major}.{minor}"
        exit 1
      fi
      echo "ℹ️  Auto-detected version from release branch: $VERSION"
      ;;
    *)
      echo "❌ ERROR: Cannot auto-detect version from branch: $CURRENT_BRANCH"
      echo "Expected branch format:"
      echo "  - konflux-submariner-bundle-{major}-{minor} (bot PR branch)"
      echo "  - release-{major}.{minor} (release branch)"
      echo ""
      echo "Provide version argument: /konflux-bundle-setup <version>"
      exit 1
      ;;
  esac
fi

# Parse version into components
VERSION_MAJOR="${VERSION%%.*}"
VERSION_MINOR="${VERSION##*.}"
VERSION_DASH="${VERSION//./-}"

# Calculate ACM version: Submariner 0.X → ACM 2.(X-7)
ACM_VERSION="2.$((VERSION_MINOR - 7))"

# Validate ACM version is positive
if [ "$((VERSION_MINOR - 7))" -lt 0 ]; then
  echo "❌ ERROR: ACM version would be negative: $ACM_VERSION"
  echo "   Minimum supported Submariner version is 0.7 (ACM 2.0)"
  exit 1
fi

# Calculate previous version for copying bundle infrastructure
PREV_VERSION_MINOR=$((VERSION_MINOR - 1))
PREV_VERSION="0.${PREV_VERSION_MINOR}"
PREV_VERSION_DASH="0-${PREV_VERSION_MINOR}"
PREV_RELEASE_BRANCH="release-${PREV_VERSION}"

# Construct branch names
RELEASE_BRANCH="release-${VERSION}"
BOT_BRANCH="konflux-submariner-bundle-${VERSION_DASH}"

# Save state to /tmp/ file for subsequent steps
STATE_FILE="/tmp/konflux-bundle-setup-${VERSION_DASH}.txt"
cat > "$STATE_FILE" <<EOF
VERSION="${VERSION}"
VERSION_DASH="${VERSION_DASH}"
VERSION_MAJOR="${VERSION_MAJOR}"
VERSION_MINOR="${VERSION_MINOR}"
ACM_VERSION="${ACM_VERSION}"
PREV_VERSION="${PREV_VERSION}"
PREV_VERSION_MINOR="${PREV_VERSION_MINOR}"
PREV_VERSION_DASH="${PREV_VERSION_DASH}"
PREV_RELEASE_BRANCH="${PREV_RELEASE_BRANCH}"
RELEASE_BRANCH="${RELEASE_BRANCH}"
BOT_BRANCH="${BOT_BRANCH}"
STATE_FILE="${STATE_FILE}"
EOF

echo ""
echo "✓ Version configuration:"
echo "  Submariner version: $VERSION"
echo "  ACM version: $ACM_VERSION"
echo "  Release branch: $RELEASE_BRANCH"
echo "  Bot branch: $BOT_BRANCH"
echo ""
echo "  State saved to: $STATE_FILE"
```

---

## Step 2: Checkout Branch

Try release branch first (if has .tekton/), then bot branch (local or remote).

```bash
#!/bin/bash
set -euo pipefail

# Load state from Step 1
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  echo "❌ ERROR: State file not found. Did Step 1 complete successfully?"
  exit 1
fi
source "$STATE_FILE"

echo "Checking for branches..."

# Try release branch first if it has .tekton/ (bot PR already merged)
if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH" && \
   git ls-tree -r "$RELEASE_BRANCH" -- .tekton/ 2>/dev/null | grep -q .; then
  # Release exists with .tekton
  git checkout "$RELEASE_BRANCH" || {
    echo "❌ ERROR: Failed to checkout branch: $RELEASE_BRANCH"
    exit 1
  }
  echo "✅ Checked out: $RELEASE_BRANCH (bot PR already merged)"

elif git show-ref --verify --quiet "refs/heads/$BOT_BRANCH"; then
  # Bot branch exists locally
  git checkout "$BOT_BRANCH" || {
    echo "❌ ERROR: Failed to checkout branch: $BOT_BRANCH"
    exit 1
  }
  echo "✅ Checked out: $BOT_BRANCH (bot PR pending)"

else
  # Try fetching bot branch from origin
  echo "ℹ️  Neither branch found locally, trying origin..."

  if git fetch origin "$BOT_BRANCH:$BOT_BRANCH" 2>/dev/null; then
    git checkout "$BOT_BRANCH" || {
      echo "❌ ERROR: Failed to checkout branch: $BOT_BRANCH"
      exit 1
    }
    echo "✅ Checked out: $BOT_BRANCH (fetched from origin)"
  else
    # Neither branch found
    echo "❌ ERROR: Neither release nor bot branch found"
    echo ""
    echo "Expected one of:"
    echo "  - Release branch: $RELEASE_BRANCH (with .tekton/ directory)"
    echo "  - Bot branch: $BOT_BRANCH"
    echo ""
    echo "Ensure Step 2 (configure-downstream) is complete."
    echo "The bot creates a PR adding .tekton/ config to the release branch."
    echo ""
    echo "To proceed, manually checkout one of these branches:"
    echo "  git fetch origin && git checkout $BOT_BRANCH"
    echo "  git fetch origin && git checkout $RELEASE_BRANCH"
    exit 1
  fi
fi

# Verify .tekton/ directory exists
if [ ! -d ".tekton" ]; then
  echo "❌ ERROR: .tekton/ directory not found on current branch"
  echo "   Branch: $(git rev-parse --abbrev-ref HEAD)"
  echo ""
  echo "The bot should have created .tekton/ files."
  echo "Ensure Step 2 (configure-downstream) is complete."
  exit 1
fi

echo "✓ Branch verified with .tekton/ directory"
```

---

## Step 3: Add YAMLlint Ignore

Verify .tekton is in .yamllint.yml ignore list (usually already present from bot).

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

# Check if .tekton already in .yamllint.yml ignore list
if grep -q "\.tekton" .yamllint.yml 2>/dev/null; then
  echo "ℹ️  YAMLlint ignore already present (.tekton in .yamllint.yml)"
else
  echo "Adding .tekton to YAMLlint ignore..."

  # Copy .yamllint.yml from previous release
  git checkout "${PREV_RELEASE_BRANCH}" -- .yamllint.yml || {
    echo "❌ ERROR: Failed to copy .yamllint.yml from ${PREV_RELEASE_BRANCH}"
    exit 1
  }

  git add .yamllint.yml
  git commit -s -m "Ignore .tekton in YAMLlint"

  echo "✓ YAMLlint ignore added"
fi
```

---

## Step 4: Add Konflux Bundle Infrastructure

Copy bundle infrastructure from previous release and update version references.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Copying bundle infrastructure from ${PREV_RELEASE_BRANCH}..."

# Copy bundle files from existing branch
git checkout "${PREV_RELEASE_BRANCH}" -- bundle.Dockerfile.konflux config/bundle/ config/manager/patches/ || {
  echo "❌ ERROR: Failed to copy bundle files from ${PREV_RELEASE_BRANCH}"
  echo "   Ensure ${PREV_RELEASE_BRANCH} branch exists with bundle infrastructure"
  exit 1
}

echo "✓ Copied bundle.Dockerfile.konflux, config/bundle/, and config/manager/patches/"

# Update version references in bundle files
echo "Updating version strings..."

# Calculate previous ACM version for replacement
PREV_ACM_VERSION="2.$((PREV_VERSION_MINOR - 7))"

# Escape dots for sed patterns (0.22 → 0\.22)
PREV_VERSION_ESCAPED="${PREV_VERSION/./\\.}"
PREV_ACM_ESCAPED="${PREV_ACM_VERSION/./\\.}"

# Replace version strings in bundle files
sed -i \
  -e "s/${PREV_VERSION_ESCAPED}/${VERSION}/g" \
  -e "s/${PREV_VERSION_DASH}/${VERSION_DASH}/g" \
  -e "s/${PREV_ACM_ESCAPED}/${ACM_VERSION}/g" \
  bundle.Dockerfile.konflux config/bundle/kustomization.yaml config/bundle/patches/submariner.csv.config.yaml

# Update tekton to use Konflux bundle Dockerfile
sed -i 's|value: bundle.Dockerfile$|value: bundle.Dockerfile.konflux|' \
  .tekton/submariner-bundle-*.yaml

# Update BASE_BRANCH in konflux.args
sed -i "s/BASE_BRANCH=.*/BASE_BRANCH=${RELEASE_BRANCH}/" .tekton/konflux.args

# Verify critical files were created/modified
[ -f bundle.Dockerfile.konflux ] || { echo "❌ ERROR: bundle.Dockerfile.konflux not found"; exit 1; }
[ -d config/bundle ] || { echo "❌ ERROR: config/bundle/ directory not found"; exit 1; }
[ -f config/manager/patches/related-images.deployment.config.yaml ] || {
  echo "❌ ERROR: config/manager/patches/related-images.deployment.config.yaml not found"
  exit 1
}
grep -q "BASE_BRANCH=${RELEASE_BRANCH}" .tekton/konflux.args || {
  echo "❌ ERROR: BASE_BRANCH not updated in konflux.args"
  exit 1
}

echo "✓ Version strings updated (${VERSION}, ${VERSION_DASH}, ${ACM_VERSION})"

# Commit changes
git add -f bundle.Dockerfile.konflux config/bundle/ config/manager/patches/ .tekton/
git commit -s -m "Add Konflux bundle infrastructure for ${RELEASE_BRANCH}"

echo "✅ Bundle infrastructure configured"
```

---

## Step 5: Verify Bundle Images Configuration

Check that bundle images file was copied from previous release. Images will be updated later with bundle-sha-update workflow.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

IMAGE_FILE="config/manager/patches/related-images.deployment.config.yaml"

echo "Verifying bundle images configuration..."

if [ ! -f "$IMAGE_FILE" ]; then
  echo "❌ ERROR: Image file not found: $IMAGE_FILE"
  echo ""
  echo "This file should have been copied from ${PREV_RELEASE_BRANCH} in Step 4."
  echo "Check that Step 4 completed successfully."
  exit 1
fi

# Check for registry.redhat.io URLs with SHA256 digests
if ! grep -q "registry.redhat.io.*@sha256:" "$IMAGE_FILE"; then
  echo "❌ ERROR: Image file has unexpected format"
  echo ""
  echo "Expected registry.redhat.io URLs with SHA256 digests."
  echo "File: $IMAGE_FILE"
  echo ""
  echo "This should have been copied from ${PREV_RELEASE_BRANCH} in Step 4."
  exit 1
fi

echo "✓ Bundle images inherited from ${PREV_RELEASE_BRANCH}"
echo "  (Images reference ${PREV_VERSION} component SHAs - this is expected)"
echo ""
echo "ℹ️  Update SHAs after ${VERSION} component builds complete:"
echo "  Workflow: ~/.agents/workflows/bundle-sha-update.md"
echo "  What it does: Updates image SHAs from Konflux snapshots (requires oc login)"
```

---

## Step 6: Add OLM Feature Annotations

Add required OLM feature annotations to the CSV base template (idempotent).

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

CSV_FILE="config/manifests/bases/submariner.clusterserviceversion.yaml"

echo "Checking OLM feature annotations..."

# Check if annotations already exist
if grep -q "features.operators.openshift.io/disconnected" "$CSV_FILE"; then
  echo "ℹ️  OLM feature annotations already present"
else
  echo "Adding OLM feature annotations..."

  # Add feature annotations after description line
  sed -i '/description: Creates and manages Submariner deployments./a\
    features.operators.openshift.io/disconnected: "true"\
    features.operators.openshift.io/fips-compliant: "true"\
    features.operators.openshift.io/proxy-aware: "false"\
    features.operators.openshift.io/tls-profiles: "false"\
    features.operators.openshift.io/token-auth-aws: "false"\
    features.operators.openshift.io/token-auth-azure: "false"\
    features.operators.openshift.io/token-auth-gcp: "false"' "$CSV_FILE"

  git add "$CSV_FILE"
  git commit -s -m "Add required OLM feature annotations to CSV base"

  echo "✓ OLM feature annotations added (7 annotations)"
fi
```

---

## Step 7: Add Subscription Annotation

Add required subscription annotation to the CSV base template (idempotent, separate commit).

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

CSV_FILE="config/manifests/bases/submariner.clusterserviceversion.yaml"

echo "Checking subscription annotation..."

# Check if annotation already exists
if grep -q "valid-subscription" "$CSV_FILE"; then
  echo "ℹ️  Subscription annotation already present"
else
  echo "Adding subscription annotation..."

  # Add subscription annotation after suggested-namespace line
  sed -i '/operatorframework.io\/suggested-namespace: submariner-operator/a\
    operators.openshift.io/valid-subscription: '\''["OpenShift Platform Plus", "Red Hat\
      Advanced Cluster Management for Kubernetes"]'\''' "$CSV_FILE"

  git add "$CSV_FILE"
  git commit -s -m "Add required subscription annotation to CSV base"

  echo "✓ Subscription annotation added"
fi
```

---

## Step 8: Add Build Args File Parameter

Add build-args-file parameter to Tekton configs (idempotent).

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Checking build-args-file parameter..."

# Check if build-args-file parameter already exists in pull-request file
PULL_REQUEST_FILE=".tekton/submariner-bundle-${VERSION_DASH}-pull-request.yaml"

if awk '/^spec:/,/^  pipelineSpec:/' "$PULL_REQUEST_FILE" | grep -q "name: build-args-file"; then
  echo "ℹ️  Build args file parameter already present"
else
  echo "Adding build-args-file parameter..."

  # Add build-args-file parameter after dockerfile parameter
  sed -i '/value: bundle.Dockerfile.konflux$/a\  - name: build-args-file\n    value: .tekton/konflux.args' \
    .tekton/submariner-bundle-*.yaml

  git add .tekton/submariner-bundle-*.yaml
  git commit -s -m "Add build args file to bundle tekton config"

  echo "✓ Build args file parameter added"
fi
```

---

## Step 9: Enable Hermetic Builds and SBOM

Add hermetic and build-source-image parameters to Tekton configs.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Adding hermetic builds and SBOM parameters..."

# Add hermetic and build-source-image parameters after build-args-file
sed -i '/value: \.tekton\/konflux\.args$/a\  - name: hermetic\n    value: "true"\n  - name: build-source-image\n    value: "true"' \
  .tekton/submariner-bundle-*.yaml

git add .tekton/submariner-bundle-*.yaml
git commit -s -m "Enable hermetic builds and SBOM for bundle"

echo "✓ Hermetic builds enabled"
echo "✓ SBOM generation enabled"
```

---

## Step 10: Add Multi-Platform Support

Add build-platforms parameter with 4 architectures.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Adding multi-platform support..."

# Add build-platforms parameter after dockerfile parameter
sed -i '/value: bundle.Dockerfile.konflux$/a\  - name: build-platforms\n    value:\n    - linux/x86_64\n    - linux/ppc64le\n    - linux/s390x\n    - linux/arm64' \
  .tekton/submariner-bundle-*.yaml

git add .tekton/submariner-bundle-*.yaml
git commit -s -m "Add multi-platform build support to bundle"

echo "✓ Multi-platform support added (x86_64, ppc64le, s390x, arm64)"
```

---

## Step 11: Add File Change Filters

Copy complete Tekton files from previous release with file change filters, then update version references.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Adding file change filters to CEL expressions..."

# Process both pull-request and push files
for FILE_TYPE in pull-request push; do
  CURRENT_FILE=".tekton/submariner-bundle-${VERSION_DASH}-${FILE_TYPE}.yaml"
  PREV_FILE=".tekton/submariner-bundle-${PREV_VERSION_DASH}-${FILE_TYPE}.yaml"

  echo "Processing $CURRENT_FILE..."

  # Copy complete working file from previous release (try local first, then remote)
  if git show "${PREV_RELEASE_BRANCH}:${PREV_FILE}" > "${CURRENT_FILE}.new" 2>/dev/null; then
    echo "  Copied from local ${PREV_RELEASE_BRANCH}"
  elif git show "origin/${PREV_RELEASE_BRANCH}:${PREV_FILE}" > "${CURRENT_FILE}.new" 2>/dev/null; then
    echo "  Copied from origin/${PREV_RELEASE_BRANCH}"
  else
    echo "⚠️  Could not copy ${PREV_FILE} from ${PREV_RELEASE_BRANCH} (tried local and origin)"
    echo "   Skipping file change filters for $FILE_TYPE"
    continue
  fi

  # Verify file was copied successfully
  if [ ! -s "${CURRENT_FILE}.new" ]; then
    echo "❌ ERROR: Copied file is empty: ${CURRENT_FILE}.new"
    rm -f "${CURRENT_FILE}.new"
    exit 1
  fi

  # Update version references (escape dots for sed patterns)
  PREV_VERSION_ESCAPED="${PREV_VERSION/./\\.}"

  sed -i \
    -e "s/${PREV_VERSION_DASH}/${VERSION_DASH}/g" \
    -e "s/release-${PREV_VERSION_ESCAPED}/release-${VERSION}/g" \
    "${CURRENT_FILE}.new"

  # Validate YAML before replacing original
  if command -v yq &>/dev/null; then
    if ! yq eval '.' "${CURRENT_FILE}.new" > /dev/null 2>&1; then
      echo "❌ ERROR: YAML invalid after version update in ${CURRENT_FILE}.new"
      rm -f "${CURRENT_FILE}.new"
      exit 1
    fi
  fi

  # Verify final file is not empty before replacing
  if [ ! -s "${CURRENT_FILE}.new" ]; then
    echo "❌ ERROR: Processed file is empty: ${CURRENT_FILE}.new"
    rm -f "${CURRENT_FILE}.new"
    exit 1
  fi

  # Replace original with updated version
  mv "${CURRENT_FILE}.new" "$CURRENT_FILE"

  echo "✓ Updated $FILE_TYPE file"
done

git add .tekton/submariner-bundle-*.yaml
git commit -s -m "Avoid building bundle when updating operator

Add file change filters to CEL expressions to prevent
unnecessary bundle builds when only operator files change."

echo "✅ File change filters added"
```

---

## Step 12: Update Task References

Download pipeline-patcher script and update Tekton task references to latest versions.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo "Updating Tekton task references..."

PATCHER_SHA="b001763bb1cd0286a894cfb570fe12dd7f4504bd"
EXPECTED_SHA256="080ad5d7cf7d0cee732a774b7e4dda0e2ccf26b58e08a8516a3b812bc73beb53"

# Download script
SCRIPT=$(curl -sL "https://raw.githubusercontent.com/simonbaird/konflux-pipeline-patcher/${PATCHER_SHA}/pipeline-patcher")

# Verify SHA256 checksum
if command -v sha256sum &>/dev/null; then
  ACTUAL_SHA256=$(echo "$SCRIPT" | sha256sum | cut -d' ' -f1)
else
  ACTUAL_SHA256=$(echo "$SCRIPT" | shasum -a 256 | cut -d' ' -f1)
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "❌ ERROR: Script checksum mismatch!"
  echo "   Expected: $EXPECTED_SHA256"
  echo "   Actual:   $ACTUAL_SHA256"
  echo ""
  echo "Security verification failed. Not executing downloaded script."
  exit 1
fi

echo "✓ Script checksum verified"

# Run bump-task-refs (updates all .tekton files, including operator)
echo "$SCRIPT" | bash -s bump-task-refs

# Stage all .tekton changes (bundle + operator files)
git add .tekton/
git commit -s -m "Update Tekton task references to latest versions"

echo "✅ Task references updated"
```

---

## Step 13: Final Verification and Summary

Verify all changes, count commits, and display summary with next steps.

```bash
#!/bin/bash
set -euo pipefail

# Load state
STATE_FILE=$(ls -t /tmp/konflux-bundle-setup-*.txt 2>/dev/null | head -1)
source "$STATE_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Final Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Count commits
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_COUNT=$(git log "origin/${CURRENT_BRANCH}..HEAD" --oneline 2>/dev/null | wc -l || echo "0")
echo "✓ Commits created: $COMMIT_COUNT"

if [ "$COMMIT_COUNT" -lt 6 ] || [ "$COMMIT_COUNT" -gt 9 ]; then
  echo "⚠️  Warning: Expected 6-9 commits, found $COMMIT_COUNT"
fi

# 2. Verify clean working tree
if [ -z "$(git status --porcelain)" ]; then
  echo "✓ Working tree clean"
else
  echo "⚠️  Warning: Working tree not clean"
  git status --short
fi

# 3. Verify all 5 required parameters in spec.params
echo ""
echo "Verifying required parameters..."

PULL_REQUEST_FILE=".tekton/submariner-bundle-${VERSION_DASH}-pull-request.yaml"

# Extract params section and check each parameter (name + value on separate lines)
PARAMS_SECTION=$(awk '/^spec:$/,/^  pipelineSpec:$/ {print}' "$PULL_REQUEST_FILE")

REQUIRED_PARAMS=(
  "dockerfile|bundle.Dockerfile.konflux"
  "build-args-file|.tekton/konflux.args"
  "hermetic|\"true\""
  "build-source-image|\"true\""
  "build-platforms|"
)

PARAMS_OK=true
for PARAM_PAIR in "${REQUIRED_PARAMS[@]}"; do
  NAME="${PARAM_PAIR%%|*}"
  VALUE="${PARAM_PAIR##*|}"

  if echo "$PARAMS_SECTION" | grep -q "name: $NAME" && \
     { [ -z "$VALUE" ] || echo "$PARAMS_SECTION" | grep -q "value: $VALUE"; }; then
    echo "  ✓ $NAME${VALUE:+: $VALUE}"
  else
    echo "  ❌ Missing: $NAME${VALUE:+: $VALUE}"
    PARAMS_OK=false
  fi
done

if [ "$PARAMS_OK" = false ]; then
  echo ""
  echo "❌ ERROR: Some required parameters are missing"
  exit 1
fi

# 4. Run make yamllint
echo ""
echo "Running YAML validation..."
if command -v make &>/dev/null && make yamllint &>/dev/null; then
  echo "✓ YAML validation passed"
else
  echo "⚠️  Warning: make yamllint failed or not available"
fi

# Display summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Bundle Setup Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Summary:"
echo "   Version: $VERSION"
echo "   Branch: $CURRENT_BRANCH"
echo "   Commits: $COMMIT_COUNT"
echo ""
echo "📋 Recent commits:"
git log "origin/${CURRENT_BRANCH}..HEAD" --oneline 2>/dev/null || git log --oneline -"$COMMIT_COUNT"
echo ""
echo "📊 Files modified:"
git diff --stat "origin/${CURRENT_BRANCH}..HEAD" 2>/dev/null || echo "  (cannot compute diff - no tracking branch)"
echo ""
echo "🚀 Next steps:"
echo "   1. Review commits: git log -p origin/${CURRENT_BRANCH}..HEAD"
echo "   2. Verify changes: git diff origin/${CURRENT_BRANCH}..HEAD"
echo "   3. Push to update bot PR: git push origin $CURRENT_BRANCH"
echo "   4. Wait for Konflux build (~15-30 min)"
echo "   5. Verify bundle EC tests pass"
echo ""
echo "💡 Verification commands:"
echo "   oc get snapshots -n submariner-tenant | grep submariner-bundle-${VERSION_DASH}"
echo "   oc get snapshot <name> -n submariner-tenant -o yaml | grep -A5 test.appstudio"
echo ""

# Cleanup state file
rm -f "$STATE_FILE"
echo "✓ State file cleaned up: $STATE_FILE"
```
