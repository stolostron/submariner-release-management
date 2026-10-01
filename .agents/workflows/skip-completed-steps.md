# Skip Already-Completed Steps

**When:** Re-releases, retargets (e.g. 0.23.2 → 0.23.4), retrying a failed stage or prod release, or resuming a release after the
upstream tag already exists. Applies to Y-stream and Z-stream.

Do not redo upstream work that is already done. These rules are maintainer decisions (see "Settled Decisions" in `CLAUDE.md`).

## The rules

| Step | Skip when | Why |
| ---- | --------- | --- |
| 6. Upstream release | `v$VERSION` exists on all 5 component repos | The tag is permanent. Never re-cut or move it. |
| 5. CVE fixes | The CVE pass was done before the upstream tag was cut | CVE fixes land before the tag; later changes cannot affect it. |
| 4. Tekton tasks | Enterprise Contract already passes on the latest snapshot | Task bumps only fix EC violations; none to fix. |
| 5b. Version labels | Labels already match `$VERSION` (release-ls shows them correct) | Nothing to change. |

Consequences:

- **Do not re-run the CVE scan or CVE fix workflow** for a retarget, re-release, or retry. A new upstream version needs its own pass
  before its own tag; a version whose tag already exists does not.
- **Do not proactively bump Tekton tasks** or merge Konflux bot task-update PRs "to be safe". Fix EC only when EC fails.
- **EC is the signal.** `TestPassed` and `BuildPLRInProgress` both count as passing (the latter is a normal, final status on push
  snapshots). If EC fails, do the Tekton task work (`/konflux-ci-fix`), then continue.
- RPM lockfile updates are separate from these rules and unchanged.

## How to tell `/autorelease` and `release-ls`

The conductor still walks every step. Mark the ones you are skipping so it advances:

```bash
/autorelease 0.X.Y --dry-run                    # see what it thinks is next
/autorelease 0.X.Y --complete cveFixes          # CVE fixes were done before the tag
/autorelease 0.X.Y --complete tektonTasks       # EC passes, no task updates needed
```

How the conductor decides each step is done:

- `upstreamRelease` verifies the tags itself and completes when `v$VERSION` exists on all 5 repos. It runs only after its
  dependencies (`cveFixes`, `ecFixes`, `rpmLockfiles`, `tektonTasks`, `versionLabels`) are complete, so mark skipped ones first.
- `ecFixes` verifies EC on the latest snapshot and completes when it passes.
- `cveFixes` and `tektonTasks` complete on their own only if the verifier finds earlier merged fix PRs (`fix-X.Y-cves*`,
  `fix-tekton-tasks-X.Y`). With open PRs it waits. With none found it concludes the work was never done and **runs the script**.
  When the work is deliberately skipped there is nothing to find, so use `--complete` for these two.

Do **not** use `--refresh cveFixes` or `--refresh tektonTasks` on a release whose upstream tag already exists.

### Expected noise

- `release-ls` prints `Stale steps: CVE fixes` once `cveFixes` completed more than 3 days ago. That warning is advisory. After the
  upstream tag exists, ignore it.
- `release-ls` Step 5 says CVE scanning needs manual review. That applies only to a version that has not been tagged yet.
- After a retarget, old STEP_DATA from the previous version may still read `complete`. Check the tag, EC and labels directly (release-ls
  does) rather than trusting old tracker entries.

## Checklist before skipping

Verify, do not assume:

```bash
# Upstream tag exists on all 5 component repos
for repo in submariner-operator submariner lighthouse shipyard subctl; do
  git ls-remote --tags https://github.com/submariner-io/$repo refs/tags/v0.X.Y | grep -q refs/tags && echo "$repo ok" || echo "$repo MISSING"
done

# EC passes on the latest push snapshot (TestPassed or BuildPLRInProgress)
scripts/release-status.sh 0.X.Y | sed -n '/Step 4/,/Step 5\]/p'
```

If a tag is missing on any repo, this page does not apply: finish the upstream release first (`cut-upstream-release.md`).

## Example: retarget 0.23.2 → 0.23.4 (2026-09)

0.23.2 failed QE and was never shipped to prod. Upstream v0.23.4 was already tagged on all repos, CVE fixes had been done before
tagging, and EC was passing. The CVE scan, Tekton task updates and upstream tag were not repeated; the release continued from the
bundle SHAs step to the stage release.
