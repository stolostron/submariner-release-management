# Add Release Notes

**When:** After creating stage release (Step 8)

## Process

Add complete release notes to stage YAML. QE verifies both code and release notes together.

**Submariner ↔ ACM versions:** 0.X → 2.(X-7) (e.g., 0.20 → 2.13, 0.21 → 2.14)

**Note for patch releases:** Use base ACM version in Jira queries, not patch version:

- For 0.21.0, 0.21.1, 0.21.2 → all use `affectedVersion = "ACM 2.14.0"`
- For 0.20.0, 0.20.1, 0.20.2 → all use `affectedVersion = "ACM 2.13.0"`

### Atlassian CLI Setup (User Must Complete)

**These steps must be done by the user before Claude can query Jira:**

1. Install acli: See [installation guide](https://developer.atlassian.com/cloud/acli/guides/install-acli/)
2. Authenticate to Jira:

   ```bash
   acli jira auth login --web
   # OR with API token:
   acli jira auth login --site redhat.atlassian.net --email your@email.com --token YOUR_TOKEN
   ```

3. Verify authentication:

   ```bash
   acli jira auth status
   ```

   Should show "✓ Authenticated" to redhat.atlassian.net

**Claude: Test if setup works with:**

```bash
acli jira workitem search --jql 'project=ACM' --limit 1 --json | jq -r '.[0].key // "Setup failed"'
```

If this returns an issue key (e.g., "ACM-12345"), setup is working. If not, ask user to complete setup steps above.

### Workflow

1. **Claude queries CVEs** (Security label)
   - Extract CVE labels and components

2. **Claude queries other issues** (non-Security)
   - Sort by priority

3. **Claude checks existing YAMLs** in `releases/0.X/*/`
   - Check which issues already in this version's previous releases:

   ```bash
   grep -h "id: ACM-" releases/0.X/*/*.yaml 2>/dev/null | sed 's/.*id: //' | sort -u
   ```

   - Replace `0.X` with current major.minor version (e.g., `0.21` for 0.21.2 release)
   - If no previous releases exist (empty directory), command returns empty (no filtering needed)
   - Exclude from BOTH CVE list and other issues list
   - Rationale: Issues already fixed/noted shouldn't appear in subsequent releases

4. **Claude checks downstream release dates** at <https://catalog.redhat.com/en/software/containers/rhacm2/submariner-rhel9-operator/65bd4446f4d2cf102701785a/history>
   - For Z-stream (0.21.2): Find previous 0.21.x release date (use as timeframe start in workflow step 5)
   - For Y-stream (0.21.0): No previous 0.21.x exists, skip timeframe filtering
   - Timeframe only applies to non-CVE issues (CVEs included regardless of date)

5. **Claude presents filtered results**
   - Run Part 1 (CVEs) and Part 2 (other issues) queries
   - Exclude issues from workflow step 3 existing list
   - Show CVEs with component mapping (excluding submariner-addon)
   - Show other issues with dates, note timeframe (e.g., "Since v0.21.0 on Aug 14")

6. **Claude reviews unclear issues** in detail
   - For non-obvious issues, fetch full details:

   ```bash
   for KEY in ACM-XXXXX ACM-YYYYY; do
     acli jira workitem view "$KEY" --fields "status,summary,fixVersions,resolution" --json | \
       jq '{key: .key, status: .fields.status.name, summary: .fields.summary, fixVersions: [.fields.fixVersions[]?.name], resolution: .fields.resolution.name}'
   done
   ```

   - Check fixVersions starts with ACM series (0.21.x → "ACM 2.14", 0.20.x → "ACM 2.13")
   - Include if: status="Closed" AND resolution="Done"
   - Exclude if: status="In Progress" or "New" (not fixed yet)
   - Fetch linked bugs (e.g., DFBUGS-XXXX) for context if needed

7. **User selects** notable other issues (Blockers/Major, user-facing, fixed)

8. **Claude builds releaseNotes section**
   - Type: RHSA if CVEs present, else ask user (RHBA/RHEA)
   - issues.fixed[]: All CVE issues (except submariner-addon) + user-selected issues with source="issues.redhat.com"
   - cves[]: CVE key + mapped component from Part 1 (excluding submariner-addon)

   **Format - issues.fixed[]**: Sort by ID, add section headers to distinguish CVE vs non-CVE:

   ```yaml
   issues:
     fixed:
       # CVE Issues (N):
       - id: ACM-XXXXX
         source: issues.redhat.com
       # Non-CVE Issues (N):
       - id: ACM-YYYYY
         source: issues.redhat.com
   ```

   **Format - cves[]**: Sort by CVE key. Add verification for each CVE with Test/Output/Required. If CVE affects
   multiple components, repeat key/component entries:

   ```yaml
   cves:
     # CVE-YYYY-NNNNN (ACM-XXXXX, ACM-YYYYY): FIXED
     #   Test: command to verify fix
     #   Output: expected output showing fixed version
     #   Required: minimum version needed
     - key: CVE-YYYY-NNNNN
       component: component-a-0-X
     - key: CVE-YYYY-NNNNN
       component: component-b-0-X
   ```

9. **Claude adds releaseNotes to stage YAML**

   - Read stage YAML from releases/0.X/stage/
   - Add spec.data.releaseNotes section, show for review

10. **Claude commits stage YAML**

- Commit with release notes
- User reviews and pushes

### Part 1: CVEs (Automatic - ALL go in release)

**CVEs are what the release closes - all must be included.**

**Note:** Filter query results to exclude issues already listed in workflow step 3 (existing releases).

**Note:** Adjust versions for your release. First, find existing fixVersion values:

```bash
# Get issue keys
KEYS=$(acli jira workitem search --jql 'project=ACM AND (text ~ submariner OR text ~ lighthouse)' --paginate --json | jq -r '.[].key')

# Fetch fixVersions for each issue
echo "$KEYS" | while read -r KEY; do
  acli jira workitem view "$KEY" --fields "fixVersions" --json 2>/dev/null
done | jq -r '[.fields.fixVersions[]?.name | select(startswith("Submariner") or startswith("ACM"))] | unique | sort[]'
```

Then construct the query:

- For 0.21.x releases:
  - affectedVersion: `"ACM 2.14.0"` (always base version)
  - fixVersion IN: Include existing versions like `"Submariner 0.21.2", "ACM 2.14.0", "ACM 2.14.1"`
- For 0.20.x releases:
  - affectedVersion: `"ACM 2.13.0"`
  - fixVersion IN: Include existing versions like `"Submariner 0.20.2", "ACM 2.13.0"`

**Important:** JQL `fixVersion` field requires exact matches. Use `IN` operator with all existing patch versions.

Query for CVEs affecting this release (checks BOTH affectedVersion and fixVersion):

```bash
acli jira workitem search \
  --jql 'project=ACM AND labels in (Security) AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND (affectedVersion = "ACM 2.14.0" OR fixVersion in ("Submariner 0.21.2", "ACM 2.14.0", "ACM 2.14.1"))' \
  --fields "key,labels" --paginate --json
```

Extract CVE and component data:

```bash
acli jira workitem search \
  --jql 'project=ACM AND labels in (Security) AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND (affectedVersion = "ACM 2.14.0" OR fixVersion in ("Submariner 0.21.2", "ACM 2.14.0", "ACM 2.14.1"))' \
  --fields "key,labels" --paginate --json | jq -r '.[] | {
  issue: .key,
  cve: (.fields.labels[]? | select(startswith("CVE-"))),
  component: (.fields.labels[]? | select(startswith("pscomponent:")) | sub("pscomponent:"; ""))
}'
```

**Filter extracted results:** Exclude results where `component` is `rhacm2/submariner-addon-rhel9`. If a CVE affects both
valid components AND submariner-addon, keep the valid component entries only.

**Component name mapping:**

Version suffix format uses X.Y (major.minor), not patch version:

- For 0.21.0, 0.21.1, 0.21.2 → all use `-0-21`
- For 0.20.0, 0.20.1, 0.20.2 → all use `-0-20`

Mapping rules (replace `-0-X` with your version suffix):

- `rhacm2/lighthouse-coredns-rhel9` → `lighthouse-coredns-0-X`
- `rhacm2/lighthouse-agent-rhel9` → `lighthouse-agent-0-X`
- `lighthouse-coredns-container` → `lighthouse-coredns-0-X`
- `lighthouse-agent-container` → `lighthouse-agent-0-X`
- `rhacm2/submariner-addon-rhel9` → `submariner-addon-0-X` **(EXCLUDE - see note below)**
- `submariner-*-container` → `submariner-*-0-X`
- `rhacm2/submariner-*-rhel9` → `submariner-*-0-X`
- `nettest-container` → `nettest-0-X`
- `subctl-container` → `subctl-0-X`

**Note:** `submariner-addon` is built separately in ACM/MCE (stolostron/submariner-addon), NOT in the core Submariner operator
release. Exclude any CVEs with `pscomponent:rhacm2/submariner-addon-rhel9` from operator release notes.

**CVE issues go into:**

- `releaseNotes.issues.fixed[]` (with issue key)
- `releaseNotes.cves[]` (with CVE key and component)

### Part 2: Other Issues (Manual Selection)

**Other issues are manually managed - user picks what's release-note worthy.**

**Note:** Filter query results to exclude issues already listed in workflow step 3 (existing releases).

**Note:** Adjust versions for your release (same as Part 1):

- For 0.21.x releases:
  - affectedVersion: `"ACM 2.14.0"`
  - fixVersion IN: `"Submariner 0.21.2", "ACM 2.14.0", "ACM 2.14.1"` (adjust based on existing versions)
- For 0.20.x releases:
  - affectedVersion: `"ACM 2.13.0"`
  - fixVersion IN: `"Submariner 0.20.2", "ACM 2.13.0"` (adjust based on existing versions)

Query for non-security issues (checks BOTH affectedVersion and fixVersion):

```bash
# Get issue keys
KEYS=$(acli jira workitem search \
  --jql 'project=ACM AND (text ~ submariner OR text ~ lighthouse OR text ~ subctl OR text ~ nettest) AND (affectedVersion = "ACM 2.14.0" OR fixVersion in ("Submariner 0.21.2", "ACM 2.14.0", "ACM 2.14.1")) AND (labels is EMPTY OR labels not in (Security, SecurityTracking))' \
  --paginate --json | jq -r '.[].key')
```

**Note:** Query includes both `affectedVersion` and `fixVersion` (with IN operator for exact matches) because some
issues are only tagged with fixVersion (e.g., ACM-25262). This ensures we don't miss customer-facing issues. The
`labels is EMPTY OR` clause ensures issues with no labels (like ACM-25262) are not excluded.

Format for user review (sorted by priority, with dates):

```bash
# Fetch full details for each issue and format
echo "$KEYS" | while read -r KEY; do
  acli jira workitem view "$KEY" --fields "priority,status,created,updated,summary" --json 2>/dev/null
done | jq -s 'sort_by(.fields.priority.id // 99999) | reverse | .[] | "\(.key) [\(.fields.priority.name)] (\(.fields.status.name)) Created: \(.fields.created[:10]) Updated: \(.fields.updated[:10]): \(.fields.summary)"' -r
```

**Note:** Exclude submariner-addon issues from selection (built separately in ACM/MCE, not in operator release).

**User reviews and selects** notable issues (Blockers, Major features, etc.) to include in `releaseNotes.issues.fixed[]`

### MCP Servers (Future)

**Not currently functional** with production Jira (issues.redhat.com). Official Atlassian MCP only works with UAT (incomplete/stale data).

**Future options when available:**

- Official: `claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse`
- Alternatives: <https://github.com/redhat-community-ai-tools/jira-mcp>, <https://github.com/redhat-community-ai-tools/jira-mcp>-snowflake

**Status:** Check #forum-mcp Slack for production availability updates.

## Done When

Stage YAML with complete release notes committed and pushed. Ready for Step 10 to apply to cluster.

```bash
# Verify file pushed to remote
git ls-tree -r --name-only HEAD releases/0.X/stage/submariner-0-X-Y-stage-*.yaml
```
