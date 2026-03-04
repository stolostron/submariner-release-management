---
name: konflux-component-setup
description: Automate Konflux component setup on new release branches - configures Tekton pipelines, Dockerfiles, RPM lockfiles, and hermetic builds for Submariner components. Supports 8 component types. Arguments are optional and order-independent.
version: 1.0.0
argument-hint: "[repo-shortcut] [component-name] [version]"
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
context: fork
---

# Konflux Component Setup Workflow

Automate the setup of Konflux CI/CD builds on new release branches for Submariner components.

**Handles 8 components** across 5 repositories:

| Repository          | Component(s)                                                              |
|---------------------|---------------------------------------------------------------------------|
| submariner-operator | submariner-operator                                                       |
| submariner          | submariner-gateway, submariner-globalnet, submariner-route-agent          |
| lighthouse          | lighthouse-agent, lighthouse-coredns                                      |
| shipyard            | nettest                                                                   |
| subctl              | subctl                                                                    |

**Does NOT handle bundle** (different workflow - use separate skill if needed).

**Usage examples:**

From release-management repo:

- `/konflux-component-setup operator 0.23` - setup operator for v0.23 (component auto-detected)
- `/konflux-component-setup submariner submariner-gateway 0.23` - setup gateway (full component name required)
- `/konflux-component-setup lighthouse lighthouse-agent 0.23` - setup lighthouse agent

From component repo:

- `/konflux-component-setup` - auto-detect from current branch (bot or release branch)

From anywhere:

- `/konflux-component-setup ~/path/to/subctl subctl 0.23` - use full path

**Repository shortcuts:**

- `operator` → `~/go/src/submariner-io/submariner-operator`
- `submariner` → `~/go/src/submariner-io/submariner`
- `lighthouse` → `~/go/src/submariner-io/lighthouse`
- `shipyard` → `~/go/src/submariner-io/shipyard`
- `subctl` → `~/go/src/submariner-io/subctl`

**Arguments** (all optional, order-independent):

- `repo-shortcut`: Repository shortcut, full path, or relative path
- `component-name`: Component name (auto-detected from branch, or for single-component repos when version provided)
- `version`: Release version like `0.23` (auto-detected from current branch if not provided)

**Note:** For single-component repos (operator, shipyard, subctl), component name is auto-detected when version is provided.

**What the skill does:**

1. Detects which branch to use:
   - If bot PR merged: uses release branch (e.g., `release-0.23`)
   - If bot PR pending: uses bot branch (e.g., `konflux-submariner-operator-0-23`)
2. Validates initial `.tekton/` files exist
3. Runs 12 setup steps (0-11) to configure hermetic builds, multi-platform, SBOM, etc.
4. Commits each configuration change separately for easy review

**Requirements:**

- Step 2 (configure-downstream) must be complete - bot must have created PR (merged or pending)
- Previous release branch must exist for reference (e.g., `release-0.21` when setting up 0.22)

---

## Step 0: Prerequisites Check

**REQUIRED**: Verify tools and repository state. If this step fails, do not proceed to subsequent steps.

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

# Check bash version (works in both interactive and non-interactive shells)
BASH_MAJOR=$(bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)
if [ -z "$BASH_MAJOR" ]; then
  # Fallback: parse from bash --version
  BASH_MAJOR=$(bash --version 2>/dev/null | head -1 | sed -nE 's/.*version ([0-9]+).*/\1/p')
fi

if [ -z "$BASH_MAJOR" ] || [ "$BASH_MAJOR" -lt 4 ]; then
  BASH_VER=$(bash --version 2>/dev/null | head -1 || echo "unknown")
  echo "❌ ERROR: bash 4.0+ required (current: $BASH_VER)"
  echo "This script uses associative arrays (declare -A) which require bash 4.0+."
  echo ""
  echo "macOS users: brew install bash"
  echo "Then ensure the new bash is in your PATH before /bin/bash"
  exit 1
fi

echo ""
echo "✓ Prerequisites verified: bash 4.0+, git, sed, awk, curl, jq, sha256sum/shasum"
```

---

## Step 1: Detect Repository and Component

Parse arguments to determine repository path, component name, and version information.

```bash
#!/bin/bash
# Component metadata: component:prefetch_type:has_cpe:special_files
# prefetch_type: gomod, gomod+rpm, rpm
# has_cpe: yes/no (whether component needs CPE label update)
# special_files: comma-separated list of special files to copy (e.g., metricsproxy)
declare -A COMPONENT_META=(
    ["submariner-operator"]="gomod:yes:"
    ["submariner-gateway"]="gomod+rpm:yes:"
    ["submariner-globalnet"]="gomod+rpm:yes:"
    ["submariner-route-agent"]="gomod+rpm:yes:"
    ["lighthouse-agent"]="gomod:yes:"
    ["lighthouse-coredns"]="gomod:yes:"
    ["nettest"]="rpm:yes:metricsproxy"
    ["subctl"]="gomod:no:"
)

# Repository shortcuts
declare -A REPO_SHORTCUTS=(
    ["operator"]="$HOME/go/src/submariner-io/submariner-operator"
    ["submariner-operator"]="$HOME/go/src/submariner-io/submariner-operator"
    ["submariner"]="$HOME/go/src/submariner-io/submariner"
    ["lighthouse"]="$HOME/go/src/submariner-io/lighthouse"
    ["shipyard"]="$HOME/go/src/submariner-io/shipyard"
    ["subctl"]="$HOME/go/src/submariner-io/subctl"
)

# Parse arguments (repo, component, version - all optional, order-independent)
read -r ARG1 ARG2 ARG3 REST <<<"$ARGUMENTS"

if [ -n "$REST" ]; then
  echo "❌ ERROR: Too many arguments."
  echo "Usage: /konflux-component-setup [repo] [component] [version]"
  exit 1
fi

REPO=""
COMPONENT=""
VERSION=""

