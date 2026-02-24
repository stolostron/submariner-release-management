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
