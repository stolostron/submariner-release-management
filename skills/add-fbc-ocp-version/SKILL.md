---
name: add-fbc-ocp-version
description: Prepare a new OCP version's Submariner FBC catalogs, Konflux tenant resources, and release admissions, including major-version transitions such as OCP 5.0. Use for OCP onboarding, not ordinary bundle updates.
metadata:
  version: "3.0.0"
allowed-tools: Bash, Read, Glob
---

# Add FBC OCP Version

Resolve `scripts/run.sh` from this skill's absolute location, independently of cwd.
For an installed copy, set `RELEASE_MANAGEMENT_REPO` to the backing checkout.
Run the wrapper with **`--workflow` and read the returned file** for the canonical
procedure. Both executable and documentation resolve from that verified checkout.

Match the user's requested milestone:

- **Plan/explore:** run the read-only default phase and report missing inputs.
- **Add:** inspect the plan, then run `--phase prepare` and `--phase test-image`.
  Preparation creates all three change sets and verifies them. Continue through
  repository checks and authorized commits; printing a plan does not complete an
  add request. Follow the workflow for review, reconciliation and live evidence.
- **Resume:** reuse the same workspace and immutable source refs. Inspect its
  changes, rerun preparation/verification, and continue from the unmet milestone.
  A changed source base needs an explicit reviewed rebase or a fresh workspace.

Example inputs (0.24 is illustrative, not a product-policy decision):

```text
5.0 --min-supported-sub 0.24 --phase plan
```

`--min-supported-sub` is inclusive. The existing FBC map is a drop-through cutoff:
minimum 0.24 means `"5.0": "0.23"`. Legacy second positional arguments retain their
old cutoff meaning and print a warning. Never silently reinterpret them.

Use `--release-data-repo`, `--fbc-repo`, `--workspace`, and independent
`--release-data-ref`/`--fbc-ref` pins. Follow both repositories' instructions.
Preparation leaves changes uncommitted; preserve the user's commit authorization.
Preserve
existing branches, untracked files, and unrelated changes. A failed fetch is
unknown remote state; it is not proof that a branch or bot PR does not exist.

Resolve the approved minimum stream before catalog preparation. While it is
pending, use `--phase prepare-config`; it needs only release-data. Catalog
preparation needs only FBC. Select a compatible `--kustomize` when necessary.
Do not claim OCP
runtime support from a successful FBC image build, an ITS aggregate pass, or a
snapshot's existence. Confirm the installed bundle, completed install tasks,
and actual cluster version; the current cluster picker can fall back to 4.x.
