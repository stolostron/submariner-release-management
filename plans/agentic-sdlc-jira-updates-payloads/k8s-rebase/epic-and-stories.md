<!-- markdownlint-disable MD013 -->

# Exact payloads: epic description and five child stories for CORENET-7155

Nothing here has been created or edited in Jira. Jira and GitHub facts were rechecked on 2026-10-07. Development counts describe the committed
bak42 snapshot (`febb7974696e870f933e8ad3741605d31ead0b5c`), rather than today's mutable working tree.
Text blocks are Markdown for a converting client/UI; direct Jira Cloud REST writes need ADF. Read current create-field and transition metadata before writing.

Conventions verified against CORENET Story create metadata and existing Story edit/transition metadata on October 7:

* Project `CORENET` (id `10389`), issue type Story (id `10009`), epic membership `CORENET-7155` via `parent`. Current CORENET Story create metadata does not expose legacy Epic Link (`customfield_10014`). Reporter is required with a default; verify the approved reporter on read-back.
* Assignee: the maintainer's own Jira account, resolved through the authenticated client. Priority Normal (id `10003`), as on CORENET-7155 and the closed sibling CORENET-7062.
* Activity Type is `customfield_10464`. The epic and CORENET-7062 use `Product / Portfolio Work` (option id `10610`); `Quality / Stability / Reliability` is option id `10608`.
* CORENET automation warns about missing **original story points** before In Progress/Code Review and a missing **sprint** before In Progress/Code Review/Closed
  (comments read on CORENET-7062). Story Points (`customfield_10028`) is writable at creation. Original story points (`customfield_10977`) is absent from create metadata but writable in existing Story edit metadata: set it after creation only when the new canary confirms edit support. CORENET-7062 has 1 in both;
  Sprint is `customfield_10020`. The epic is in the active sprint "CORENET Sprint 295" (id `87581`, board `9839`, ends 2026-10-19).
* The story-point values below are **placeholders for the maintainer to choose**; I do not know the team's scale. Confirm the chosen values against the team's scale and current field constraints before creating any story.
* Git Pull Request is `customfield_10875`; it is absent from CORENET create metadata but writable in existing Story edit metadata. Set it after the new Story confirms edit support, or preserve the URL in its restricted comment. The epic already holds an ADF URL; its edit metadata does not expose this field, and no epic PR-field edit is proposed. Markdown links need conversion before direct REST use.
* Description format: markdown with `_Scope:_` and `_Acceptance criteria:_` italic headings, as used on sibling stories.
* Comments use visibility `{"type": "group", "value": "Red Hat Employee"}`.

Verified facts used below (full method in Part B, section B8 of the plan):

* Plugin in openshift-eng/ai-helpers: 134 tracked files, about 20.8k lines, at `plugins/k8s-rebase`. README: a state machine above the agent, scripts do repeatable work, 32
  verification gates decide when a step may advance; five steps plus rules; 13 scripts (including the eval runner); hooks; four docs (design, compatibility, patterns, Kubernetes 1.37); 238 test functions
  in about 5.0k lines of tests; 16 evaluation cases (pattern-retention) and an eval README.
* 43 local backup branches of the work (`k8s-rebase-skill-bak0` on 2026-05-31 through `bak42` on 2026-09-25); 29 of them are on the maintainer's fork, including bak41 and bak42.
* PR openshift-eng/ai-helpers#617: opened 2026-07-13, draft, 127 files, +15,774/-17, one squashed commit (head 7e1aa060, the bak41 state), 175 reviews (85 by CodeRabbit,
  83 by the author, 7 by a teammate), labels `do-not-merge/work-in-progress`, `do-not-merge/invalid-owners-file`, `needs-ok-to-test`.
* From the PR head to bak42: 69 commits between 2026-09-22 and 2026-09-25 (10, 35, 23 and 1 per day), 90 files, +7,799/-2,641, backed up on the fork but not on the PR.
  The October 7 local HEAD is at `a477bced`, 82 commits beyond the PR head and 13 beyond bak42; those 13 need their own backup and qualification evidence. Two test files also have uncommitted court-permission changes, separate from that HEAD and its evidence.
