# Update FBC with Prod Release

**When:** Y-stream (0.20 → 0.21) and Z-stream (0.20.1 → 0.20.2), after prod release completes

## Process

Add bundle to File-Based Catalog.

**Repo:** <https://github.com/stolostron/submariner-operator-fbc>
**Local:** `~/konflux/submariner-operator-fbc`

**Workflow:** README.md in that repo (`make add-bundle`)

**TODO:** `make add-bundle` doesn't work - templates edited manually.

**TODO:** Add `.agents/workflows/update-catalog.md` to FBC repo with actual workflow.

## Done When

**TODO:** Add verification commands for updated FBC catalog.
