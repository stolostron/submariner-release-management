---
name: add-fbc-ocp-version
description: Prepare a new OCP version's Submariner FBC catalogs, Konflux tenant resources, and release admissions, including major-version transitions such as OCP 5.0. Use for OCP onboarding, not ordinary bundle updates.
metadata:
  version: "2.0.0"
allowed-tools: Bash, Read, Glob
---

# Add FBC OCP Version

Run `scripts/run.sh` beside this skill with the user's arguments. Resolve its
absolute path from this skill's location; do not infer the release-management
checkout from the caller's current Git directory. Installed copies can set
`RELEASE_MANAGEMENT_REPO` to a verified checkout containing `scripts/fbc-onboard.py`.

The default phase is a read-only JSON plan. Example arguments:

```text
5.0 --min-supported-sub 0.24 --phase plan
```

`--min-supported-sub` is inclusive. The existing FBC map is a drop-through cutoff:
minimum 0.24 means `"5.0": "0.23"`. Legacy second positional arguments retain their
old cutoff meaning and print a warning. Never silently reinterpret them.

Read the [onboarding workflow](../../../.agents/workflows/add-fbc-ocp-version.md)
for preparation and readiness gates. Follow both repositories' instructions.
Use `--release-data-repo`, `--fbc-repo`, and `--workspace` for explicit checkouts.
Preparation creates resumable worktrees and leaves changes uncommitted. Preserve
existing branches, untracked files, and unrelated changes. A failed fetch is
unknown remote state; it is not proof that a branch or bot PR does not exist.

Resolve the first supported Submariner stream before catalog preparation. Work
on tooling and tenant configuration can proceed independently. Do not claim OCP
runtime support from a successful FBC image build, an ITS aggregate pass, or a
snapshot's existence. Confirm the installed bundle, completed install tasks,
and actual cluster version; the current cluster picker can fall back to 4.x.