* Qualification runs: 6 Kubernetes 1.36.2 PRs on 2026-06-09/10 (1 merged: ovn-kubernetes-mcp#57; 5 closed) and 108 draft PRs from the maintainer's fork against upstream
  repos on 2026-07-16 to 2026-07-23 (all closed): cloud-network-config-controller 26, ingress-node-firewall 23, multus-cni 22, ovn-kubernetes-mcp 22, cluster-network-operator 15.

## Epic CORENET-7155: add a description (it is currently empty)

Field to set: `description` (ADF, converted from the Markdown below). Nothing else on the epic needs to change.

```text
Bumping the Kubernetes minor version across the CoreNet Go repositories is repetitive and error-prone: align dependencies across modules, regenerate code, update version references, and fix build, lint and test breakage. This epic builds agents that automate the bump, packaged as the k8s-rebase plugin for the openshift-eng/ai-helpers marketplace (Claude Code and Codex).

The design is a state machine above the agent: scripts do the repeatable work, the agent repairs breakage, and 32 verification gates are designed to require retained evidence before a step advances. Enforcement and installed-runtime qualification remain acceptance work.

_Scope:_

* The k8s-rebase plugin: a five-step workflow (rebase, compilation, autofix, verification, PR) with gates, scripts, hooks and design docs
* Qualification against real Kubernetes 1.36.2 rebases of CoreNet repositories
* Evaluations that measure the workflow, including run cost and model
* Preparing and validating the next minor (Kubernetes 1.37)
* Upstreaming the plugin to openshift-eng/ai-helpers

_Acceptance criteria:_

* The plugin performs a complete Kubernetes minor rebase of a CoreNet repository end to end, with the gates enforcing each step
* The plugin is qualified on the 1.36.2 rebases and prepared for 1.37
* Evaluations with cost and model data exist and are documented
* The plugin is merged in openshift-eng/ai-helpers
```

## Story K1: Build the k8s-rebase plugin

* Summary: `Build the k8s-rebase plugin: a gated state machine for Kubernetes rebases`
* Activity Type: Product / Portfolio Work (`10610`); Priority Normal; story points: placeholder (maintainer to choose)
* Target status: In Progress, after points and sprint are set; discover the issue's available transition.
* Git Pull Request: `[https://github.com/openshift-eng/ai-helpers/pull/617](https://github.com/openshift-eng/ai-helpers/pull/617)`

```text
Build the plugin that automates a Kubernetes minor-version rebase of a Go project: align dependencies across modules, regenerate code, update version references, and fix build, lint and test breakage. A state machine owns progress; scripts do the repeatable work, the agent repairs, and verification gates decide when a step may advance. The design guide explains how this structure resists an agent claiming success it has not earned.

_Scope:_

* Five-step workflow (rebase, compilation, autofix, verification, PR) with shared rules
* 32 verification gates with explicit verdict rules: a gate that did not run is never passed or skipped
* Scripts for the repeatable work, and hooks
* Docs: design guide, runtime compatibility, repair patterns, Kubernetes 1.37 notes
* Unit and integration tests for the tooling (238 test functions at the dated bak42 baseline; current source is newer)

_Acceptance criteria:_

* A complete rebase of a CoreNet repository runs end to end with every gate enforced
* Verification evidence is retained and a run cannot pass with missing evidence
* Tests pass in CI
```

Progress comment (post after creation):

```text
Current source implements the five-step workflow, verification gates, hooks, repair guidance and retained-evidence contracts. Upstream https://github.com/openshift-eng/ai-helpers/pull/617 remains at 7e1aa060; local HEAD a477bced has 82 newer commits, including 13 beyond verified bak42. Two test files also contain uncommitted court-permission changes.

Preserve and review the complete intended source before publishing it. Current installed-runtime and CI acceptance are not established by the older PR or dated test-function counts. K2 owns historical 1.36.2 evidence, K3 measurements and K4 the newer trial limits; no plugin test or trial was run by this planning audit.
```

## Story K2: Qualify k8s-rebase on the 1.36.2 rebases

* Summary: `Qualify k8s-rebase on the Kubernetes 1.36.2 rebases of CoreNet repositories`
* Activity Type: Product / Portfolio Work (`10610`); Priority Normal; story points: placeholder
* Link: `Related` to CORENET-7062 (the closed story for the ovn-kubernetes-mcp bump, which the agent's merged PR completed)
* Target status: In Progress pending evidence/acceptance review; set points and sprint first. PR counts and legacy PASS rows do not establish both criteria below.
* Git Pull Request: `[https://github.com/ovn-kubernetes/ovn-kubernetes-mcp/pull/57](https://github.com/ovn-kubernetes/ovn-kubernetes-mcp/pull/57)`

```text
Run the plugin against real Kubernetes 1.36.2 rebases of CoreNet repositories to find where it breaks and to qualify the workflow.

_Scope:_

* First runs against ovn-kubernetes, ovn-kubernetes-mcp, multus-cni, cluster-network-operator, cloud-network-config-controller and ingress-node-firewall; preserve the separate repository-delivery scope under CORENET-6983
* A larger batch of qualification runs, opened as draft PRs from a fork and closed afterwards, across five repositories
* Feed the findings back into the gates, repair patterns and docs

_Acceptance criteria:_

* The agent produces a rebase branch and PR for each target repository
* Failures found during the runs are fixed in the plugin or documented as known limits
```

Progress comment (post after creation):

```text
Runs to date:

* 2026-06-09 and 2026-06-10: six Kubernetes 1.36.2 rebase PRs (ovn-kubernetes, ovn-kubernetes-mcp, multus-cni, cluster-network-operator, cloud-network-config-controller, ingress-node-firewall). https://github.com/ovn-kubernetes/ovn-kubernetes-mcp/pull/57 merged; the other five were closed.
* 2026-07-16 to 2026-07-23: 108 draft PRs opened from the maintainer's fork and then closed: cloud-network-config-controller 26, ingress-node-firewall 23, multus-cni 22, ovn-kubernetes-mcp 22, cluster-network-operator 15. This counts PRs, not independently accepted runs.
* Local legacy matrix records contain 536 rows dated July 29–September 24, including 218 for 1.36.2 and latest unmutated PASS rows for all six targets. The inspected matrix-state has no evidence archive and only one run-input record; those PASS summaries are not requalified by the current harness. Recover per-target source/result, gates and failure dispositions before accepting this story. Missing evidence needs an explicit limited-acceptance decision or fresh qualification; no rerun was performed here.
```

## Story K3: Evals and cost/model measurement

* Summary: `Add evaluations and cost and model measurement for k8s-rebase`
* Activity Type: Quality / Stability / Reliability (`10608`); Priority Normal; story points: placeholder
* Target status: In Progress, using the issue's available transition after points and sprint are set.

```text
A reviewer on the pull request asked whether the plugin has any eval, cost estimation or specific model measurement, and noted that other plugins in the marketplace use a shared eval harness. The plugin has an evaluation guide, a set of cases and test harness isolation for eval runs; this story makes the measurements explicit and decides how they relate to the marketplace harness.

_Scope:_

* Document how to run the evals, and record run duration, cost and model with each result
* Keep the evals isolated and retain evidence from interrupted runs
* Decide whether to adopt the marketplace's shared eval harness or document why the plugin's own is used, and answer the reviewer on the PR

_Acceptance criteria:_

* The eval procedure is documented and reproducible, with duration, cost and model recorded per run
* The question on the pull request is answered with data
```

Progress comment (post after creation):

```text
Current source has 16 pattern-retention cases, isolated plugin snapshots, exact input/result metadata and a runner that captures model, tokens, turns and cost. The guide gives observed estimates of $17–27 for light cases and $40–60 for heavy cases; these are documented estimates, not a fresh benchmark. The runner collects artifacts but does not execute the YAML judges, and its missing-result fallback writes zero-valued metrics. Exclude fallback metrics from measurements rather than treating them as free successful runs.

Remaining: retain valid per-run measurements and judge outcomes with source/model/version attribution, distinguish workflow completion from diff review, decide the shared-harness approach, and answer the reviewer with that data. No model run or paid eval was launched by this audit.
```

## Story K4: Kubernetes 1.37

* Summary: `Prepare and validate Kubernetes 1.37 rebases in k8s-rebase`
* Activity Type: Product / Portfolio Work (`10610`); Priority Normal; story points: placeholder
* Target status: In Progress, using the issue's available transition after points and sprint are set.

```text
The next Kubernetes minor changes APIs and tooling the plugin relies on. Prepare the plugin for 1.37 and validate it against the published 1.37 patch release.

_Scope:_

* 1.37 preparation and validation in the plugin, with notes in docs/k8s-1.37.md
* Tests that target the published 1.37.1 patch; plugin qualification is separate from the repository-delivery bumps already tracked under CORENET-7450
* A real 1.37 rebase of at least one CoreNet repository

_Acceptance criteria:_

* The plugin is validated for 1.37 by its tests
* A 1.37 rebase of a CoreNet repository completes end to end with the gates enforced
```

Progress comment (post after creation):

```text
October 7 source refresh: the plugin HEAD is at a477bced687c3385311bafddbf2ae1a3b0228ed0, 82 commits after the upstream PR and 13 after bak42. Its docs/k8s-1.37.md records CNCC, Multus and initial MCP Kubernetes 1.37.1 workflow candidates, superseding the September assertion that no real rebase exists.

CNCC has historical independent host evidence but requires fresh qualification after correcting unsupported JSON-pin attribution. Multus candidate f5b4591085fb66dc62cd43140f24ee8e01d6cdb1 has recorded frozen-source evidence: 28 PASS, two SKIP, two INCONCLUSIVE. Dependency-history and hosted-coverage limits and an unchanged reachable gRPC finding remain disclosed. This is recorded source evidence, not a qualification rerun by this planning audit.

MCP candidate 8cfc303b77f7f65232e8a726c3048376e9b23d88 used source 80a1c318 from baseline 858f54cf. Its independent execution/reporting audit accepts limits: 24 PASS, three SKIP, three FAIL and two INCONCLUSIVE gates. Unit tests report 17 fresh packages, 62 top-level and 589 subtest passes separately; offline E2E passes 58 selected specs with 76 excluded. Lint did not complete after three retained attempts; dependency-history/security coverage remains incomplete and live CI selects Kubernetes 1.36.4. Preserve the separate maintainer FAIL for byte-identical upstream vendor suppression under the frozen rubric.

The a477bced source applies MCP lessons and two test files have further uncommitted court-permission changes; neither is a fresh qualification result. Freeze the intended source and compare loaded skill/hook bytes before a separate fresh MCP run; preserve the original budgets/reports. CNCC requalification and other repositories remain deferred while MCP is corrected and qualified. Keep this story In Progress until agreed criteria pass; do not claim clean vulnerability, installed-host, image or external-CI coverage.
```

## Story K5: Upstream the plugin

* Summary: `Upstream k8s-rebase into openshift-eng/ai-helpers`
* Activity Type: Product / Portfolio Work (`10610`); Priority Normal; story points: placeholder
* Target status: In Progress, using the issue's available transition after points and sprint are set.
* Git Pull Request: `[https://github.com/openshift-eng/ai-helpers/pull/617](https://github.com/openshift-eng/ai-helpers/pull/617)`

```text
Get the plugin merged into the openshift-eng/ai-helpers marketplace.

_Scope:_

* Update the pull request to the reviewed branch state (bak42 alone adds 69 commits after the PR head; newer local work must be reviewed separately)
* Resolve the automation blockers on the PR: the invalid OWNERS file (reported nonmembers; repair it according to repository requirements and re-run /verify-owners), needs-ok-to-test, and approvals from the file owners
* Answer reviewer questions, including the eval and cost question (see the evals story)
* Take the PR out of draft when ready

_Acceptance criteria:_

* The pull request is merged
```

Progress comment (post after creation):

```text
https://github.com/openshift-eng/ai-helpers/pull/617 remains draft at 7e1aa060 with WIP, invalid-OWNERS and needs-ok-to-test labels at the October 7 read. Automation previously reported nonmembers in OWNERS; confirm and repair the current repository requirements before asking for verification/approval. The reviewer's eval/cost/shared-harness question remains K3 work. Review and qualify all intended local changes before an authorized PR refresh; merge remains this story's acceptance criterion.
```
