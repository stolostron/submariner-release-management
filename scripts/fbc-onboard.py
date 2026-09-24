#!/usr/bin/env python3
"""Prepare and inspect FBC onboarding without changing a caller's checkout."""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

TENANT = Path("tenants-config/cluster/kflux-prd-rh02/tenants/submariner-tenant")
OVERLAYS = TENANT / "overlay/application-submariner-fbc"
RPA = Path("config/kflux-prd-rh02.0fk9.p1/product/ReleasePlanAdmission/submariner")
GENERATED = Path(
    "tenants-config/auto-generated/cluster/kflux-prd-rh02/tenants/submariner-tenant"
)
PLATFORMS = ["linux/x86_64", "linux/arm64", "linux/ppc64le", "linux/s390x"]


def run(*args, cwd=None, capture=True, env=None):
    return subprocess.run(
        args,
        cwd=cwd,
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else sys.stderr,
    ).stdout


def ocp(value):
    if not re.fullmatch(r"[1-9][0-9]*[.-](?:0|[1-9][0-9]*)", value):
        raise argparse.ArgumentTypeError("OCP must be major.minor or major-minor")
    return value.replace(".", "-")


def stream(value):
    if not re.fullmatch(r"0\.(?:0|[1-9][0-9]*)", value):
        raise argparse.ArgumentTypeError("Submariner stream must be 0.Y")
    return value


def load(path):
    return yaml.safe_load(path.read_text())


def save(path, data):
    path.write_text(yaml.safe_dump(data, sort_keys=False, explicit_start=True))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def named_values(items, description):
    require(isinstance(items, list), f"{description} must be a list")
    require(
        all(
            isinstance(item, dict)
            and isinstance(item.get("name"), str)
            and "value" in item
            for item in items
        ),
        f"Malformed {description}",
    )
    values = {item["name"]: item["value"] for item in items}
    require(len(values) == len(items), f"Duplicate {description}")
    return values


def base_commit(root, ref):
    return run("git", "rev-parse", "--verify", f"{ref}^{{commit}}", cwd=root).strip()


def predecessor_at_ref(root, version, ref, pipelines=False):
    entries = run(
        "git",
        "ls-tree",
        "--name-only",
        f"{ref}:{'.tekton' if pipelines else OVERLAYS}",
        cwd=root,
    ).splitlines()
    if pipelines:
        candidates = [
            name.removeprefix("submariner-fbc-").removesuffix("-push.yaml")
            for name in entries
            if re.fullmatch(
                r"submariner-fbc-[1-9][0-9]*-(?:0|[1-9][0-9]*)-push.yaml", name
            )
            and name.replace("-push.yaml", "-pull-request.yaml") in entries
        ]
    else:
        candidates = [
            ocp(name.removesuffix("-overlay"))
            for name in entries
            if re.fullmatch(r"[1-9][0-9]*-(?:0|[1-9][0-9]*)-overlay", name)
        ]
    prior = [
        candidate
        for candidate in candidates
        if tuple(map(int, candidate.split("-"))) < tuple(map(int, version.split("-")))
    ]
    require(
        prior,
        "No preceding OCP pipeline pair"
        if pipelines
        else "No preceding OCP overlay in the selected base",
    )
    return max(prior, key=lambda value: tuple(map(int, value.split("-"))))


def repo(path, marker):
    path = path.expanduser().resolve()
    require((path / marker).is_file(), f"Wrong repository or missing {marker}: {path}")
    require(
        Path(run("git", "rev-parse", "--show-toplevel", cwd=path).strip()) == path,
        f"Expected repository root: {path}",
    )
    return path


def worktree(source, target, base, branch, check_only=False):
    """Never reset branches, switch a checkout, or overwrite an unrelated directory."""
    if target.exists():
        require(
            (target / ".git").is_file(), f"Existing path is not a worktree: {target}"
        )
        common = run(
            "git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=source
        ).strip()
        require(
            run(
                "git",
                "rev-parse",
                "--path-format=absolute",
                "--git-common-dir",
                cwd=target,
            ).strip()
            == common,
            f"Worktree belongs to another repository: {target}",
        )
        require(
            run("git", "branch", "--show-current", cwd=target).strip() == branch,
            f"Worktree branch differs: {target}",
        )
        try:
            run("git", "merge-base", "--is-ancestor", base, "HEAD", cwd=target)
        except subprocess.CalledProcessError as error:
            raise ValueError(
                f"{target} does not contain {base}; review and rebase its changes or choose a fresh --workspace"
            ) from error
        return target
    # An existing branch can contain unique work: leave it for explicit reconciliation.
    refs = run(
        "git", "for-each-ref", "--format=%(refname)", f"refs/heads/{branch}", cwd=source
    )
    require(
        not refs.strip(), f"Branch {branch} already exists; select another --workspace"
    )
    if check_only:
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    run(
        "git",
        "worktree",
        "add",
        "-b",
        branch,
        str(target),
        base,
        cwd=source,
        capture=False,
    )
    return target


def add_resource(path, resource):
    data = load(path)
    if resource not in data["resources"]:
        # Preserve source formatting/comments by adding to the existing resources block.
        text = path.read_text()
        require(
            re.search(r"^resources:\s*$", text, re.M), f"No resources block in {path}"
        )
        text = re.sub(
            r"^(resources:\s*\n)",
            lambda m: m[1] + f"  - {resource}\n",
            text,
            count=1,
            flags=re.M,
        )
        path.write_text(text)
    require(
        load(path)["resources"].count(resource) == 1, f"Duplicate resource: {resource}"
    )


