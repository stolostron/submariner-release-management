# Submariner Release Management

Submariner release orchestration via Konflux.

## Usage

```bash
# Login to cluster
oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/

# Show available commands
make

# Validate locally (no cluster access needed)
make test

# Validate with cluster checks (requires cluster login)
make test-remote

# Apply release (requires cluster login)
make apply FILE=releases/0.20/stage/submariner-0-20-2-stage-20250930-01.yaml

# Watch release (requires cluster login)
make watch NAME=submariner-0-20-2-stage-20250930-01
```

## Claude Skills

```bash
/plugin marketplace add submariner-release https://github.com/stolostron/submariner-release-management
/plugin install release-management@submariner-release
```

| Command                  | Purpose                                   |
|--------------------------|-------------------------------------------|
| `/learn-release`         | Learn 20-step release workflow            |
| `/release-ls`            | Check release status                      |
| `/configure-downstream`  | Create Konflux app for new version        |

See [.claude/SKILLS.md](.claude/SKILLS.md).
