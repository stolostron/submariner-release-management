# Skills

## /learn-release

Teaches Submariner release process

```bash
/learn-release overview
/learn-release step 5
```

## /release-ls

Checks release status

```bash
/release-ls 0.22.0
```

## /configure-downstream

Configure Konflux for new Submariner version (Y-stream releases)

```bash
/configure-downstream 0.23
/configure-downstream 0.23.0  # Extracts major.minor
```

## /add-team-member

Add user to Submariner Konflux team RBAC

```bash
/add-team-member alice maintainer
/add-team-member bob admin
/add-team-member charlie  # Defaults to contributor (read-only)
```

## /konflux-ci-fix

Diagnose and fix Konflux CI Enterprise Contract violations

```bash
# From release-management (use shortcuts):
/konflux-ci-fix operator              # Short form
/konflux-ci-fix lighthouse 0.21       # Short form with branch
/konflux-ci-fix PR-1234 subctl        # Short form with PR

# Or use full paths:
/konflux-ci-fix ~/go/src/submariner-io/submariner-operator

# From component repo:
/konflux-ci-fix                       # Current repo, current branch
/konflux-ci-fix 0.21                  # Current repo, specified branch
/konflux-ci-fix PR-1234               # Current repo, specific PR
```

**Shortcuts:** operator, submariner, lighthouse, shipyard, subctl

## /konflux-component-setup

Automate Konflux component setup on new release branches

Configures Tekton pipelines, Dockerfiles, RPM lockfiles, and hermetic builds for Submariner components.
Handles 8 components across 5 repos. Runs 12 automated setup steps and creates per-step commits for easy review.

```bash
# From release-management (use shortcuts):
/konflux-component-setup operator 0.23              # Setup operator
/konflux-component-setup submariner submariner-gateway 0.23  # Multi-component repo
/konflux-component-setup lighthouse lighthouse-agent 0.23    # Specify component

# From component repo (auto-detection):
/konflux-component-setup                            # Detect from branch
/konflux-component-setup 0.23                       # Specify version

# Use full paths:
/konflux-component-setup ~/go/src/submariner-io/subctl subctl 0.23
```

**Shortcuts:** operator, submariner, lighthouse, shipyard, subctl

**Supported components:**

- `submariner-operator` (operator repo)
- `submariner-gateway`, `submariner-globalnet`, `submariner-route-agent` (submariner repo)
- `lighthouse-agent`, `lighthouse-coredns` (lighthouse repo)
- `nettest` (shipyard repo)
- `subctl` (subctl repo)

**Requirements:**

- `/configure-downstream` must be complete (bot PR branches created)
- Previous release branch must exist (e.g., `release-0.22` when setting up 0.23)

**What it does:**

1. Checks out bot's PR branch (e.g., `konflux-submariner-operator-0-23`)
2. Runs 12 setup steps: yamllint, RPM lockfiles, Dockerfiles, hermetic builds, multi-platform, SBOM, task updates, file filters
3. Creates separate commits for each step
4. Validates YAML after each modification

**After running:** Review commits, validate YAML, push to remote, wait for build (~15-30 min)

## Installation

### .claude/settings.json

```json
{
  "extraKnownMarketplaces": {
    "submariner-release": {
      "source": {
        "source": "github",
        "repo": "stolostron/submariner-release-management",
        "ref": "main"
      }
    }
  },
  "enabledPlugins": {
    "release-management@submariner-release": true
  }
}
```

### CLI

```bash
/plugin marketplace add submariner-release https://github.com/stolostron/submariner-release-management
/plugin install release-management@submariner-release
```