def prepare_tenant(root, version, previous, kustomize=None):
    source, dest = (
        root / OVERLAYS / f"{previous}-overlay",
        root / OVERLAYS / f"{version}-overlay",
    )
    require(
        len(list(source.glob("*.yaml"))) == 8,
        f"Unexpected predecessor overlay: {source}",
    )
    if not dest.exists():
        dest.mkdir()
        for path in source.glob("*.yaml"):
            text = (
                path.read_text()
                .replace(previous, version)
                .replace(previous.replace("-", "."), version.replace("-", "."))
            )
            (dest / path.name).write_text(text)
        # Empty CHANNEL_NAME means use the package's default channel. "stable" does
        # not exist in current Submariner catalogs (stable-0.24 does).
        base = load(
            root / OVERLAYS / "base/integration-test-scenario-fbc-operator.yaml"
        )
        params = base["spec"]["params"]
        index = next(i for i, p in enumerate(params) if p["name"] == "CHANNEL_NAME")
        path = dest / "integration-test-scenario-fbc-operator-patch.yaml"
        with path.open("a") as output:
            output.write(
                f"- op: test\n  path: /spec/params/{index}/name\n  value: CHANNEL_NAME\n"
                f'- op: replace\n  path: /spec/params/{index}/value\n  value: ""\n'
            )
    add_resource(
        root / TENANT / "kustomization.yaml",
        f"overlay/application-submariner-fbc/{version}-overlay",
    )
    # Required repository builder, narrowed to this tenant, in an isolated worktree.
    with tempfile.NamedTemporaryFile(mode="w") as changed:
        changed.write("cluster/kflux-prd-rh02/tenants/submariner-tenant\n")
        changed.flush()
        run(
            "./build-manifests.sh",
            kustomize or shutil.which("kustomize") or "kustomize",
            changed.name,
            cwd=root / "tenants-config",
            capture=False,
        )
    validate_tenant(root, version)


def validate_tenant(root, version):
    objects = {}
    for path in (root / GENERATED).glob("*.yaml"):
        data = load(path)
        require(
            isinstance(data, dict) and isinstance(data.get("metadata"), dict),
            f"Malformed resource: {path}",
        )
        name = data["metadata"].get("name", "")
        if name.endswith(f"-{version}") and name.startswith(
            ("submariner-fbc-", "imagerepository-submariner-fbc-")
        ):
            key = (data["kind"], data["metadata"]["name"])
            require(key not in objects, f"Duplicate generated object: {key}")
            objects[key] = data
    return validate_tenant_objects(objects, version)


def validate_tenant_objects(objects, version):
    app = f"submariner-fbc-{version}"
    expected = {
        ("Application", app),
        ("Component", app),
        ("ImageRepository", f"imagerepository-{app}"),
    }
    expected |= {
        ("ReleasePlan", f"submariner-fbc-release-plan-{env}-{version}")
        for env in ("stage", "prod")
    }
    expected |= {
        ("IntegrationTestScenario", f"submariner-fbc-{kind}-{version}")
        for kind in ("operator", "standard")
    }
    require(
        set(objects) == expected,
        f"Generated resource identities differ: {set(objects) ^ expected}",
    )
    for (kind, name), data in objects.items():
        require(
            data["metadata"]["namespace"] == "submariner-tenant",
            f"Wrong namespace: {name}",
        )
        if kind in ("Component", "IntegrationTestScenario", "ReleasePlan"):
            require(data["spec"]["application"] == app, f"Wrong application: {name}")
        if kind == "ReleasePlan":
            require(
                data["metadata"]["labels"].get(
                    "release.appstudio.openshift.io/auto-release"
                )
                == "false",
                f"Autorelease enabled: {name}",
            )
    for env in ("stage", "prod"):
        plan = objects["ReleasePlan", f"submariner-fbc-release-plan-{env}-{version}"]
        require(
            plan["spec"]["target"] == "rhtap-releng-tenant",
            f"Wrong {env} release target",
        )
        require(
            plan["metadata"]["labels"].get(
                "release.appstudio.openshift.io/releasePlanAdmission"
            )
            == f"submariner-fbc-{env}",
            f"Wrong {env} admission label",
        )
    repository = objects["ImageRepository", f"imagerepository-{app}"]
    require(
        repository["spec"]["image"]["name"] == f"submariner-tenant/{app}",
        "Wrong ImageRepository destination",
    )
    for label in ("application", "component"):
        require(
            repository["metadata"]["labels"].get(f"appstudio.redhat.com/{label}")
            == app,
            f"Wrong ImageRepository {label}",
        )
    for scenario in ("standard", "operator"):
        its = objects["IntegrationTestScenario", f"submariner-fbc-{scenario}-{version}"]
        require(
            its["metadata"]["labels"].get("test.appstudio.openshift.io/optional")
            == "false",
            f"Optional {scenario} scenario",
        )
    standard = objects["IntegrationTestScenario", f"submariner-fbc-standard-{version}"]
    require(
        named_values(standard["spec"]["params"], "standard ITS params")[
            "POLICY_CONFIGURATION"
        ]
        == "rhtap-releng-tenant/fbc-standard",
        "Wrong standard ITS policy",
    )
    component = objects["Component", app]
    source = component["spec"]["source"]["git"]
    require(
        source["url"].removesuffix(".git")
        == "https://github.com/stolostron/submariner-operator-fbc"
        and source["revision"] == "main"
        and source["dockerfileUrl"] == "catalog.Dockerfile",
        "Wrong Component source",
    )
    image = f"quay.io/redhat-user-workloads/submariner-tenant/{app}"
    require(
        component["spec"]["containerImage"] == image, "Wrong component output image"
    )
    operator = objects["IntegrationTestScenario", f"submariner-fbc-operator-{version}"]
    params = named_values(operator["spec"]["params"], "operator ITS params")
    require(params["OCI_REF"] == image, "Wrong ITS image")
    require(
        params["CREDENTIALS_SECRET_NAME"] == f"imagerepository-{app}-image-push",
        "Wrong ITS secret",
    )
    require(params["CHANNEL_NAME"] == "", "ITS must use the catalog default channel")
    require(
        operator["spec"]["contexts"][0]["name"] == f"component_{app}",
        "Wrong ITS component context",
    )
    return sorted(name for _, name in objects)


