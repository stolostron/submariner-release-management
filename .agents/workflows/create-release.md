# Create Downstream Stage Release

Create basic ReleasePlanAdmission YAML for stage release (without release notes).

**Repo:** <https://github.com/dfarrell07/submariner-release-management> (this repo)
**Local:** `~/konflux/submariner-release-management`

---

**Stage:** After bundle SHAs updated (Step 7) → `releases/0.X/stage/`

**Note:** Release notes added to stage in Step 12, then prod created in Step 13

---

## Finding Snapshots

```bash
oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp
oc get snapshot <name> -n submariner-tenant \
  -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' \
  | jq
```

Look for snapshots where all tests show `"status": "TestPassed"`.

## Creating Release YAML

1. Copy existing stage YAML
2. Update `metadata.name` and `spec.snapshot`
3. Remove `spec.data.releaseNotes` section if present (from copied YAML)
4. `make test-remote` then `make apply FILE=...`
5. `make watch NAME=...`

## Requirements

- Advisory types: RHSA (security, must have ≥1 CVE), RHBA (bug fix), RHEA (enhancement)
- Component names must have version suffix: `lighthouse-coredns-0-20`
- Issue IDs:
  - Jira: `PROJECT-12345` (source: `issues.redhat.com`)
  - Bugzilla: `1234567` (source: `bugzilla.redhat.com`)

## Validation

Releases: `make test` | `make test-remote` (requires cluster)

Markdown: `npx markdownlint-cli2 "**/*.md"`