# Argument parsing logic (detect type by pattern, using case like konflux-ci-fix)
for arg in "$ARG1" "$ARG2" "$ARG3"; do
  [ -z "$arg" ] && continue

  # Expand tilde
  arg="${arg/#\~/$HOME}"

  case "$arg" in
    # Version format: 0.23 (dot only, like konflux-ci-fix branch format)
    [0-9].[0-9]|[0-9].[0-9][0-9]|[0-9][0-9].[0-9]|[0-9][0-9].[0-9][0-9])
      if [ -n "$VERSION" ]; then
        echo "❌ ERROR: Multiple versions specified"
        exit 1
      fi
      VERSION="$arg"
      ;;
    # Path patterns
    /*|./*|../*)
      if [ -n "$REPO" ]; then
        echo "❌ ERROR: Multiple repositories specified"
        exit 1
      fi
      REPO="$arg"
      ;;
    # Repository shortcuts or component names
    *)
      # Check if it's a known shortcut
      if [ -n "${REPO_SHORTCUTS[$arg]:-}" ]; then
        if [ -n "$REPO" ]; then
          echo "❌ ERROR: Multiple repositories specified"
          exit 1
        fi
        REPO="${REPO_SHORTCUTS[$arg]}"
      # Check if it's a known component
      elif [ -n "${COMPONENT_META[$arg]:-}" ]; then
        if [ -n "$COMPONENT" ]; then
          echo "❌ ERROR: Multiple components specified"
          exit 1
        fi
        COMPONENT="$arg"
      # Try as directory path
      elif [ -d "$arg" ]; then
        if [ -n "$REPO" ]; then
          echo "❌ ERROR: Multiple repositories specified"
          exit 1
        fi
        REPO="$arg"
      else
        echo "❌ ERROR: Unknown argument: $arg"
        echo "Expected: repo shortcut, component name, or version (e.g., 0.23)"
        exit 1
      fi
      ;;
  esac
done

# Default repo to current directory
REPO="${REPO:-.}"

# Validate repo exists
if [ ! -d "$REPO" ]; then
  echo "❌ ERROR: Repository not found: $REPO"
  echo ""
  # Check if it looks like a shortcut was used
  case "$REPO" in
    */go/src/submariner-io/*)
      SHORTCUT=$(basename "$REPO")
      echo "The '$SHORTCUT' shortcut expects repos at: ~/go/src/submariner-io/"
      echo "Your repos may be in a different location."
      echo ""
      echo "Solutions:"
      echo "  1. Use full path: /konflux-component-setup /path/to/your/$SHORTCUT"
      echo "  2. Clone repos to: ~/go/src/submariner-io/"
      ;;
  esac
  exit 1
fi

# Validate it's a git repo
git -C "$REPO" rev-parse --git-dir &>/dev/null || {
  echo "❌ ERROR: Not a git repository: $REPO"
  exit 1
}

# Change to repository directory
if [ ! "$REPO" = "." ]; then
  cd "$REPO" || {
    echo "❌ ERROR: Cannot change to directory: $REPO"
    exit 1
  }
  echo "ℹ️  Working in repository: $REPO"
fi

# Auto-detect component from repository name (for single-component repos)
# Usage: auto_detect_component [version]
#   version: Optional, used for error messages in VERSION path
auto_detect_component() {
  local VERSION_ARG="$1"

  REPO_NAME=$(basename "$(pwd)")
  case "$REPO_NAME" in
    submariner-operator)
      COMPONENT="submariner-operator"
      echo "ℹ️  Auto-detected component: $COMPONENT"
      ;;
    shipyard)
      COMPONENT="nettest"
      echo "ℹ️  Auto-detected component: $COMPONENT"
      ;;
    subctl)
      COMPONENT="subctl"
      echo "ℹ️  Auto-detected component: $COMPONENT"
      ;;
    submariner)
      if [ -n "$VERSION_ARG" ]; then
        echo "❌ ERROR: submariner repo has 3 components:"
        echo "  submariner-gateway, submariner-globalnet, submariner-route-agent"
        echo "Please specify: /konflux-component-setup submariner <component> $VERSION_ARG"
        echo "Example: /konflux-component-setup submariner submariner-gateway $VERSION_ARG"
      else
        echo "❌ ERROR: submariner repo has 3 components"
        echo "Please specify: /konflux-component-setup submariner <component>"
        echo "Example: /konflux-component-setup submariner submariner-gateway"
      fi
      exit 1
      ;;
    lighthouse)
      if [ -n "$VERSION_ARG" ]; then
        echo "❌ ERROR: lighthouse repo has 2 components:"
        echo "  lighthouse-agent, lighthouse-coredns"
        echo "Please specify: /konflux-component-setup lighthouse <component> $VERSION_ARG"
        echo "Example: /konflux-component-setup lighthouse lighthouse-agent $VERSION_ARG"
      else
        echo "❌ ERROR: lighthouse repo has 2 components"
        echo "Please specify: /konflux-component-setup lighthouse <component>"
        echo "Example: /konflux-component-setup lighthouse lighthouse-agent"
      fi
      exit 1
      ;;
    *)
      if [ -n "$VERSION_ARG" ]; then
        echo "❌ ERROR: Cannot auto-detect component from repo: $REPO_NAME"
        echo "Usage: /konflux-component-setup <repo> <component> <version>"
      else
        echo "❌ ERROR: Cannot auto-detect component from repo: $REPO_NAME"
        echo "Please specify: /konflux-component-setup <repo> <component>"
      fi
      exit 1
      ;;
  esac
}

# If version provided, checkout the branch and set version variables
if [ -n "$VERSION" ]; then
  # Auto-detect component from repo if not specified (only for single-component repos)
  if [ -z "$COMPONENT" ]; then
    auto_detect_component "$VERSION"
  fi

  # Parse version into major/minor
  VERSION_MAJOR="${VERSION%%.*}"
  VERSION_MINOR="${VERSION##*.}"

  # Construct branch names
  VERSION_DASH="${VERSION//./-}"
  RELEASE_BRANCH="release-${VERSION}"
  BOT_BRANCH="konflux-${COMPONENT}-${VERSION_DASH}"

  # Try release branch first if it has .tekton (bot PR already merged)
  # Note: Only check local branches - user may have SSH key on external device
  if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH" && \
     git ls-tree -r "$RELEASE_BRANCH" -- .tekton/ 2>/dev/null | grep -q .; then
    # Release exists with .tekton
    git checkout "$RELEASE_BRANCH" || {
      echo "❌ ERROR: Failed to checkout branch: $RELEASE_BRANCH"
      exit 1
    }
    echo "✅ Checked out: $RELEASE_BRANCH (bot PR already merged)"

  elif git show-ref --verify --quiet "refs/heads/$BOT_BRANCH"; then
    # Bot branch exists
    git checkout "$BOT_BRANCH" || {
      echo "❌ ERROR: Failed to checkout branch: $BOT_BRANCH"
      exit 1
    }
    echo "✅ Checked out: $BOT_BRANCH (bot PR pending)"

  else
    # Neither branch found
    echo "❌ ERROR: Neither release nor bot branch found locally"
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
else
  # No version provided - extract from current branch
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "❌ ERROR: Not on a branch (detached HEAD)"
    echo "Provide version argument: /konflux-component-setup <repo> <component> <version>"
    exit 1
  fi

  # Validate branch is a bot or release branch
  case "$CURRENT_BRANCH" in
    konflux-*)
      # Bot branch format: konflux-{component}-{major}-{minor}
      # Validate format by trying extraction - if it fails, format is wrong
      TEMP="${CURRENT_BRANCH#konflux-}"  # "submariner-operator-0-23"
      VERSION_MINOR="${TEMP##*-}"         # "23"
      TEMP="${TEMP%-*}"                   # "submariner-operator-0"
      VERSION_MAJOR="${TEMP##*-}"         # "0"
      TEMP="${TEMP%-*}"                   # "submariner-operator"

      # Validate extraction worked (VERSION_MAJOR and VERSION_MINOR should be numbers)
      case "$VERSION_MAJOR" in
        ''|*[!0-9]*)
          echo "❌ ERROR: Bot branch does not match expected pattern: $CURRENT_BRANCH"
          echo "Expected: konflux-{component}-{major}-{minor}"
          echo "Example: konflux-submariner-operator-0-23"
          exit 1
          ;;
      esac
      case "$VERSION_MINOR" in
        ''|*[!0-9]*)
          echo "❌ ERROR: Bot branch does not match expected pattern: $CURRENT_BRANCH"
          echo "Expected: konflux-{component}-{major}-{minor}"
          echo "Example: konflux-submariner-operator-0-23"
          exit 1
          ;;
      esac

      if [ -z "$COMPONENT" ]; then
        COMPONENT="$TEMP"
        echo "ℹ️  Detected component from branch: $COMPONENT"
      fi
      ;;

    release-*)
      # Release branch format: release-{major}.{minor}

      # Extract component from repo if not provided
      if [ -z "$COMPONENT" ]; then
        auto_detect_component
      fi

      # Extract version from branch
      VERSION_STR="${CURRENT_BRANCH#release-}"
      VERSION_MAJOR="${VERSION_STR%%.*}"
      VERSION_MINOR="${VERSION_STR##*.}"
      ;;

    *)
      echo "❌ ERROR: Not on a bot or release branch (current: $CURRENT_BRANCH)"
      echo "Expected patterns:"
      echo "  - Bot branch: konflux-{component}-{version} (e.g., konflux-submariner-operator-0-23)"
      echo "  - Release branch: release-{version} (e.g., release-0.23)"
      echo ""
      echo "Either checkout a branch manually or provide version argument:"
      echo "  /konflux-component-setup <repo> <component> <version>"
      exit 1
      ;;
  esac

  # Validate version numbers (empty or contains non-digits)
  case "$VERSION_MAJOR" in
    ''|*[!0-9]*)
      echo "❌ ERROR: Could not extract version from branch: $CURRENT_BRANCH"
      echo "Expected patterns:"
      echo "  - Bot: konflux-{component}-{major}-{minor} (e.g., konflux-submariner-operator-0-23)"
      echo "  - Release: release-{major}.{minor} (e.g., release-0.23)"
      echo ""
      echo "Extracted: VERSION_MAJOR='$VERSION_MAJOR' VERSION_MINOR='$VERSION_MINOR'"
      exit 1
      ;;
  esac
  case "$VERSION_MINOR" in
    ''|*[!0-9]*)
      echo "❌ ERROR: Could not extract version from branch: $CURRENT_BRANCH"
      echo "Expected patterns:"
      echo "  - Bot: konflux-{component}-{major}-{minor} (e.g., konflux-submariner-operator-0-23)"
      echo "  - Release: release-{major}.{minor} (e.g., release-0.23)"
      echo ""
      echo "Extracted: VERSION_MAJOR='$VERSION_MAJOR' VERSION_MINOR='$VERSION_MINOR'"
      exit 1
      ;;
  esac
fi

# Get current branch (after checkout if VERSION path, already set in no-VERSION path)
if [ -z "$CURRENT_BRANCH" ]; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "❌ ERROR: Not on a branch (detached HEAD)"
    exit 1
  fi
fi

# Validate component is known
if [ -z "${COMPONENT_META[$COMPONENT]:-}" ]; then
  echo "❌ ERROR: Unknown component: $COMPONENT"
  echo ""
  echo "Known components:"
  for comp in "${!COMPONENT_META[@]}"; do
    echo "  - $comp"
  done | sort
  exit 1
fi

VERSION_DASHED="${VERSION_MAJOR}-${VERSION_MINOR}"
VERSION_DOTTED="${VERSION_MAJOR}.${VERSION_MINOR}"
TARGET_BRANCH="release-${VERSION_DOTTED}"
PREV_VERSION=$((VERSION_MINOR - 1))
ACM_VERSION=$((VERSION_MINOR - 7))

# Validate ACM version is non-negative
if [ "$ACM_VERSION" -lt 0 ]; then
  echo "❌ ERROR: ACM version would be negative: 2.$ACM_VERSION"
  echo "Minimum supported version is 0.7 (ACM 2.0)"
  exit 1
fi

# Validate .tekton directory exists (bot created it)
if [ ! -d .tekton ]; then
  echo "❌ ERROR: .tekton directory not found"
  echo "The Konflux bot must create the initial PR with .tekton files first."
  echo "Wait for the bot to create the PR, then checkout the bot branch."
  exit 1
fi

# Validate previous release branch exists
git rev-parse --verify "origin/release-${VERSION_MAJOR}.${PREV_VERSION}" &>/dev/null || {
  echo "❌ ERROR: Previous release branch not found: release-${VERSION_MAJOR}.${PREV_VERSION}"
  echo "This script needs to copy files from the previous release."
  exit 1
}

# Extract component metadata
IFS=':' read -r PREFETCH_TYPE HAS_CPE SPECIAL_FILES <<< "${COMPONENT_META[$COMPONENT]}"

# Determine lockfile component name (strips submariner- prefix)
# Used by Steps 3 and 6 for RPM lockfile paths
case "$COMPONENT" in
  submariner-*)
    LOCKFILE_COMPONENT="${COMPONENT#submariner-}"
    ;;
  *)
    LOCKFILE_COMPONENT="$COMPONENT"
    ;;
esac

# Save state for subsequent steps
echo "$COMPONENT" > /tmp/konflux-setup-component.txt
echo "$LOCKFILE_COMPONENT" > /tmp/konflux-setup-lockfile-component.txt
echo "$VERSION_DASHED" > /tmp/konflux-setup-version-dashed.txt
echo "$VERSION_DOTTED" > /tmp/konflux-setup-version-dotted.txt
echo "$VERSION_MAJOR" > /tmp/konflux-setup-version-major.txt
echo "$VERSION_MINOR" > /tmp/konflux-setup-version-minor.txt
echo "$TARGET_BRANCH" > /tmp/konflux-setup-target-branch.txt
echo "$PREV_VERSION" > /tmp/konflux-setup-prev-version.txt
echo "$ACM_VERSION" > /tmp/konflux-setup-acm-version.txt
echo "$PREFETCH_TYPE" > /tmp/konflux-setup-prefetch-type.txt
echo "$HAS_CPE" > /tmp/konflux-setup-has-cpe.txt
echo "$SPECIAL_FILES" > /tmp/konflux-setup-special-files.txt
echo "$(pwd)" > /tmp/konflux-setup-repo-path.txt

# Summary
echo ""
echo "━━━ Configuration Summary ━━━"
echo "Component:      $COMPONENT"
echo "Current branch: $CURRENT_BRANCH"
echo "Target branch:  $TARGET_BRANCH"
echo "Previous ver:   ${VERSION_MAJOR}.${PREV_VERSION}"
echo "ACM version:    2.${ACM_VERSION}"
echo "Prefetch type:  $PREFETCH_TYPE"
echo "Has CPE label:  $HAS_CPE"
if [ -n "$SPECIAL_FILES" ]; then
  echo "Special files:  $SPECIAL_FILES"
fi
echo ""

# Create common functions file for Steps 2-10
cat > /tmp/konflux-setup-functions.sh << 'FUNCTIONS_EOF'
# Common functions for konflux-component-setup skill

load_state() {
  # Load state variables from /tmp files, validate required variables, and cd to REPO_PATH
  # $1 = space-separated list of required variables (e.g., "COMPONENT VERSION_DASHED REPO_PATH")
  # $2 = current step number for error message (e.g., "4")

  # Load ALL possible state variables
  COMPONENT=$(cat /tmp/konflux-setup-component.txt 2>/dev/null)
  VERSION_MAJOR=$(cat /tmp/konflux-setup-version-dotted.txt 2>/dev/null | cut -d. -f1)
  VERSION_MINOR=$(cat /tmp/konflux-setup-version-dotted.txt 2>/dev/null | cut -d. -f2)
  VERSION_DASHED=$(cat /tmp/konflux-setup-version-dashed.txt 2>/dev/null)
  TARGET_BRANCH=$(cat /tmp/konflux-setup-target-branch.txt 2>/dev/null)
  PREV_VERSION=$(cat /tmp/konflux-setup-prev-version.txt 2>/dev/null)
  ACM_VERSION=$(cat /tmp/konflux-setup-acm-version.txt 2>/dev/null)
  HAS_CPE=$(cat /tmp/konflux-setup-has-cpe.txt 2>/dev/null)
  SPECIAL_FILES=$(cat /tmp/konflux-setup-special-files.txt 2>/dev/null)
  PREFETCH_TYPE=$(cat /tmp/konflux-setup-prefetch-type.txt 2>/dev/null)
  LOCKFILE_COMPONENT=$(cat /tmp/konflux-setup-lockfile-component.txt 2>/dev/null)
  REPO_PATH=$(cat /tmp/konflux-setup-repo-path.txt 2>/dev/null)

  # Validate required variables (portable - works in bash and zsh)
  # Enable word splitting for zsh compatibility
  if [ -n "$ZSH_VERSION" ]; then
    setopt SH_WORD_SPLIT
  fi

  for var in $1; do
    case "$var" in
      COMPONENT) [ -z "$COMPONENT" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      VERSION_MAJOR) [ -z "$VERSION_MAJOR" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      VERSION_MINOR) [ -z "$VERSION_MINOR" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      VERSION_DASHED) [ -z "$VERSION_DASHED" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      TARGET_BRANCH) [ -z "$TARGET_BRANCH" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      PREV_VERSION) [ -z "$PREV_VERSION" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      ACM_VERSION) [ -z "$ACM_VERSION" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      HAS_CPE) [ -z "$HAS_CPE" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      SPECIAL_FILES) [ -z "$SPECIAL_FILES" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      PREFETCH_TYPE) [ -z "$PREFETCH_TYPE" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      LOCKFILE_COMPONENT) [ -z "$LOCKFILE_COMPONENT" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      REPO_PATH) [ -z "$REPO_PATH" ] && { echo "❌ ERROR: State not found. Run Steps 1-$(($2 - 1)) first."; exit 1; } ;;
      *) echo "❌ ERROR: Unknown variable in validation: $var"; exit 1 ;;
    esac
  done

  # Restore zsh behavior
  if [ -n "$ZSH_VERSION" ]; then
    unsetopt SH_WORD_SPLIT
  fi

  # Change to repository directory
  cd "$REPO_PATH" || {
    echo "❌ ERROR: Cannot change to directory: $REPO_PATH"
    exit 1
  }
}

commit_changes() {
  # Wrapper for git commit with standardized error handling
  # $1 = commit message
  # $2 (optional) = success message (defaults to "Changes committed")

  git commit -s -m "$1" || {
    echo "❌ ERROR: Failed to commit changes"
    exit 1
  }
  echo "✅ ${2:-Changes committed}"
}
FUNCTIONS_EOF

echo "✅ Functions file created: /tmp/konflux-setup-functions.sh"
```

---

## Step 2: Configure YAMLlint Ignore

Add `.tekton` and `.rpm-lockfiles` (if needed) to yamllint ignore list.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT PREFETCH_TYPE REPO_PATH" 2

echo "━━━ Step 2: Configure YAMLlint Ignore ━━━"

CHANGED=false

# Add .tekton
grep -q "\.tekton" .yamllint.yml 2>/dev/null && {
  echo "ℹ️  .tekton already in yamllint ignore"
} || {
  sed -i '/^ignore: |$/a\  .tekton' .yamllint.yml || {
    echo "❌ ERROR: Failed to add .tekton to yamllint ignore"
    exit 1
  }
  echo "✓ Added .tekton to yamllint ignore"
  CHANGED=true
}

# Add .rpm-lockfiles if component has RPM dependencies
case "$PREFETCH_TYPE" in
  *rpm*)
    grep -q "\.rpm-lockfiles" .yamllint.yml 2>/dev/null && {
      echo "ℹ️  .rpm-lockfiles already in yamllint ignore"
    } || {
      sed -i '/^ignore: |$/a\  .rpm-lockfiles' .yamllint.yml || {
        echo "❌ ERROR: Failed to add .rpm-lockfiles to yamllint ignore"
        exit 1
      }
      echo "✓ Added .rpm-lockfiles to yamllint ignore"
      CHANGED=true
    }
    ;;
esac

if [ "$CHANGED" = true ]; then
  git add .yamllint.yml || {
    echo "❌ ERROR: Failed to stage .yamllint.yml"
    exit 1
  }
  commit_changes "Configure yamllint ignore for Konflux directories" "Committed yamllint configuration"
else
  echo "✅ YAMLlint already configured (no commit needed)"
fi
```

---

## Step 3: Add RPM Lockfile Support (Conditional)

**Only for components with RPM dependencies** (submariner-gateway, submariner-globalnet,
submariner-route-agent, nettest). Automatically skipped for gomod-only components.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT LOCKFILE_COMPONENT PREFETCH_TYPE PREV_VERSION TARGET_BRANCH REPO_PATH" 3

# Skip if no RPM dependencies
case "$PREFETCH_TYPE" in
  *rpm*)
    # Has RPM dependencies - proceed
    ;;
  *)
    echo "━━━ Step 3: Add RPM Lockfile Support ━━━"
    echo "ℹ️  Component has no RPM dependencies - skipping"
    exit 0
    ;;
esac

echo "━━━ Step 3: Add RPM Lockfile Support ━━━"

# Copy lockfile infrastructure:
# - Scripts (update-lockfile.sh, etc.) from devel (always use latest)
# - Component directory from previous release (starting point for new release)

# Copy scripts from devel using git show (more reliable)
mkdir -p .rpm-lockfiles
git show "origin/devel:.rpm-lockfiles/update-lockfile.sh" > .rpm-lockfiles/update-lockfile.sh || {
  echo "❌ ERROR: Could not copy update-lockfile.sh from devel"
  exit 1
}

# Copy additional scripts if they exist
for script in check-repo-access.sh verify-packages.sh; do
  if git show "origin/devel:.rpm-lockfiles/${script}" > ".rpm-lockfiles/${script}" 2>/dev/null; then
    chmod +x ".rpm-lockfiles/${script}"
  fi
done

# Make update-lockfile.sh executable
chmod +x .rpm-lockfiles/update-lockfile.sh || {
  echo "❌ ERROR: Failed to make update-lockfile.sh executable"
  exit 1
}

# Copy component-specific lockfile directory from previous release
git archive "origin/release-0.${PREV_VERSION}" ".rpm-lockfiles/${LOCKFILE_COMPONENT}/" | tar -x || {
  echo "❌ ERROR: Could not copy lockfile directory from previous release"
  echo "Expected: .rpm-lockfiles/${LOCKFILE_COMPONENT}/ on branch release-0.${PREV_VERSION}"
  exit 1
}

# Generate lockfile
echo "ℹ️  Generating RPM lockfile for $LOCKFILE_COMPONENT..."
.rpm-lockfiles/update-lockfile.sh "$LOCKFILE_COMPONENT" || {
  echo "❌ ERROR: Lockfile generation failed"
  echo "Check RPM repository access and package availability"
  exit 1
}

# Verify lockfile was created
if [ ! -f ".rpm-lockfiles/${LOCKFILE_COMPONENT}/rpms.lock.yaml" ]; then
  echo "❌ ERROR: Lockfile not created: .rpm-lockfiles/${LOCKFILE_COMPONENT}/rpms.lock.yaml"
  exit 1
fi

git add .rpm-lockfiles/ || {
  echo "❌ ERROR: Failed to stage .rpm-lockfiles/"
  exit 1
}
commit_changes "Add RPM lockfile support for ${LOCKFILE_COMPONENT}" "RPM lockfile added and committed"
```

---

## Step 4: Copy and Configure Konflux Dockerfile

Copy Dockerfile from previous release and update version references, CPE labels, and Tekton config.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_DASHED TARGET_BRANCH PREV_VERSION REPO_PATH" 4

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 4: Add Konflux Dockerfile ━━━"

# Determine Dockerfile path
DOCKERFILE="package/Dockerfile.${COMPONENT}.konflux"

# Copy Dockerfile from previous release using git show (more reliable than checkout)
git show "origin/release-${VERSION_MAJOR}.${PREV_VERSION}:${DOCKERFILE}" > "${DOCKERFILE}" || {
  echo "❌ ERROR: Could not copy Dockerfile from previous release"
  echo "Expected: $DOCKERFILE on branch release-${VERSION_MAJOR}.${PREV_VERSION}"
  exit 1
}

echo "✓ Copied Dockerfile from release-${VERSION_MAJOR}.${PREV_VERSION}"

# Copy special files if needed
if [ -n "$SPECIAL_FILES" ]; then
  IFS=',' read -ra FILES <<< "$SPECIAL_FILES"
  for file in "${FILES[@]}"; do
    # nettest has metricsproxy.konflux in scripts/nettest/
    SPECIAL_PATH="scripts/${COMPONENT}/${file}.konflux"
    if git show "origin/release-${VERSION_MAJOR}.${PREV_VERSION}:${SPECIAL_PATH}" > "${SPECIAL_PATH}" 2>/dev/null; then
      if [ -f "$SPECIAL_PATH" ]; then
        echo "✓ Copied special file: $SPECIAL_PATH"
      else
        echo "⚠️  Warning: Special file copy succeeded but file not found: $SPECIAL_PATH"
      fi
    else
      echo "⚠️  Warning: Could not copy special file: $SPECIAL_PATH"
    fi
  done
fi

# Update version references in Dockerfile
sed -i "s/release-${VERSION_MAJOR}.${PREV_VERSION}/${TARGET_BRANCH}/g" "$DOCKERFILE" || {
  echo "❌ ERROR: Failed to update branch references in Dockerfile"
  exit 1
}

# Verify the sed actually changed something
grep -q "${TARGET_BRANCH}" "$DOCKERFILE" || {
  echo "❌ ERROR: Branch reference update failed - ${TARGET_BRANCH} not found in Dockerfile"
  exit 1
}

echo "✓ Updated branch references: release-${VERSION_MAJOR}.${PREV_VERSION} -> ${TARGET_BRANCH}"

# Update CPE label if component has it
if [ "$HAS_CPE" = "yes" ]; then
  if grep -q "cpe=" "$DOCKERFILE"; then
    sed -i "s/cpe=\"cpe:\/a:redhat:acm:[0-9.]*::el9\"/cpe=\"cpe:\/a:redhat:acm:2.${ACM_VERSION}::el9\"/" "$DOCKERFILE" || {
      echo "❌ ERROR: Failed to update CPE label in Dockerfile"
      exit 1
    }
    # Verify the update worked
    if grep -q "cpe=\"cpe:/a:redhat:acm:2.${ACM_VERSION}::el9\"" "$DOCKERFILE"; then
      echo "✓ Updated CPE label: ACM 2.${ACM_VERSION}"
    else
      echo "❌ ERROR: CPE label update verification failed"
      exit 1
    fi
  else
    echo "⚠️  Warning: CPE label not found in Dockerfile (component may not need it)"
  fi
fi

# Update version label for Y-stream (initial version)
# Change version="${BASE_BRANCH}" or version="vX.Y.Z" to version="v0.M.0"
if grep -q 'version=' "$DOCKERFILE"; then
  sed -i "s/version=\"[^\"]*\"/version=\"v${VERSION_MAJOR}.${VERSION_MINOR}.0\"/" "$DOCKERFILE" || {
    echo "❌ ERROR: Failed to update version label in Dockerfile"
    exit 1
  }
  # Verify the update worked
  grep -q "version=\"v${VERSION_MAJOR}.${VERSION_MINOR}.0\"" "$DOCKERFILE" && {
    echo "✓ Updated version label: v${VERSION_MAJOR}.${VERSION_MINOR}.0"
  } || {
    echo "❌ ERROR: Version label update verification failed"
    exit 1
  }
else
  echo "⚠️  Warning: No version label found in Dockerfile"
fi

# Remove obsolete go generate line if present (operator only)
if [ "$COMPONENT" = "submariner-operator" ]; then
  if grep -q "^RUN go generate pkg/embeddedyamls/generate.go$" "$DOCKERFILE"; then
    sed -i '/^RUN go generate pkg\/embeddedyamls\/generate.go$/d' "$DOCKERFILE" || {
      echo "❌ ERROR: Failed to remove obsolete go generate line"
      exit 1
    }
    echo "✓ Removed obsolete go generate line"
  fi
fi

# Update Tekton config to use Konflux Dockerfile (component-specific files only)
for file in "${TEKTON_FILES[@]}"; do
  [ -f "$file" ] || {
    echo "❌ ERROR: No Tekton files found matching pattern: .tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml"
    exit 1
  }
  sed -i "s|package/Dockerfile.${COMPONENT}|package/Dockerfile.${COMPONENT}.konflux|g" "$file" || {
    echo "❌ ERROR: Failed to update Tekton config to use Konflux Dockerfile"
    exit 1
  }
done

# Verify Tekton update worked
if grep -q "package/Dockerfile.${COMPONENT}.konflux" "${TEKTON_FILES[@]}"; then
  echo "✓ Updated Tekton to use Konflux Dockerfile"
else
  echo "❌ ERROR: Tekton config update verification failed"
  exit 1
fi

# Commit changes
git add package/ "${TEKTON_FILES[@]}" || exit 1

# Also add scripts/ if it exists (optional - only nettest has special files)
if [ -d scripts/ ]; then
  git add scripts/ || true  # Non-fatal if scripts/ staging fails
fi

commit_changes "Add Konflux Dockerfile for ${COMPONENT}" "Dockerfile configured and committed"
```

---

## Step 5: Add Build Args File (Operator Only)

**Only for submariner-operator**. Copy and configure `.tekton/konflux.args` build arguments file. Automatically skipped for other components.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_DASHED TARGET_BRANCH PREV_VERSION REPO_PATH" 5

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

# Skip if not operator
if [ "$COMPONENT" != "submariner-operator" ]; then
  echo "━━━ Step 5: Add Build Args File ━━━"
  echo "ℹ️  Component is not operator - skipping"
  exit 0
fi

echo "━━━ Step 5: Add Build Args File ━━━"

# Check if already configured (component-specific files only)
# Verify: (1) parameter VALUE in spec.params, (2) file exists, (3) correct content
if grep -q "^  - name: build-args-file$" "${TEKTON_FILES[@]}" 2>/dev/null && \
   [ -f .tekton/konflux.args ] && \
   grep -q "BASE_BRANCH=${TARGET_BRANCH}" .tekton/konflux.args 2>/dev/null; then
  echo "ℹ️  Build args file already configured"
  exit 0
fi

# Copy konflux.args from previous release using git show (more reliable)
git show "origin/release-${VERSION_MAJOR}.${PREV_VERSION}:.tekton/konflux.args" > .tekton/konflux.args || {
  echo "❌ ERROR: Could not copy .tekton/konflux.args from previous release"
  echo "Expected: .tekton/konflux.args on branch release-${VERSION_MAJOR}.${PREV_VERSION}"
  exit 1
}

echo "✓ Copied .tekton/konflux.args from release-${VERSION_MAJOR}.${PREV_VERSION}"

# Update version references
sed -i "s/release-${VERSION_MAJOR}.${PREV_VERSION}/${TARGET_BRANCH}/g" .tekton/konflux.args || {
  echo "❌ ERROR: Failed to update version references in konflux.args"
  exit 1
}

# Verify the sed worked
grep -q "${TARGET_BRANCH}" .tekton/konflux.args || {
  echo "❌ ERROR: Version update verification failed in konflux.args"
  exit 1
}

echo "✓ Updated branch references in konflux.args"

# Add build-args-file parameter to Tekton config (after dockerfile parameter)
# Component-specific files only
for file in "${TEKTON_FILES[@]}"; do
  [ -f "$file" ] || {
    echo "❌ ERROR: No Tekton files found matching pattern: .tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml"
    exit 1
  }
  sed -i '/value: package\/Dockerfile.submariner-operator.konflux$/a\  - name: build-args-file\n    value: .tekton/konflux.args' "$file" || {
    echo "❌ ERROR: Failed to add build-args-file parameter to Tekton config"
    exit 1
  }
done

# Verify parameter was added
grep -q "name: build-args-file" "${TEKTON_FILES[@]}" || {
  echo "❌ ERROR: build-args-file parameter not found in Tekton config after adding"
  exit 1
}

echo "✓ Added build-args-file parameter to Tekton config"

git add "${TEKTON_FILES[@]}" .tekton/konflux.args || exit 1
commit_changes "Add hermetic build args file for ${COMPONENT}" "Build args file configured and committed"
```

---

## Step 6: Enable Hermetic Builds

Add prefetch-input and hermetic flag to Tekton config.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT PREFETCH_TYPE VERSION_DASHED REPO_PATH" 6

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 6: Enable Hermetic Builds ━━━"

# Check if already configured (component-specific files only)
if grep -q "^  - name: hermetic$" "${TEKTON_FILES[@]}" 2>/dev/null; then
  echo "ℹ️  Hermetic builds already enabled"
  exit 0
fi

# Build prefetch-input JSON based on type
case "$PREFETCH_TYPE" in
  gomod+rpm)
    # Load lockfile component name from state
    LOCKFILE_COMPONENT=$(cat /tmp/konflux-setup-lockfile-component.txt 2>/dev/null)
    [ -z "$LOCKFILE_COMPONENT" ] && {
      echo "❌ ERROR: LOCKFILE_COMPONENT not found in state"
      exit 1
    }
    PREFETCH_JSON="[{\"type\": \"gomod\", \"path\": \".\"}, {\"type\": \"gomod\", \"path\": \"tools\"}, {\"type\": \"rpm\", \"path\": \"./.rpm-lockfiles/${LOCKFILE_COMPONENT}\"}]"
    ;;
  gomod)
    # Component-specific gomod paths
    case "$COMPONENT" in
      lighthouse-coredns)
        # Uses only coredns module
        PREFETCH_JSON="[{\"type\": \"gomod\", \"path\": \"./coredns\"}]"
        ;;
      subctl)
        # Uses only root module
        PREFETCH_JSON="[{\"type\": \"gomod\", \"path\": \".\"}]"
        ;;
      *)
        # Default: root + tools (operator, lighthouse-agent)
        PREFETCH_JSON="[{\"type\": \"gomod\", \"path\": \".\"}, {\"type\": \"gomod\", \"path\": \"tools\"}]"
        ;;
    esac
    ;;
  rpm)
    # nettest is rpm-only
    PREFETCH_JSON="[{\"type\": \"rpm\", \"path\": \"./.rpm-lockfiles/${COMPONENT}\"}]"
    ;;
  *)
    echo "❌ ERROR: Unknown prefetch type: $PREFETCH_TYPE"
    exit 1
    ;;
esac

echo "ℹ️  Prefetch configuration: $PREFETCH_JSON"

# Add hermetic build parameters
# Insert before pipelineSpec: line using awk (portable across sed versions)
# Only modify component-specific files (not bundle)
for file in "${TEKTON_FILES[@]}"; do
  [ -f "$file" ] || {
    echo "❌ ERROR: No Tekton files found matching pattern: .tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml"
    exit 1
  }
  awk -v prefetch="$PREFETCH_JSON" '
    /^  pipelineSpec:$/ {
      print "  - name: prefetch-input"
      print "    value: '\''" prefetch "'\''"
      print "  - name: hermetic"
      print "    value: \"true\""
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file" || {
    echo "❌ ERROR: Failed to add hermetic build parameters to $file"
    exit 1
  }
done

# Verify parameters were added
grep -q "name: hermetic" "${TEKTON_FILES[@]}" || \
  ! grep -q "name: prefetch-input" "${TEKTON_FILES[@]}" || {
  echo "❌ ERROR: Hermetic build parameters not found after adding"
  exit 1
}

git add "${TEKTON_FILES[@]}" || exit 1
commit_changes "Enable hermetic builds with prefetching for ${COMPONENT}" "Hermetic builds enabled and committed"
```

---

## Step 7: Add Multi-Platform Support

Add multi-architecture support (ARM64, PPC64LE, S390X).

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_DASHED REPO_PATH" 7

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 7: Add Multi-Platform Support ━━━"

# Check if already configured (component-specific files only)
if grep -q "linux/arm64" "${TEKTON_FILES[@]}" 2>/dev/null; then
  echo "ℹ️  Multi-platform already enabled"
  exit 0
fi

# Add ARM64, PPC64LE, and S390X support (component-specific files only)
for file in "${TEKTON_FILES[@]}"; do
  [ -f "$file" ] || {
    echo "❌ ERROR: No Tekton files found matching pattern: .tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml"
    exit 1
  }
  sed -i '/^    - linux\/x86_64$/a\    - linux/arm64\n    - linux/ppc64le\n    - linux/s390x' "$file" || {
    echo "❌ ERROR: Failed to add multi-platform support to Tekton config"
    exit 1
  }
done

# Verify platforms were added
grep -q "linux/arm64" "${TEKTON_FILES[@]}" || {
  echo "❌ ERROR: Multi-platform architectures not found after adding"
  exit 1
}

git add "${TEKTON_FILES[@]}" || exit 1
commit_changes "Add multi-platform build support for ${COMPONENT}" "Multi-platform support enabled and committed"
```

---

## Step 8: Enable SBOM Generation

Enable source image builds for SBOM.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_DASHED REPO_PATH" 8

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 8: Enable SBOM Generation ━━━"

# Check if already configured (component-specific files only)
if grep -q "^  - name: build-source-image$" "${TEKTON_FILES[@]}" 2>/dev/null; then
  echo "ℹ️  SBOM generation already enabled"
  exit 0
fi

# Add build-source-image parameter after hermetic (component-specific files only)
for file in "${TEKTON_FILES[@]}"; do
  [ -f "$file" ] || {
    echo "❌ ERROR: No Tekton files found matching pattern: .tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml"
    exit 1
  }
  sed -i '/  - name: hermetic$/,/    value: "true"$/{
    /    value: "true"$/a\
    - name: build-source-image\
      value: "true"
  }' "$file" || {
    echo "❌ ERROR: Failed to add build-source-image parameter to Tekton config"
    exit 1
  }
done

# Verify parameter was added
grep -q "name: build-source-image" "${TEKTON_FILES[@]}" || {
  echo "❌ ERROR: build-source-image parameter not found after adding"
  exit 1
}

git add "${TEKTON_FILES[@]}" || exit 1
commit_changes "Enable SBOM generation for ${COMPONENT}" "SBOM generation enabled and committed"
```

---

## Step 9: Update Task References

Update Tekton task references to latest versions using pipeline-patcher.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_DASHED REPO_PATH" 9

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 9: Update Task References ━━━"

# Pipeline patcher configuration (from konflux-ci-fix)
PATCHER_SHA="b001763bb1cd0286a894cfb570fe12dd7f4504bd"
EXPECTED_SHA256="080ad5d7cf7d0cee732a774b7e4dda0e2ccf26b58e08a8516a3b812bc73beb53"

echo "ℹ️  Downloading pipeline-patcher..."
SCRIPT=$(curl -sL "https://raw.githubusercontent.com/simonbaird/konflux-pipeline-patcher/${PATCHER_SHA}/pipeline-patcher")

# Verify download succeeded
if [ -z "$SCRIPT" ]; then
  echo "❌ ERROR: Failed to download pipeline-patcher script"
  echo "Check network connectivity and GitHub access"
  exit 1
fi

# Verify checksum
if command -v sha256sum &>/dev/null; then
  ACTUAL_SHA256=$(echo "$SCRIPT" | sha256sum | cut -d' ' -f1)
else
  ACTUAL_SHA256=$(echo "$SCRIPT" | shasum -a 256 | cut -d' ' -f1)
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "❌ ERROR: Pipeline patcher checksum mismatch!"
  echo "Expected: $EXPECTED_SHA256"
  echo "Actual:   $ACTUAL_SHA256"
  exit 1
fi

echo "✓ Checksum verified"

# Run pipeline-patcher (modifies all .tekton/*.yaml but we only commit component files)
echo "ℹ️  Updating task references..."

# Save current state of non-component files (e.g., bundle) before patcher runs
# This prevents bundle files from being accidentally modified
TEMP_DIR=$(mktemp -d)
for file in .tekton/*.yaml; do
  # Check if file is in TEKTON_FILES array
  FOUND=false
  for tf in "${TEKTON_FILES[@]}"; do
    [ "$file" = "$tf" ] && FOUND=true && break
  done

  if [ "$FOUND" = false ]; then
    # Save non-component files (e.g., bundle)
    cp "$file" "$TEMP_DIR/" 2>/dev/null || true
  fi
done

# Run patcher (will modify all .tekton/*.yaml files)
echo "$SCRIPT" | bash -s bump-task-refs || {
  echo "❌ ERROR: Pipeline patcher execution failed"
  rm -rf "$TEMP_DIR"
  exit 1
}

# Restore non-component files to prevent bundle modifications
for file in "$TEMP_DIR"/*.yaml; do
  [ -f "$file" ] && cp "$file" .tekton/
done
rm -rf "$TEMP_DIR"

# Check if component files changed
if git diff --quiet "${TEKTON_FILES[@]}"; then
  echo "ℹ️  Task references already up to date"
  exit 0
fi

git add "${TEKTON_FILES[@]}" || exit 1
commit_changes "Update Tekton task references to latest versions" "Task references updated and committed"
```

---

## Step 10: Add File Change Filters (Operator Only)

Add CEL expression filters to prevent operator builds when only bundle changes.

**Operator-specific:** This step only runs for submariner-operator. Other components skip this step.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT VERSION_MAJOR VERSION_MINOR PREV_VERSION REPO_PATH" 10

# Calculate version in dashed format
VERSION_DASHED="${VERSION_MAJOR}-${VERSION_MINOR}"

# Tekton files for this component
TEKTON_FILES=(.tekton/${COMPONENT}-${VERSION_DASHED}-*.yaml)

echo "━━━ Step 10: Add File Change Filters ━━━"

# Only apply to operator
if [ "$COMPONENT" != "submariner-operator" ]; then
  echo "ℹ️  Component is not operator - skipping file change filters"
  exit 0
fi

# Check if already applied - both files must have filters to skip
FILTER_COUNT=$(grep -l "pathChanged()" "${TEKTON_FILES[@]}" 2>/dev/null | wc -l)
if [ "$FILTER_COUNT" -eq 2 ]; then
  echo "ℹ️  File change filters already present in both files"
  exit 0
fi

# Construct previous version in dashed format for filenames (e.g., "0-22")
PREV_VERSION_DASHED="${VERSION_MAJOR}-${PREV_VERSION}"

echo "📋 Copying CEL expressions from release-${VERSION_MAJOR}.${PREV_VERSION} branch..."

# Process both pull-request and push files
for FILE_TYPE in pull-request push; do
  CURRENT_FILE=".tekton/${COMPONENT}-${VERSION_DASHED}-${FILE_TYPE}.yaml"
  PREV_FILE=".tekton/${COMPONENT}-${PREV_VERSION_DASHED}-${FILE_TYPE}.yaml"

  if [ ! -f "$CURRENT_FILE" ]; then
    echo "⚠️  Warning: $CURRENT_FILE not found, skipping"
    continue
  fi

  # Extract CEL expression from previous branch (single-line format)
  CEL_LINE=$(git show "origin/release-${VERSION_MAJOR}.${PREV_VERSION}:${PREV_FILE}" 2>/dev/null | \
    grep 'pipelinesascode.tekton.dev/on-cel-expression:')

  [ -z "$CEL_LINE" ] && {
    echo "⚠️  Could not extract CEL from ${PREV_FILE} - previous branch may not have filters yet"
    continue
  }

  # Update version numbers in the expression
  CEL_LINE_UPDATED=$(echo "$CEL_LINE" | \
    sed -e "s/release-${VERSION_MAJOR}.${PREV_VERSION}/release-${VERSION_MAJOR}.${VERSION_MINOR}/g" \
        -e "s/${COMPONENT}-${PREV_VERSION_DASHED}/${COMPONENT}-${VERSION_DASHED}/g")

  # Verify max-keep-runs exists before modifying (we need it as insertion point)
  grep -q 'pipelinesascode.tekton.dev/max-keep-runs:' "$CURRENT_FILE" || {
    echo "⚠️  Warning: max-keep-runs annotation not found in $CURRENT_FILE"
    echo "   Cannot add file change filters without insertion point. Skipping."
    continue
  }

  # Delete bot's CEL expression (handles both 1-line and 2-line formats)
  # Bot may generate 2-line: "...on-cel-expression: event == \"pull_request\" && target_branch\n      == \"release-0.23\""
  # Or 1-line: "...on-cel-expression: event == \"pull_request\" && target_branch == \"release-0.23\""
  awk '/pipelinesascode.tekton.dev\/on-cel-expression:/ {
    skip=1
    next
  }
  skip && /^[[:space:]]+==/ {
    skip=0
    next
  }
  {
    skip=0
    print
  }' "$CURRENT_FILE" > "${CURRENT_FILE}.tmp" || {
    echo "❌ ERROR: Failed to delete bot's CEL expression from $CURRENT_FILE"
    rm -f "${CURRENT_FILE}.tmp"
    exit 1
  }

  mv "${CURRENT_FILE}.tmp" "$CURRENT_FILE" || {
    echo "❌ ERROR: Failed to replace $CURRENT_FILE after CEL deletion"
    exit 1
  }

  # Insert updated CEL expression after max-keep-runs using awk for better YAML preservation
  awk -v cel="$CEL_LINE_UPDATED" \
    '/pipelinesascode.tekton.dev\/max-keep-runs:/ {print; print cel; next} {print}' \
    "$CURRENT_FILE" > "${CURRENT_FILE}.tmp" || {
    echo "❌ ERROR: Failed to insert updated CEL expression into $CURRENT_FILE"
    rm -f "${CURRENT_FILE}.tmp"
    exit 1
  }

  mv "${CURRENT_FILE}.tmp" "$CURRENT_FILE" || {
    echo "❌ ERROR: Failed to replace $CURRENT_FILE with updated version"
    exit 1
  }

  # Validate this file's YAML syntax immediately
  yq eval '.' "$CURRENT_FILE" > /dev/null 2>&1 || {
    echo "❌ ERROR: YAML validation failed for $CURRENT_FILE after adding CEL expression"
    git checkout "$CURRENT_FILE"  # Rollback this file
    exit 1
  }

  echo "✓ Added file change filters to $CURRENT_FILE"
done

# Check if any changes were made to this component's files
git diff --quiet "${TEKTON_FILES[@]}" && {
  echo "⚠️  No changes made - previous branch may not have filters configured yet."
  echo "   Skipping commit. Filters will need to be added manually."
  exit 0
}

# Commit only the files we modified (per-file validation already done above)
git add "${TEKTON_FILES[@]}" || exit 1

commit_changes "Add file change filters for operator builds

Add file change filters to CEL expressions in Tekton pipelines.
This prevents operator builds when only bundle files change,
reducing unnecessary pipeline runs." "File change filters added and committed"
```

---

## Step 11: Summary and Next Steps

Show what was done and provide next steps.

```bash
#!/bin/bash
source /tmp/konflux-setup-functions.sh
load_state "COMPONENT TARGET_BRANCH REPO_PATH" 11

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete for $COMPONENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show commits
COMMIT_COUNT=$(git log "origin/${TARGET_BRANCH}..HEAD" --oneline 2>/dev/null | wc -l | tr -d ' ')
echo "📝 Commits created: $COMMIT_COUNT"
git log "origin/${TARGET_BRANCH}..HEAD" --oneline 2>/dev/null || echo "(Could not fetch commit log)"
echo ""

# Show working tree status
if git diff --quiet && git diff --cached --quiet; then
  echo "✅ Working tree clean"
else
  echo "⚠️  Uncommitted changes detected:"
  git status --short
fi

echo ""
echo "━━━ Next Steps ━━━"
echo ""
echo "1. Review changes:"
echo "   git log origin/${TARGET_BRANCH}..HEAD"
echo "   git diff origin/${TARGET_BRANCH}..HEAD"
echo ""
echo "2. Validate YAML syntax:"
echo "   yq eval '.' .tekton/*.yaml > /dev/null && echo '✅ Valid'"
echo ""
echo "3. Push to remote:"
echo "   git push origin $CURRENT_BRANCH --force-with-lease"
echo ""
echo "4. Wait for build (~15-30 min) and verify:"
echo "   oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep ${COMPONENT}"
echo ""

# Cleanup temp files
rm -f /tmp/konflux-setup-*.txt

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```
