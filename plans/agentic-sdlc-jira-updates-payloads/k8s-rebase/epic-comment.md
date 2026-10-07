<!-- markdownlint-disable MD013 -->

# Exact payload: summary comment for CORENET-7155

Nothing has been posted. Visibility `{"type": "group", "value": "Red Hat Employee"}`. Post after the five stories exist and replace `<K1>` to `<K5>` with their keys.

The epic's existing comments end on 2026-06-12. This one brings it up to date.

```text
October 7 update: work since the June comments is split into <K1> plugin, <K2> 1.36.2 qualification, <K3> evals/measurement, <K4> Kubernetes 1.37 and <K5> upstreaming.

* https://github.com/openshift-eng/ai-helpers/pull/617 remains a draft at 7e1aa060. Current local HEAD a477bced includes 82 newer commits, plus two uncommitted test-file changes; preserve/qualify that source before a PR refresh. Bak42 is a verified older backup, not a backup of the complete current work.
* Six June rebase PRs and 108 closed July draft PRs record exercised workflows. Legacy matrix PASS summaries do not provide the current per-run evidence archive; K2 remains pending acceptance review.
* CNCC/Multus/MCP 1.37.1 trials exist with limits and failed/inconclusive gates. The newest lessons and test changes need fresh qualification; no trial was rerun by this audit.
* Eval metrics and sixteen cases exist; valid measurements/judge results, the reviewer's cost/shared-harness question, OWNERS/ok-to-test gates and final upstream merge remain.
```
