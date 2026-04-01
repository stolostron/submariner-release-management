.PHONY: help test test-remote validate-yaml validate-fields validate-data validate-references validate-bundle-images validate-markdown gitlint shellcheck apply watch create-fbc-releases create-component-release rpm-lockfile-update add-release-notes

.DEFAULT_GOAL := help

# Shellcheck configuration
SHELLCHECK_ARGS += $(shell [ ! -d scripts ] || find scripts -type f -exec awk 'FNR == 1 && /sh$$/ { print FILENAME }' {} +)
export SHELLCHECK_ARGS

help:
	@echo "Available targets:"
	@echo ""
	@echo "Release Creation:"
	@echo "  make create-fbc-releases VERSION=... [TYPE=stage|prod]"
	@echo "                         - Create FBC releases for all 6 OCP versions (requires oc login)"
	@echo "                           Default TYPE is stage if not specified"
	@echo "                           Example: make create-fbc-releases VERSION=0.22.1"
	@echo "                           Example: make create-fbc-releases VERSION=0.22.1 TYPE=prod"
	@echo "  make create-component-release VERSION=... [TYPE=stage|prod]"
	@echo "                         - Create component release (requires oc login)"
	@echo "                           Default TYPE is stage if not specified"
	@echo "                           Example: make create-component-release VERSION=0.22.1"
	@echo "                           Example: make create-component-release VERSION=0.22.1 TYPE=prod"
	@echo "  make rpm-lockfile-update [BRANCH=...] [REPO=...|COMPONENT=...]"
	@echo "                         - Update RPM lockfiles across Submariner repos"
	@echo "                           Example: make rpm-lockfile-update"
	@echo "                           Example: make rpm-lockfile-update COMPONENT=gateway"
	@echo "                           Example: make rpm-lockfile-update BRANCH=0.21 COMPONENT=gateway"
	@echo "  make add-release-notes VERSION=... [STAGE_YAML=...]"
	@echo "                         - Query Jira and display release note candidates (report mode, no YAML updates)"
	@echo "                           For interactive mode (updates YAML), use: ./scripts/add-release-notes.sh VERSION"
	@echo "                           Example: make add-release-notes VERSION=0.22.1"
	@echo "                           Example: make add-release-notes VERSION=0.22.1 STAGE_YAML=releases/0.22/stage/submariner-0-22-1-stage-20260316-01.yaml"
	@echo ""
	@echo "Validation:"
	@echo "  make test              - Run local validations (no cluster access needed)"
	@echo "  make test-remote       - Run all validations including cluster checks and bundle images (requires oc login)"
	@echo "  make validate-yaml     - YAML syntax only"
	@echo "  make validate-fields   - Release CRD fields only"
	@echo "  make validate-data     - Data formats only"
	@echo "  make validate-markdown - Markdown linting (docs)"
	@echo "  make gitlint           - Commit message linting"
	@echo "  make shellcheck        - Shell script linting"
	@echo ""
	@echo "Release Operations:"
	@echo "  make apply FILE=...    - Validate and apply release YAML to cluster (requires oc login)"
	@echo "  make watch NAME=...    - Watch release status (requires oc login)"

create-fbc-releases:
	@test -n "$(VERSION)" || (echo "ERROR: VERSION parameter required. Usage: make create-fbc-releases VERSION=0.22.1 [TYPE=stage|prod]" && exit 1)
	./scripts/create-fbc-releases.sh $(VERSION) $(if $(TYPE),--$(TYPE),--stage)

create-component-release:
	@test -n "$(VERSION)" || (echo "ERROR: VERSION parameter required. Usage: make create-component-release VERSION=0.22.1 [TYPE=stage|prod]" && exit 1)
	./scripts/create-component-release.sh $(VERSION) $(if $(TYPE),$(TYPE),stage)

rpm-lockfile-update:
	./scripts/rpm-lockfile-update.sh $(BRANCH) $(if $(REPO),$(REPO),$(COMPONENT))