def prepare_rpas(root, version):
    for env in ("stage", "prod"):
        path = root / RPA / f"submariner-fbc-{env}.yaml"
        data = load(path)
        app = f"submariner-fbc-{version}"
        if app not in data["spec"]["applications"]:
            text = path.read_text()
            require(
                re.search(r"^  applications:\s*$", text, re.M),
                f"No applications block: {path}",
            )
            text = re.sub(
                r"^(  applications:\s*\n)",
                lambda m: m[1] + f"    - {app}\n",
                text,
                count=1,
                flags=re.M,
            )
            path.write_text(text)
        validate_rpa(load(path), version, env)


def validate_rpa(data, version, env):
    require(
        data["kind"] == "ReleasePlanAdmission"
        and data["metadata"]["name"] == f"submariner-fbc-{env}"
        and data["metadata"]["namespace"] == "rhtap-releng-tenant",
        f"Wrong {env} admission identity",
    )
    require(
        data["metadata"]["labels"].get("release.appstudio.openshift.io/block-releases")
        == "false",
        f"Blocked {env} admission",
    )
    spec = data["spec"]
    require(
        spec["applications"].count(f"submariner-fbc-{version}") == 1,
        f"Missing/duplicate {env} admission application",
    )
    require(spec["origin"] == "submariner-tenant", f"Wrong {env} admission origin")
    require(
        spec["policy"] == ("fbc-stage" if env == "stage" else "fbc-standard"),
        f"Wrong {env} admission policy",
    )
    fbc = spec["data"]["fbc"]
    require(fbc["allowedPackages"] == ["submariner"], f"Wrong {env} allowed packages")
    require(
        "{{ OCP_VERSION }}" in fbc["fromIndex"], f"Hardcoded {env} source index version"
    )
    if env == "stage":
        require(
            fbc.get("stagedIndex") is True
            and fbc["targetIndex"] == ""
            and spec["data"]["intention"] == "staging",
            "Wrong stage destination",
        )
    else:
        require(
            not fbc.get("stagedIndex", False)
            and "{{ OCP_VERSION }}" in fbc["targetIndex"]
            and spec["data"]["intention"] == "production",
            "Wrong prod destination",
        )
    params = named_values(
        spec["pipeline"]["pipelineRef"]["params"], "admission pipeline params"
    )
    require(
        params["url"].removesuffix(".git")
        == "https://github.com/konflux-ci/release-service-catalog"
        and params["pathInRepo"] == "pipelines/managed/fbc-release/fbc-release.yaml",
        f"Wrong {env} admission pipeline",
    )


def pipelines(root, version, previous, base_image):
    for event in ("push", "pull-request"):
        path = root / ".tekton" / f"submariner-fbc-{version}-{event}.yaml"
        if not path.exists():
            source = root / ".tekton" / f"submariner-fbc-{previous}-{event}.yaml"
            require(
                source.exists(), f"No pipeline template: {source}; supply --previous"
            )
            # Literal identity replacement keeps comments, CEL, and inline or
            # referenced pipeline structure intact. Params are validated below.
            text = source.read_text().replace(previous, version)
            old = f"registry.redhat.io/openshift{previous.split('-')[0]}/ose-operator-registry-rhel9:v{previous.replace('-', '.')}"
            require(
                text.count(old) == 1,
                f"Expected one explicit base-image build arg in {source}",
            )
            path.write_text(text.replace(old, base_image))
    validate_pipelines(root, version, base_image)


