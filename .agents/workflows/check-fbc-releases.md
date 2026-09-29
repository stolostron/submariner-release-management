# Check FBC releases

Check the exact Release objects recorded for this Submariner version. Do not
select by a broad OCP prefix, which can return a different Submariner release.

```bash
VERSION=0.24.1
ENV=stage
DASH=${VERSION//./-}
for YAML in releases/fbc/*-*/"$ENV"/submariner-fbc-*-"$DASH"-"$ENV"-*.yaml; do
  [ -f "$YAML" ] || continue
  NAME=$(yq -r '.metadata.name' "$YAML")
  oc get release "$NAME" -n submariner-tenant \
    -o jsonpath='{.metadata.name}{": "}{.status.conditions[?(@.type=="Released")]}{"\n"}'
done
```

Each requested Release must have `Released=True` and `reason=Succeeded`.
Investigate missing, pending, or failed releases. Use `make watch NAME=...` for
the exact release. Historical files without a Submariner version need explicit
identification by their component release date; do not mix them into a modern
release merely because their OCP version matches.