add-release-notes:
	@test -n "$(VERSION)" || (echo "ERROR: VERSION parameter required. Usage: make add-release-notes VERSION=0.22.1 [STAGE_YAML=...]" && exit 1)
	@./scripts/release-notes/collect.sh $(VERSION) $(if $(STAGE_YAML),--stage-yaml $(STAGE_YAML),)
	@./scripts/release-notes/prepare.sh
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Review: jq . /tmp/release-notes-topics.json"
	@echo "Next: /add-release-notes $(VERSION) $(if $(STAGE_YAML),--stage-yaml $(STAGE_YAML),)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test: validate-yaml validate-fields validate-data validate-markdown gitlint shellcheck

test-remote: test validate-references validate-bundle-images

validate-references:
	./scripts/validate-release-references.sh $(FILE)

validate-bundle-images:
	./scripts/validate-bundle-images.sh $(FILE)

validate-yaml:
	yamllint .

validate-fields:
	./scripts/validate-release-fields.sh $(FILE)

validate-data:
	./scripts/validate-release-data.sh $(FILE)

validate-markdown:
	npx markdownlint-cli2 "**/*.md"

gitlint:
	gitlint --commits origin/main..HEAD

shellcheck:
ifneq (,$(SHELLCHECK_ARGS))
	shellcheck -S warning $(SHELLCHECK_ARGS)
else
	@echo 'No shell scripts found to check.'
endif

apply: test-remote
	@test -n "$(FILE)" || (echo "ERROR: FILE parameter required. Usage: make apply FILE=releases/0.20/stage/..." && exit 1)
	@test -f "$(FILE)" || (echo "ERROR: File '$(FILE)' not found" && exit 1)
	oc apply -n submariner-tenant -f "$(FILE)"

watch:
	@test -n "$(NAME)" || (echo "ERROR: NAME parameter required. Usage: make watch NAME=submariner-0-20-2-stage-..." && exit 1)
	@echo "Watching Release '$(NAME)' in submariner-tenant namespace..."
	@echo "Press Ctrl+C to exit"
	@echo ""
	@while true; do \
		clear; \
		echo "=== Release Status ==="; \
		oc get release "$(NAME)" -n submariner-tenant -o yaml | yq '.status' 2>/dev/null || echo "No status yet"; \
		echo ""; \
		echo "=== Latest Conditions ==="; \
		oc get release "$(NAME)" -n submariner-tenant -o json 2>/dev/null | jq -r '.status.conditions[]? | "\(.lastTransitionTime) \(.type): \(.status) - \(.reason): \(.message)"' | tail -5 || echo "No conditions yet"; \
		echo ""; \
		echo "=== Release Pipeline ==="; \
		PIPELINE_RUN_FULL=$$(oc get release "$(NAME)" -n submariner-tenant -o jsonpath='{.status.managedProcessing.pipelineRun}' 2>/dev/null); \
		if [ -n "$$PIPELINE_RUN_FULL" ]; then \
			echo "PipelineRun: $$PIPELINE_RUN_FULL"; \
			START_TIME=$$(oc get release "$(NAME)" -n submariner-tenant -o jsonpath='{.status.managedProcessing.startTime}' 2>/dev/null); \
			echo "Started: $$START_TIME"; \
			RELEASE_STATUS=$$(oc get release "$(NAME)" -n submariner-tenant -o json 2>/dev/null | jq -r '.status.conditions[] | select(.type == "Released") | .reason' 2>/dev/null); \
			if [ "$$RELEASE_STATUS" = "Succeeded" ]; then \
				echo "Status: Succeeded"; \
			elif [ "$$RELEASE_STATUS" = "Failed" ]; then \
				echo "Status: Failed"; \
				FAILURE_MSG=$$(oc get release "$(NAME)" -n submariner-tenant -o json 2>/dev/null | jq -r '.status.conditions[] | select(.type == "Released") | .message' 2>/dev/null); \
				echo "Message: $$FAILURE_MSG"; \
			else \
				echo "Status: Running"; \
			fi; \
		else \
			echo "No pipeline run yet"; \
		fi; \
		echo ""; \
		echo "Last updated: $$(date)"; \
		sleep 5; \
	done