def validate_pipelines(root, version, base_image):
    for event in ("push", "pull-request"):
        path = root / ".tekton" / f"submariner-fbc-{version}-{event}.yaml"
        data = load(path)
        app = f"submariner-fbc-{version}"
        require(data["kind"] == "PipelineRun", f"Not a PipelineRun: {path}")
        require(
            data["metadata"]["name"] == f"{app}-on-{event}",
            f"Wrong pipeline name: {path}",
        )
        for label in ("application", "component"):
            require(
                data["metadata"]["labels"][f"appstudio.openshift.io/{label}"] == app,
                f"Wrong {label}: {path}",
            )
        params = named_values(data["spec"]["params"], "pipeline params")
        require(
            data["metadata"].get("namespace") == "submariner-tenant",
            f"Wrong pipeline namespace: {path}",
        )
        require(params.get("revision") == "{{revision}}", f"Wrong revision: {path}")
        require(
            params.get("git-url")
            in (
                "{{source_url}}",
                "https://github.com/stolostron/submariner-operator-fbc",
                "https://github.com/stolostron/submariner-operator-fbc.git",
            ),
            f"Wrong Git source: {path}",
        )
        require(
            len(params) == len(data["spec"]["params"]),
            f"Duplicate pipeline params: {path}",
        )
        require(
            sorted(params["build-platforms"]) == sorted(PLATFORMS),
            f"Wrong platforms: {path}",
        )
        require(
            params["dockerfile"] == "catalog.Dockerfile", f"Wrong Dockerfile: {path}"
        )
        arguments = params["build-args"]
        require(
            isinstance(arguments, list)
            and all(isinstance(arg, str) and "=" in arg for arg in arguments),
            f"Malformed build arguments: {path}",
        )
        build_args = dict(arg.split("=", 1) for arg in arguments)
        require(
            len(build_args) == len(arguments), f"Duplicate build argument keys: {path}"
        )
        require(
            build_args.get("INPUT_DIR") == f"catalog-{version}",
            f"Wrong INPUT_DIR: {path}",
        )
        require(build_args.get("OPM_IMAGE") == base_image, f"Wrong OPM_IMAGE: {path}")
        expected = (
            f"quay.io/redhat-user-workloads/submariner-tenant/{app}:"
            + ("on-pr-" if event == "pull-request" else "")
            + "{{revision}}"
        )
        require(params["output-image"] == expected, f"Wrong output image: {path}")
        annotations = data["metadata"]["annotations"]
        require(
            annotations["pipelinesascode.tekton.dev/cancel-in-progress"]
            == ("true" if event == "pull-request" else "false"),
            f"Wrong cancellation policy: {path}",
        )
        if event == "pull-request":
            require(params["image-expires-after"] == "5d", f"Wrong PR expiry: {path}")
        else:
            expiry = params.get("image-expires-after")
            if "image-expires-after" not in params:
                defaults = [
                    parameter.get("default")
                    for parameter in data["spec"]
                    .get("pipelineSpec", {})
                    .get("params", [])
                    if parameter.get("name") == "image-expires-after"
                ]
                require(
                    len(defaults) == 1, f"Cannot determine push image expiry: {path}"
                )
                expiry = defaults[0]
            require(expiry == "", f"Push images must not expire: {path}")
        cel = annotations["pipelinesascode.tekton.dev/on-cel-expression"]
        # Accept the documented positive path-trigger grammar. Substring checks
        # also accept disabled expressions and the wrong event or target branch.
        expression = re.fullmatch(
            r'event\s*==\s*"'
            + event.replace("-", "_")
            + r'"\s*&&\s*target_branch\s*==\s*"main"\s*&&\s*\((.*)\)',
            cel.strip(),
            re.S,
        )
        require(expression, f"Wrong/unsupported event or branch expression: {path}")
        triggers = [
            re.fullmatch(r'"([^"\n]+)"\.pathChanged\(\)', term.strip())
            for term in expression[1].split("||")
        ]
        require(all(triggers), f"Unsupported path trigger expression: {path}")
        paths = [trigger[1] for trigger in triggers]
        expected_paths = [
            f"catalog-{version}/***",
            ".tekton/images-mirror-set.yaml",
            "catalog.Dockerfile",
        ] + [f".tekton/{app}-{mode}.yaml" for mode in ("push", "pull-request")]
        require(
            sorted(paths) == sorted(expected_paths),
            f"Missing, duplicate, or unexpected CEL paths: {path}",
        )
        require(
            ("pipelineSpec" in data["spec"]) != ("pipelineRef" in data["spec"]),
            f"Expected one pipeline definition: {path}",
        )
        require(
            data["spec"]["taskRunTemplate"]["serviceAccountName"]
            == f"build-pipeline-{app}",
            f"Wrong service account: {path}",
        )


def prepare_catalog(root, args, previous, base_image):
    require(
        (root / "test/lib/isolate.sh").is_file(),
        "Selected FBC base lacks isolated tests; land the safety changes first",
    )
    require(
        args.min_supported_sub,
        "--min-supported-sub is required for catalog preparation",
    )
    minor = int(args.min_supported_sub.split(".")[1])
    require(
        minor > 0,
        "Inclusive minimum 0.0 cannot be represented by the existing cutoff map",
    )
    cutoff = f"0.{minor - 1}"
    template = load(root / "catalog-template.yaml")
    channel = f"stable-{args.min_supported_sub}"
    channels = [e for e in template["entries"] if e.get("schema") == "olm.channel"]
    require(
        any(e["name"] == channel and e.get("entries") for e in channels),
        f"No populated {channel} channel in template; add its bundles first",
    )
    path = root / "drop-versions.json"
    data = json.loads(path.read_text())
    dotted = args.ocp.replace("-", ".")
    require(
        dotted not in data or data[dotted] == cutoff,
        f"Existing {dotted} cutoff conflicts with requested minimum",
    )
    data[dotted] = cutoff
    path.write_text(json.dumps(data, indent=2) + "\n")
    pipelines(root, args.ocp, previous, base_image)
    run("make", "build-catalogs", cwd=root, capture=False)
    run("make", "validate-catalogs", cwd=root, capture=False)
    run("make", "test", cwd=root, capture=False)
    validate_catalog(root, args.ocp, args.min_supported_sub)


