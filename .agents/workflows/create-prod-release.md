# Create and Deploy Production Release

**When:** After QE approval (following Step 12)

## Process

Deploy tested code with QE-verified release notes to production.

### Workflow

1. **Read verified stage YAML**
   - Stage YAML already has verified release notes from Step 12
   - Located in `releases/0.X/stage/submariner-0-X-Y-stage-*.yaml`

2. **Create prod YAML by copying stage**
   - Change `metadata.name` (stage → prod, update date if needed)
   - Change `spec.releasePlan` (stage-0-X → prod-0-X)
   - Keep `spec.snapshot` the same (tested snapshot from stage)
   - Keep `spec.data.releaseNotes` the same (verified notes from stage)
   - Save to `releases/0.X/prod/submariner-0-X-Y-prod-*.yaml`

3. **Apply prod release**
   - `make test-remote FILE=releases/0.X/prod/...yaml`
   - `make apply FILE=releases/0.X/prod/...yaml`
   - `make watch NAME=submariner-0-X-Y-prod-...`

4. **Commit prod YAML**
   - Commit prod YAML after successful deployment
   - Documents what was released to production

## Done When

**TODO:** Add verification commands for completed prod release.
