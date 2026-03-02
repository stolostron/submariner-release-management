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