def validate_catalog(root, version, minimum):
    mapping = json.loads((root / "drop-versions.json").read_text())
    dotted = version.replace("-", ".")
    require(dotted in mapping, f"Catalog {dotted} is not registered in the build map")
    if minimum:
        require(
            mapping[dotted] == f"0.{int(minimum.split('.')[1]) - 1}",
            "Catalog build map conflicts with the requested minimum",
        )
    directory = root / f"catalog-{version}"
    package = load(directory / "package.yaml")
    require(
        package["schema"] == "olm.package" and package["name"] == "submariner",
        "Catalog package must be submariner",
    )
    channels = [load(p) for p in (directory / "channels").glob("*.yaml")]
    require(
        channels
        and any(
            c["name"] == package["defaultChannel"] and c.get("entries")
            for c in channels
        ),
        "Default channel is missing or empty",
    )
    bundles = list((directory / "bundles").glob("*.yaml"))
    require(bundles, "Catalog contains no bundles")
    if minimum:
        for path in bundles:
            data = load(path)
            version_value = next(
                p["value"]["version"]
                for p in data["properties"]
                if p["type"] == "olm.package"
            )
            require(
                tuple(map(int, version_value.split(".")[:2]))
                >= tuple(map(int, minimum.split("."))),
                f"Bundle below minimum: {path}",
            )
    run(str(root / "bin/opm"), "validate", str(directory), capture=False)
    return len(bundles)


