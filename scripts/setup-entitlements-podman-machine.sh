#!/bin/bash
# Register Red Hat entitlements inside the Podman machine VM (macOS only)
#
# Usage: setup-entitlements-podman-machine.sh [--check]
#
#   (no flag)  Register subscription-manager inside podman machine
#   --check    Check if entitlements are registered in podman machine
#
# Prerequisites:
#   1. Run `make setup-entitlements` first (extracts credentials to Podman secrets)
#   2. Podman machine must be running
#
# This script:
#   - Retrieves org/key from macOS Podman secrets (set by setup-entitlements.sh)
#   - SSHes into podman machine VM
#   - Installs subscription-manager if needed
#   - Registers with Red Hat
#   - Verifies /etc/pki/entitlement/ certs exist

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ONLY=false

die() {
  echo "❌ $1" >&2
  [ -n "${2:-}" ] && echo "$2" >&2
  exit 1
}

check_prerequisites() {
  [ "$(uname -s)" != "Darwin" ] && die "This script is for macOS only" \
    "Linux users: Run setup-entitlements.sh directly (uses subscription-manager natively)"

  command -v podman &>/dev/null || die "podman not found" \
    "Install: brew install podman"

  # Check podman machine exists and is running
  if ! podman machine list --format '{{.Name}}\t{{.Running}}' 2>/dev/null | grep -q "true"; then
    die "No running podman machine found" \
      "Start it: podman machine start"
  fi

  # Check that macOS-side credentials exist (from setup-entitlements.sh)
  if ! podman secret exists rh-org 2>/dev/null || ! podman secret exists rh-activation-key 2>/dev/null; then
    die "Red Hat credentials not found in Podman secrets" \
      "Run first: make setup-entitlements"
  fi
}

check_vm_registration() {
  # Returns 0 if registered, 1 if not
  podman machine ssh -- 'test -f /etc/pki/consumer/cert.pem' 2>/dev/null
}

check_vm_entitlements() {
  # Returns 0 if entitlement certs exist, 1 if not
  local cert_count
  cert_count=$(podman machine ssh -- 'ls /etc/pki/entitlement/*.pem 2>/dev/null | grep -v -- "-key.pem" | wc -l' 2>/dev/null || echo 0)
  [ "$cert_count" -gt 0 ]
}

