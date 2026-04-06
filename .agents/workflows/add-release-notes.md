# Add Release Notes

**When:** After creating stage release (Step 8)

## Process

Automated 3-phase workflow: query Jira, filter, auto-apply.

**Submariner ↔ ACM:** 0.X → 2.(X-7) (e.g., 0.20 → 2.13, 0.21 → 2.14)

### Prerequisites

```bash
# One-time setup
acli jira auth login --web
acli jira auth status  # Verify authenticated
```

### Run

```bash
make add-release-notes VERSION=0.22.1                    # Auto-find stage YAML
make add-release-notes VERSION=0.22.1 STAGE_YAML=...     # Specific YAML
```

### How it works

**Phase 1 - Collect** (`scripts/release-notes/collect.sh`):

- Queries Jira (base ACM version for all patches)
- Scans `releases/0.X/prod/*.yaml` for existing
- Z-stream: gets last publish date from registry.redhat.io
- Outputs `/tmp/release-notes-data.json`

**Phase 2 - Filter** (`scripts/release-notes/prepare.sh`):

- Excludes published, invalid resolutions; keeps Unresolved (Jira may be stale)
- Z-stream: also excludes by date
- Groups CVEs, categorizes non-CVEs, recommends type
- Outputs `/tmp/release-notes-topics.json`

**Phase 3 - Auto-apply** (`scripts/release-notes/auto-apply.sh`):

- Auto-applies ALL filtered issues
- Validates, commits

### After running

```bash
git show              # Review
git commit --amend    # Remove irrelevant
git push
```

### Component mapping

CVE `pscomponent:` labels → Konflux component names:

- `rhacm2/lighthouse-coredns-rhel9` → `lighthouse-coredns-0-X`
- `rhacm2/submariner-gateway-rhel9` → `submariner-gateway-0-X`
- `rhacm2/submariner-addon-rhel9` → **EXCLUDED** (built separately in ACM/MCE)

See `map_component_name()` in `scripts/lib/release-notes-common.sh` for full mapping.

## Done When

Stage YAML committed with release notes.

```bash
git log --oneline -1 | grep "release notes"
```
