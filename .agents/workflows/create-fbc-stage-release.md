# Create FBC stage releases

Run the verified release helper from this repository:

```bash
make create-fbc-releases VERSION=0.24.1
# Initial onboarding can select a complete OCP version explicitly:
make create-fbc-releases VERSION=0.24.1 OCP=5.0
```

Without `OCP`, scope comes from `FBC_OCP_VERSIONS` in `scripts/lib/fbc-scope.sh`.
A new major version remains outside that active list until onboarding readiness
is established. For onboarding, set `FBC_EXPECTED_COMMIT` to the expected merged
FBC commit before invoking the command.

The helper checks bundle identity against the catalog, snapshot images, and
component SHAs; requires both configured test scenarios to complete successfully;
and fails when an applicable active catalog lacks a snapshot. Pending, malformed,
or missing test status blocks release. A missing bundle is distinct from an
unreachable registry or GitHub fetch error.

Generated filenames include both the full OCP ID and full Submariner version,
for example `submariner-fbc-5-0-0-24-1-stage-YYYYMMDD-01.yaml`. The command validates
and commits the resulting YAMLs, then prints push/apply commands. Review exact
files and snapshot identities before release. An FBC build/test pass does not
prove operator compatibility on the requested OCP major; see
[onboarding evidence](add-fbc-ocp-version.md).