def verify_live(args, base_image):
    """Report deployed build evidence; never infer runtime support from ITS pass."""
    require(
        args.expected_commit and re.fullmatch(r"[0-9a-f]{40}", args.expected_commit),
        "verify-live requires --expected-commit with the merged 40-character SHA",
    )
    app = f"submariner-fbc-{args.ocp}"
    namespace = "submariner-tenant"
    result = {
        "ocp": args.ocp,
        "expected_commit": args.expected_commit,
        "errors": [],
        "runtime_on_requested_ocp": "unverified; inspect install task execution and actual cluster version",
    }

    def get(kind, name):
        return json.loads(run("oc", "get", kind, name, "-n", namespace, "-o", "json"))

    try:
        identities = [
            ("Application", app),
            ("Component", app),
            ("ImageRepository", f"imagerepository-{app}"),
        ]
        identities += [
            ("IntegrationTestScenario", f"submariner-fbc-{kind}-{args.ocp}")
            for kind in ("standard", "operator")
        ]
        identities += [
            ("ReleasePlan", f"submariner-fbc-release-plan-{env}-{args.ocp}")
            for env in ("stage", "prod")
        ]
        objects = {
            identity: get(identity[0].lower(), identity[1]) for identity in identities
        }
        for (kind, name), obj in objects.items():
            require(
                obj["kind"] == kind and obj["metadata"]["name"] == name,
                f"Unexpected live resource identity: {kind}/{name}",
            )
        validate_tenant_objects(objects, args.ocp)
        for env in ("stage", "prod"):
            plan = objects[
                "ReleasePlan", f"submariner-fbc-release-plan-{env}-{args.ocp}"
            ]
            require(
                plan["spec"]["application"] == app, f"Wrong {env} release application"
            )
            require(
                plan["metadata"]["labels"].get(
                    "release.appstudio.openshift.io/auto-release"
                )
                == "false",
                f"{env} autorelease is enabled",
            )
            admission = plan["status"]["releasePlanAdmission"]
            require(
                admission.get("active") is True
                and admission.get("name")
                == f"rhtap-releng-tenant/submariner-fbc-{env}",
                f"Wrong/inactive {env} admission",
            )
            require(
                any(
                    c["type"] == "Matched" and c["status"] == "True"
                    for c in plan["status"]["conditions"]
                ),
                f"{env} release plan is unmatched",
            )
        get("serviceaccount", f"build-pipeline-{app}")
        # Existence check only: never read or print secret data.
        run(
            "oc",
            "get",
            "secret",
            f"imagerepository-{app}-image-push",
            "-n",
            namespace,
            "-o",
            "name",
        )
        result["configuration_ready"] = True
        snapshots = json.loads(
            run(
                "oc",
                "get",
                "snapshots",
                "-n",
                namespace,
                "-l",
                f"appstudio.openshift.io/application={app}",
                "-o",
                "json",
            )
        )["items"]
        candidates = [
            snap
            for snap in snapshots
            if snap["spec"]["application"] == app
            and snap["metadata"]
            .get("labels", {})
            .get("pac.test.appstudio.openshift.io/event-type")
            == "push"
            and len(snap["spec"]["components"]) == 1
            and snap["spec"]["components"][0].get("name") == app
            and snap["spec"]["components"][0]
            .get("source", {})
            .get("git", {})
            .get("revision")
            == args.expected_commit
        ]
        require(candidates, "No merged push snapshot for the expected commit")
        snapshot = max(
            candidates, key=lambda snap: snap["metadata"]["creationTimestamp"]
        )
        result["snapshot"] = snapshot["metadata"]["name"]
        tests = json.loads(
            snapshot["metadata"]["annotations"]["test.appstudio.openshift.io/status"]
        )
        names = [test["scenario"] for test in tests]
        required = {
            f"submariner-fbc-{kind}-{args.ocp}" for kind in ("standard", "operator")
        }
        require(
            required.issubset(names)
            and len(names) == len(set(names))
            and all(test["status"] == "TestPassed" for test in tests),
            "Required snapshot tests are missing or incomplete",
        )
        plr_name = snapshot["metadata"]["labels"][
            "appstudio.openshift.io/build-pipelinerun"
        ]
        build = get("pipelinerun", plr_name)
        require(
            any(
                c["type"] == "Succeeded" and c["status"] == "True"
                for c in build["status"]["conditions"]
            ),
            "Build PipelineRun did not succeed",
        )
        labels = build["metadata"].get("labels", {})
        annotations = build["metadata"].get("annotations", {})
        require(
            all(
                labels.get(f"appstudio.openshift.io/{key}") == app
                for key in ("application", "component")
            ),
            "Build application/component differs",
        )
        require(
            annotations.get("pipelinesascode.tekton.dev/event-type") == "push"
            and annotations.get("build.appstudio.redhat.com/target_branch") == "main",
            "Build is not a push to main",
        )
        params = named_values(build["spec"]["params"], "live build params")
        require(
            params["git-url"].removesuffix(".git")
            == "https://github.com/stolostron/submariner-operator-fbc",
            "Wrong build source URL",
        )
        require(
            params["revision"] == args.expected_commit,
            "Build revision differs from expected commit",
        )
        require(
            sorted(params["build-platforms"]) == sorted(PLATFORMS),
            "Build did not request all four platforms",
        )
        image = snapshot["spec"]["components"][0]["containerImage"]
        expected_repo = f"quay.io/redhat-user-workloads/submariner-tenant/{app}"
        require(
            re.fullmatch(re.escape(expected_repo) + r"@sha256:[0-9a-f]{64}", image),
            "Snapshot image must have the expected repository and a SHA256 digest",
        )
        source = snapshot["spec"]["components"][0]["source"]["git"]
        require(
            source["url"].removesuffix(".git")
            == "https://github.com/stolostron/submariner-operator-fbc",
            "Wrong snapshot source URL",
        )
        results = named_values(build["status"]["results"], "build results")
        require(
            results.get("IMAGE_DIGEST") == image.split("@")[1]
            and results.get("IMAGE_URL", "").split(":")[0] == expected_repo,
            "Build image results do not match the snapshot",
        )
        manifest = json.loads(run("skopeo", "inspect", "--raw", f"docker://{image}"))
        arches = {
            item["platform"]["architecture"]
            for item in manifest["manifests"]
            if item["platform"]["os"] == "linux"
        }
        require(
            {"amd64", "arm64", "ppc64le", "s390x"}.issubset(arches),
            "Published image is missing build platforms",
        )
        for item in manifest["manifests"]:
            if (
                item["platform"]["os"] != "linux"
                or item["platform"]["architecture"] not in arches
            ):
                continue
            child = json.loads(
                run(
                    "skopeo",
                    "inspect",
                    "--raw",
                    "docker://" + image.split("@")[0] + "@" + item["digest"],
                )
            )
            require(
                child.get("annotations", {}).get("org.opencontainers.image.base.name")
                == base_image,
                f"Wrong/missing base annotation for {item['platform']['architecture']}",
            )
        result.update(build_ready=True, image=image, platforms=sorted(arches))
    except (ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        result["errors"].append(str(error))
    print(json.dumps(result, indent=2))
    return not result["errors"]


def git_text(root, ref, path):
    return run("git", "show", f"{ref}:{path}", cwd=root)


def require_tools(*names):
    missing = [name for name in names if not shutil.which(name)]
    require(not missing, "Missing required tools: " + ", ".join(missing))


def kustomize_binary(root, requested=None, ref=None):
    binary = str(requested) if requested else shutil.which("kustomize")
    require(
        binary and shutil.which(binary),
        "Kustomize is required; select it with --kustomize",
    )
    source = (
        git_text(root, ref, "tenants-config/utils.sh")
        if ref
        else (root / "tenants-config/utils.sh").read_text()
    )
    required = re.search(r"KUSTOMIZE_VERSION=['\"]?(v[0-9]+\.[0-9]+\.[0-9]+)", source)
    require(
        required, "Cannot determine the selected repository's Kustomize requirement"
    )
    actual = re.search(r"v([0-9]+\.[0-9]+\.[0-9]+)", run(binary, "version"))
    require(
        actual
        and tuple(map(int, actual[1].split(".")))
        >= tuple(map(int, required[1][1:].split("."))),
        f"Kustomize {required[1]} or newer required; use --kustomize /path/to/kustomize",
    )
    return str(Path(shutil.which(binary)).resolve())


def catalog_inputs(template, mapping, version, minimum):
    require(minimum, "Choose --min-supported-sub before catalog preparation")
    cutoff = f"0.{int(minimum.split('.')[1]) - 1}"
    dotted = version.replace("-", ".")
    require(
        dotted not in mapping or mapping[dotted] == cutoff,
        f"Existing {dotted} cutoff conflicts with requested minimum",
    )
    channels = [
        entry for entry in template["entries"] if entry.get("schema") == "olm.channel"
    ]
    require(
        any(
            entry["name"] == f"stable-{minimum}" and entry.get("entries")
            for entry in channels
        ),
        f"No populated stable-{minimum} channel in template; add its bundles first",
    )
    packages = [
        entry for entry in template["entries"] if entry.get("schema") == "olm.package"
    ]
    require(
        len(packages) == 1 and packages[0]["name"] == "submariner",
        "Expected one Submariner package",
    )
    default = packages[0]["defaultChannel"]
    require(
        any(
            entry["name"] == default
            and entry.get("entries")
            and stream(entry["name"].removeprefix("stable-"))
            and int(entry["name"].split(".")[-1]) >= int(minimum.split(".")[-1])
            for entry in channels
        ),
        "The selected cutoff removes the populated default channel",
    )
    return cutoff


def inspect_base_image(image):
    require_tools("skopeo")
    manifest = json.loads(run("skopeo", "inspect", "--raw", f"docker://{image}"))
    arches = {
        item.get("platform", {}).get("architecture")
        for item in manifest.get("manifests", [])
        if item.get("platform", {}).get("os") == "linux"
    }
    require(
        {"amd64", "arm64", "ppc64le", "s390x"}.issubset(arches),
        "Selected OPM base must provide amd64, arm64, ppc64le and s390x",
    )
    return sorted(arches)


def verify_workspace(workspace, args, image):
    result = {"tenant_resources": validate_tenant(workspace / "tenant", args.ocp)}
    for env in ("stage", "prod"):
        validate_rpa(
            load(workspace / "admission" / RPA / f"submariner-fbc-{env}.yaml"),
            args.ocp,
            env,
        )
    validate_pipelines(workspace / "fbc", args.ocp, image)
    result["bundles"] = validate_catalog(
        workspace / "fbc", args.ocp, args.min_supported_sub
    )
    result.update(
        local_ready=True,
        deployed="unverified",
        multiarch_build="unverified",
        tested_on_ocp=args.ocp.replace("-", ".") + ": unverified",
    )
    return result


def test_image(root, version, base_image):
    require_tools("make", "podman")
    inspect_base_image(base_image)
    with tempfile.TemporaryDirectory(prefix="fbc-image-") as temporary:
        image = "localhost/submariner-fbc-onboarding:" + Path(temporary).name
        try:
            run(
                "make",
                "test-image",
                f"CATALOG=catalog-{version}",
                f"OPM_IMAGE={base_image}",
                f"IMG={image}",
                cwd=root,
                capture=False,
            )
        finally:
            subprocess.run(
                ["podman", "rmi", image],
                stdout=sys.stderr,
                stderr=sys.stderr,
                check=False,
            )
    return {
        "catalog": f"catalog-{version}",
        "base_image": base_image,
        "local_image_test": "passed",
        "multiarch_build": "unverified",
        "runtime": "unverified",
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ocp", type=ocp)
    parser.add_argument(
        "legacy_cutoff",
        nargs="?",
        type=stream,
        help="deprecated exclusive drop-through stream",
    )
    parser.add_argument(
        "--min-supported-sub",
        type=stream,
        help="inclusive first supported stream, e.g. 0.24",
    )
    parser.add_argument(
        "--phase",
        choices=[
            "plan",
            "prepare",
            "prepare-config",
            "prepare-catalog",
            "verify",
            "test-image",
            "verify-live",
        ],
        default="plan",
    )
    parser.add_argument(
        "--release-data-repo",
        type=Path,
        default=Path.home() / "konflux/konflux-release-data",
    )
    parser.add_argument(
        "--fbc-repo", type=Path, default=Path.home() / "konflux/submariner-operator-fbc"
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        help="worktree parent (required outside plan/live mode)",
    )
    parser.add_argument(
        "--base",
        help="compatible shorthand for both repository refs; no implicit fetch",
    )
    parser.add_argument(
        "--release-data-ref", help="release-data ref or SHA (default origin/main)"
    )
    parser.add_argument("--fbc-ref", help="FBC ref or SHA (default origin/main)")
    parser.add_argument(
        "--previous", type=ocp, help="compatible shorthand for both predecessors"
    )
    parser.add_argument("--overlay-previous", type=ocp)
    parser.add_argument("--pipeline-previous", type=ocp)
    parser.add_argument("--base-image", help="operator-registry build image override")
    parser.add_argument(
        "--kustomize",
        type=Path,
        help="Kustomize binary for the selected release-data version",
    )
    parser.add_argument(
        "--expected-commit", help="merged commit required for live verification"
    )
    args = parser.parse_args(argv)
    if args.legacy_cutoff:
        require(
            not args.min_supported_sub,
            "Do not combine the legacy cutoff with --min-supported-sub",
        )
        args.min_supported_sub = f"0.{int(args.legacy_cutoff.split('.')[1]) + 1}"
        print(
            f"WARNING: positional {args.legacy_cutoff} is a drop-through cutoff, NOT a minimum; inclusive minimum is {args.min_supported_sub}",
            file=sys.stderr,
        )
    require(
        not args.min_supported_sub or int(args.min_supported_sub.split(".")[1]) > 0,
        "Inclusive minimum must be above 0.0 for the drop-through map",
    )
    for explicit in (args.release_data_ref, args.fbc_ref):
        require(
            not (args.base and explicit and args.base != explicit),
            "Do not combine conflicting --base and repository refs",
        )
    for explicit in (args.overlay_previous, args.pipeline_previous):
        require(
            not (args.previous and explicit and args.previous != explicit),
            "Do not combine conflicting --previous and predecessor options",
        )
    dotted = args.ocp.replace("-", ".")
    image = (
        args.base_image
        or f"registry.redhat.io/openshift{args.ocp.split('-')[0]}/ose-operator-registry-rhel9:v{dotted}"
    )
    if args.phase == "verify-live":
        if not verify_live(args, image):
            raise ValueError("Live readiness checks failed; see JSON evidence above")
        return
    if args.phase != "plan":
        require(args.workspace, "--workspace is required outside plan mode")
    workspace = args.workspace.expanduser().resolve() if args.workspace else None
    if args.phase == "verify":
        print(json.dumps(verify_workspace(workspace, args, image), indent=2))
        return
    if args.phase == "test-image":
        validate_catalog(workspace / "fbc", args.ocp, args.min_supported_sub)
        print(json.dumps(test_image(workspace / "fbc", args.ocp, image), indent=2))
        return
    sources = {}
    issues = {"configuration": [], "catalog": []}
    configuration = args.phase in ("plan", "prepare", "prepare-config")
    catalog = args.phase in ("plan", "prepare", "prepare-catalog")
    for kind, needed, path, marker, ref, previous in (
        (
            "configuration",
            configuration,
            args.release_data_repo,
            str(OVERLAYS / "base/kustomization.yaml"),
            args.release_data_ref or args.base or "origin/main",
            args.overlay_previous or args.previous,
        ),
        (
            "catalog",
            catalog,
            args.fbc_repo,
            "drop-versions.json",
            args.fbc_ref or args.base or "origin/main",
            args.pipeline_previous or args.previous,
        ),
    ):
        if not needed:
            continue
        try:
            root = repo(path, marker)
            sha = base_commit(root, ref)
            previous = previous or predecessor_at_ref(
                root, args.ocp, sha, pipelines=kind == "catalog"
            )
            require(
                tuple(map(int, previous.split("-")))
                < tuple(map(int, args.ocp.split("-"))),
                "Previous OCP must precede the requested version",
            )
            sources[kind] = {
                "root": str(root),
                "ref": ref,
                "commit": sha,
                "previous": previous,
            }
            if kind == "configuration":
                require_tools("git", "yq")
                sources[kind]["kustomize"] = kustomize_binary(root, args.kustomize, sha)
                names = run(
                    "git",
                    "ls-tree",
                    "--name-only",
                    f"{sha}:{OVERLAYS}/{previous}-overlay",
                    cwd=root,
                ).splitlines()
                require(
                    len([name for name in names if name.endswith(".yaml")]) == 8,
                    "Unexpected predecessor overlay layout",
                )
                for env in ("stage", "prod"):
                    admission = yaml.safe_load(
                        git_text(root, sha, RPA / f"submariner-fbc-{env}.yaml")
                    )
                    app = f"submariner-fbc-{args.ocp}"
                    if app not in admission["spec"]["applications"]:
                        admission["spec"]["applications"].append(app)
                    validate_rpa(admission, args.ocp, env)
            else:
                require_tools("git", "make", "jq", "yq", "podman", "curl", "csplit")
                git_text(root, sha, "test/lib/isolate.sh")
                for event in ("push", "pull-request"):
                    git_text(
                        root, sha, f".tekton/submariner-fbc-{previous}-{event}.yaml"
                    )
                template = yaml.safe_load(git_text(root, sha, "catalog-template.yaml"))
                mapping = json.loads(git_text(root, sha, "drop-versions.json"))
                catalog_inputs(template, mapping, args.ocp, args.min_supported_sub)
        except (
            ValueError,
            KeyError,
            TypeError,
            OSError,
            yaml.YAMLError,
            subprocess.CalledProcessError,
        ) as error:
            if args.phase != "plan":
                raise
            issues[kind].append(str(error))
    if args.phase == "plan":
        print(
            json.dumps(
                {
                    "ocp": args.ocp,
                    "minimum_inclusive": args.min_supported_sub,
                    "cutoff_exclusive": f"0.{int(args.min_supported_sub.split('.')[1]) - 1}"
                    if args.min_supported_sub
                    else None,
                    "base_image": image,
                    "sources": sources,
                    "blockers": issues,
                    "previous": sources.get("configuration", {}).get("previous"),
                    "remote_freshness": "not checked; fetch explicitly before preparing",
                    "base_image_availability": "unverified; inspected before catalog preparation",
                    "next_phases": [
                        "prepare (or prepare-config while policy is pending)",
                        "test-image",
                        "review/reconcile configuration and merged push build",
                        "verify-live and actual install/QE",
                    ],
                },
                indent=2,
            )
        )
        return
    prefix = re.sub(r"[^a-zA-Z0-9._-]", "-", workspace.name) + f"-ocp-{args.ocp}"
    targets = []
    if configuration:
        targets += [
            ("configuration", "tenant", "tenant"),
            ("configuration", "admission", "admission"),
        ]
    if catalog:
        inspect_base_image(image)
        targets.append(("catalog", "fbc", "catalog"))
    # Check all existing targets/branches before creating the first worktree.
    for kind, directory, suffix in targets:
        source = sources[kind]
        worktree(
            Path(source["root"]),
            workspace / directory,
            source["commit"],
            prefix + "-" + suffix,
            check_only=True,
        )
    for kind, directory, suffix in targets:
        source = sources[kind]
        worktree(
            Path(source["root"]),
            workspace / directory,
            source["commit"],
            prefix + "-" + suffix,
        )
    if configuration:
        prepare_tenant(
            workspace / "tenant",
            args.ocp,
            sources["configuration"]["previous"],
            sources["configuration"]["kustomize"],
        )
        prepare_rpas(workspace / "admission", args.ocp)
    if catalog:
        prepare_catalog(workspace / "fbc", args, sources["catalog"]["previous"], image)
    result = {
        "ocp": args.ocp,
        "workspace": str(workspace),
        "sources": sources,
        "prepared": [directory for _, directory, _ in targets],
        "deployed": "unverified",
    }
    if args.phase == "prepare":
        result.update(verify_workspace(workspace, args, image))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (
        ValueError,
        KeyError,
        TypeError,
        yaml.YAMLError,
        StopIteration,
        OSError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