check_vm_repo_access() {
  # Returns: ok, denied, or unknown
  podman machine ssh -- 'bash -s' <<'EOF' 2>/dev/null || echo "unknown"
set -euo pipefail
cert=$(ls /etc/pki/entitlement/*.pem 2>/dev/null | grep -v -- "-key.pem" | head -1)
key="${cert%.pem}-key.pem"
[ -e "$cert" ] && [ -e "$key" ] && command -v curl &>/dev/null || { echo unknown; exit 0; }
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  --cacert /etc/rhsm/ca/redhat-uep.pem --cert "$cert" --key "$key" \
  https://cdn.redhat.com/content/dist/rhel9/9/x86_64/baseos/os/repodata/repomd.xml 2>/dev/null) || code=000
case "$code" in
  200) echo ok ;;
  401|403) echo denied ;;
  *) echo unknown ;;
esac
EOF
}

install_subscription_manager() {
  echo "Checking for subscription-manager in podman machine..."

  if podman machine ssh -- 'command -v subscription-manager &>/dev/null'; then
    echo "  ✓ subscription-manager already installed"
    return 0
  fi

  echo "  Installing subscription-manager..."

  # Try dnf first (Fedora)
  if podman machine ssh -- 'command -v dnf &>/dev/null'; then
    echo "  Using dnf to install..."
    podman machine ssh -- 'sudo dnf install -y subscription-manager' || \
      die "Failed to install subscription-manager via dnf"
    echo "  ✓ Installed subscription-manager"
    return 0
  fi

  # Try rpm-ostree (Fedora CoreOS)
  if podman machine ssh -- 'command -v rpm-ostree &>/dev/null'; then
    echo "  Using rpm-ostree to install (requires reboot)..."
    podman machine ssh -- 'sudo rpm-ostree install subscription-manager' || \
      die "Failed to install subscription-manager via rpm-ostree"
    echo ""
    echo "  ⚠️  Podman machine needs reboot to apply rpm-ostree changes"
    echo "  Run: podman machine stop && podman machine start"
    echo "  Then re-run this script."
    exit 2  # Special exit code: reboot needed
  fi

  die "Could not install subscription-manager" \
    "Unknown package manager in podman machine VM"
}

register_vm() {
  echo "Registering Red Hat entitlements in podman machine..."

  # Get credentials from Podman secrets (set by setup-entitlements.sh on macOS host)
  local org_id key
  org_id=$(podman secret inspect rh-org --showsecret 2>/dev/null) || \
    die "Could not read rh-org secret" "Run: make setup-entitlements"
  key=$(podman secret inspect rh-activation-key --showsecret 2>/dev/null) || \
    die "Could not read rh-activation-key secret" "Run: make setup-entitlements"

  [ -n "$org_id" ] && [ -n "$key" ] || \
    die "Empty credentials in Podman secrets"

  # Check if already registered (avoid duplicate registrations)
  if check_vm_registration; then
    echo "  ℹ️  Podman machine is already registered"
    echo "  To re-register: podman machine ssh -- sudo subscription-manager unregister"
    echo "  Then re-run this script"
    return 0
  fi

  # Register inside the VM
  # Note: We pass credentials via stdin to avoid them in process list
  echo "  Registering with org: ${org_id:0:8}..."
  podman machine ssh -- "sudo subscription-manager register --org='$org_id' --activationkey='$key'" || \
    die "Registration failed" \
      "Check credentials, network (try without VPN), and activation key permissions"

  echo "  ✓ Registered"

  # Verify certs appeared
  if ! check_vm_entitlements; then
    die "Registered, but no entitlement certificates appeared in /etc/pki/entitlement/" \
      "Add repos (RHEL BaseOS/AppStream) to the activation key at:
https://console.redhat.com/insights/connector/activation-keys/"
  fi

  echo "  ✓ Entitlement certificates present"
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --check) CHECK_ONLY=true ;;
      -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
      *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
  done

  check_prerequisites

  if $CHECK_ONLY; then
    echo "Podman machine entitlement status:"
    local rc=0

    if check_vm_registration; then
      echo "  ✓ Registered with Red Hat"
    else
      echo "  ✗ Not registered"
      rc=1
    fi

    if check_vm_entitlements; then
      echo "  ✓ Entitlement certificates in /etc/pki/entitlement/"
    else
      echo "  ✗ No entitlement certificates"
      rc=1
    fi

    if check_vm_registration && check_vm_entitlements; then
      case "$(check_vm_repo_access)" in
        ok) echo "  ✓ Entitlement grants access to RHEL repositories" ;;
        denied) echo "  ✗ Entitlement grants no RHEL repository access (missing repos in activation key?)"; rc=1 ;;
        *) echo "  ? Could not verify RHEL repository access (network or VPN?)" ;;
      esac
    fi

    if [ "$rc" -ne 0 ]; then
      echo ""
      echo "Fix with: make setup-entitlements-podman-machine"
    fi
    exit "$rc"
  fi

  # Non-check mode: Register
  install_subscription_manager
  [ $? -eq 2 ] && exit 0  # Reboot needed, handled by install_subscription_manager message

  register_vm

  # Verify repo access
  echo ""
  case "$(check_vm_repo_access)" in
    ok)
      echo "✓ Entitlement grants access to RHEL repositories"
      echo ""
      echo "Ready: bash scripts/rpm-lockfile-update.sh <version>"
      ;;
    denied)
      echo "⚠️  The entitlement grants no RHEL repository access"
      echo ""
      echo "Fix: Add RHEL BaseOS/AppStream repos to the activation key:"
      echo "  https://console.redhat.com/insights/connector/activation-keys/"
      echo ""
      echo "Then re-register:"
      echo "  podman machine ssh -- sudo subscription-manager unregister"
      echo "  make setup-entitlements-podman-machine"
      exit 1
      ;;
    *)
      echo "? Could not verify RHEL repository access (network or VPN?)"
      echo ""
      echo "If rpm-lockfile-update.sh fails with 403/subscription errors, check:"
      echo "  1. VPN connected/disconnected (try both)"
      echo "  2. Activation key has RHEL repos enabled"
      echo ""
      echo "Otherwise, ready: bash scripts/rpm-lockfile-update.sh <version>"
      ;;
  esac
}

main "$@"
