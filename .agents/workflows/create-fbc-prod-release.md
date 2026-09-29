# Create FBC production releases

After QE approves the staged artifacts:

```bash
make create-fbc-releases VERSION=0.24.1 TYPE=prod
# A scoped initial release:
make create-fbc-releases VERSION=0.24.1 TYPE=prod OCP=5.0
```

The helper reads the exact Submariner version's stage YAMLs across full OCP IDs
and reuses their snapshot names. It must not select a newer snapshot built after
QE validation. Review the stage records when several attempts exist; the helper
selects the latest version-matched stage record per OCP version.

It validates and commits the production YAMLs and prints push/apply commands.
Follow [release checking](check-fbc-releases.md) for those exact Release names.
Only share public index URLs after bundle membership is confirmed with
`make get-fbc-urls VERSION=0.24.1 PROD_INDEX=true` (optionally `OCP=5.0`).
