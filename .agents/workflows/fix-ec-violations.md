# Update Tekton Tasks and Resolve EC Violations

**When:** Y-stream (0.20 → 0.21) and Z-stream (0.20.1 → 0.20.2). Components mostly handled in step 3 for Y-stream, FBC needs checking for both.

## Process

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

## Done When

- Component builds pass Enterprise Contract validation (requires `oc login --web https://api.kflux-prd-rh02.0fk9.p1.openshiftapps.com:6443/`):

  ```bash
  oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "^submariner-0" | tail -5
  # Pick recent component snapshot, then check EC test status:
  oc get snapshot <snapshot-name> -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq '.[] | select(.scenario | contains("enterprise-contract")) | {scenario, status}'
  # Should show: "status": "TestPassed" for enterprise-contract scenario
  ```

- FBC builds pass validation tests:

  ```bash
  oc get snapshots -n submariner-tenant --sort-by=.metadata.creationTimestamp | grep "^submariner-fbc" | tail -5
  # Pick recent FBC snapshot, then check test status:
  oc get snapshot <snapshot-name> -n submariner-tenant -o jsonpath='{.metadata.annotations.test\.appstudio\.openshift\.io/status}' | jq '.[] | {scenario, status}'
  # Should show: "status": "TestPassed" for standard and operator scenarios
  ```
