# Update Tekton Tasks and Resolve EC Violations

**When:** Y-stream (0.20 → 0.21) and Z-stream (0.20.1 → 0.20.2). Components mostly handled in step 3 for Y-stream, FBC needs checking for both.

Ensure all Konflux builds pass Enterprise Contract validation before cutting releases.

**Component repos** (all in <https://github.com/submariner-io>):

- `submariner-operator` (2): submariner-operator, submariner-bundle
- `submariner` (3): submariner-gateway, submariner-globalnet, submariner-route-agent
- `lighthouse` (2): lighthouse-agent, lighthouse-coredns
- `shipyard` (1): nettest
- `subctl` (1): subctl

**Local:** `~/go/src/submariner-io/`

**FBC repo:** <https://github.com/stolostron/submariner-operator-fbc>
**Local:** `~/konflux/submariner-operator-fbc`

**Workflow:** `~/go/src/submariner-io/submariner-operator/.agents/workflows/konflux-ci-fix.md` (on `kf_claud` branch) for components

**TODO:** Add similar workflows to other component repos.

**TODO:** Add FBC EC violation fixing workflow.
