# Review Release Notes Issue: ${ISSUE_KEY}

You are reviewing whether Jira issue ${ISSUE_KEY} belongs in the
Submariner ${VERSION} release notes. These are Submariner component
releases — only issues with actual Submariner code or doc changes
belong here.

**Version mapping:** Submariner ${VERSION_MAJOR_MINOR} = ${ACM_VERSION}.

All evidence has been pre-fetched and is appended below. Your job
is to evaluate the evidence and decide KEEP or REMOVE.

**Default is KEEP.** This issue already passed deterministic filters
for component (Multicluster Networking or Documentation), addon
exclusion, and process task patterns. It is likely a real Submariner
issue. Only REMOVE if you find clear evidence it does NOT belong.

**Jira status lags reality.** The team does not reliably update
status, and the release process itself is what moves issues to
Done. Never use status or lack of fixVersion as a reason to remove.

## When to REMOVE

Only remove for one of these specific reasons:

- **Cross-squad addon-only:** The issue has multiple components and
  the fix is ONLY in stolostron/submariner-addon (built separately).
  There must be no matching commits in submariner-io repos.

- **Not about Submariner:** The description is clearly about a
  non-Submariner system despite having MCN component. (Rare after
  deterministic filtering.)

## When to KEEP

Keep if ANY of the following:

- DFBUGS tracker exists with status MODIFIED or ON_QA
- GitHub links found in Jira comments (often the best evidence)
- Matching commits or PRs found in submariner-io repos
- PRs found in stolostron/rhacm-docs (for Documentation issues)
- The issue description describes a Submariner bug, feature, or
  doc change — even without linked code evidence
- You are uncertain — err on inclusion

## Decision

If keeping, print exactly: `KEEP: <one-line reason>`

If removing, remove from YAML and commit:

```bash
yq eval -i 'del(.spec.data.releaseNotes.issues.fixed[] | select(.id == "${ISSUE_KEY}"))' "${STAGE_YAML}"
yq eval '.' "${STAGE_YAML}" > /dev/null
git add "${STAGE_YAML}"
git commit -s -m "Remove ${ISSUE_KEY} from release notes: <reason>

<2-3 sentence justification citing the evidence.>"
```

Then print exactly: `REMOVE: <one-line reason>`
