#!/bin/bash
# Helpers for the team entitlement bundle: the shared Red Hat org ID and
# activation key, sealed with GnuPG symmetric encryption (AES-256, iterated
# and salted SHA-512 key derivation, integrity-protected) and committed as
# secrets/entitlements.asc. One long random team password opens it.
#
# Sourced by setup-entitlements.sh and seal-entitlements.sh.
# Test hooks: ENTITLEMENT_BUNDLE, ENTITLEMENT_PASSWORD, XDG_CONFIG_HOME.

# shellcheck disable=SC2034  # variables are consumed by the scripts that source this
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_FILE="${ENTITLEMENT_BUNDLE:-$(cd "$_LIB_DIR/../.." && pwd)/secrets/entitlements.asc}"
PASSWORD_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/submariner-release-management/entitlement-password"
MIN_PASSWORD_LEN=43 # ~256 bits of base64

# Bundle fields we accept. Anything else in the file is ignored.
BUNDLE_KEYS="RH_ORG RH_ACTIVATION_KEY RH_REGISTRY_USER RH_REGISTRY_PASSWORD"

# Run gpg against a throwaway keyring so we never touch the user's own.
_gpg() {
  local home rc=0
  home=$(mktemp -d) || return 1
  GNUPGHOME="$home" gpg --batch --quiet --no-tty --pinentry-mode loopback "$@" || rc=$?
  rm -rf "$home"
  return "$rc"
}

# bundle_encrypt PASSWORD OUTFILE  (plaintext on stdin)
bundle_encrypt() {
  _gpg --passphrase-file <(printf '%s' "$1") --symmetric --armor \
    --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 \
    --s2k-count 65011712 --compress-algo none -o "$2"
}

# bundle_decrypt PASSWORD FILE  (plaintext on stdout; stderr silenced)
bundle_decrypt() {
  _gpg --passphrase-file <(printf '%s' "$1") --decrypt "$2" 2>/dev/null
}

cached_password() {
  [ -s "$PASSWORD_FILE" ] && cat "$PASSWORD_FILE"
  return 0
}

save_password() {
  local dir
  dir=$(dirname "$PASSWORD_FILE")
  mkdir -p "$dir" && chmod 700 "$dir"
  (umask 077 && printf '%s' "$1" > "$PASSWORD_FILE")
}

# parse_bundle: read plaintext on stdin, export the allowed KEY=VALUE pairs
# as BUNDLE_<KEY>. Never evaluated as shell.
parse_bundle() {
  local line k v
  while IFS= read -r line || [ -n "$line" ]; do
    k=${line%%=*}
    v=${line#*=}
    case " $BUNDLE_KEYS " in
      *" $k "*) printf -v "BUNDLE_$k" '%s' "$v" ;;
    esac
  done
}

# store_password_keychain: Store password in macOS Keychain
# Args: $1=password
store_password_keychain() {
  local pw="$1"
  local service="submariner-release-management"
  local account="entitlement-bundle"

  # Delete any existing entry first
  security delete-generic-password -s "$service" -a "$account" 2>/dev/null || true

  # Add new password to keychain
  security add-generic-password -s "$service" -a "$account" -w "$pw" -U
}

# get_password_keychain: Retrieve password from macOS Keychain
# Returns: password on stdout, exit 1 if not found
get_password_keychain() {
  local service="submariner-release-management"
  local account="entitlement-bundle"

  security find-generic-password -s "$service" -a "$account" -w 2>/dev/null
}

# extract_bundle_to_podman_secrets: Extract and store credentials securely on macOS
# Uses macOS Keychain for the bundle password and Podman secrets for credentials
# Args: $1=entitlement_dir (created but stores only metadata, not plaintext)
extract_bundle_to_podman_secrets() {
  local ent_dir="$1"
  local password plaintext

  [ -s "$BUNDLE_FILE" ] || return 1

  # Try macOS Keychain first, then cached file, then prompt
  if command -v security &>/dev/null; then
    password=$(get_password_keychain 2>/dev/null) || password=""
  fi

  if [ -z "$password" ]; then
    password=$(cached_password)
  fi

  if [ -z "$password" ]; then
    read -rsp "Enter team entitlement password: " password
    echo >&2
    [ ${#password} -lt "$MIN_PASSWORD_LEN" ] && return 1
  fi

  plaintext=$(bundle_decrypt "$password" "$BUNDLE_FILE") || {
    echo "Failed to decrypt bundle - wrong password?" >&2
    return 1
  }

  # Store password in Keychain for next time (more secure than plaintext file)
  if command -v security &>/dev/null; then
    store_password_keychain "$password" || {
      echo "Warning: Could not store password in Keychain, falling back to file" >&2
      save_password "$password"
    }
  else
    save_password "$password"
  fi

  # Parse bundle to get credentials
  parse_bundle <<<"$plaintext"
  eval "$(declare -p $(printf 'BUNDLE_%s ' $BUNDLE_KEYS) 2>/dev/null)"

  # Store credentials as Podman secrets (if podman available)
  if command -v podman &>/dev/null; then
    # Remove old secrets if they exist
    podman secret rm rh-org 2>/dev/null || true
    podman secret rm rh-activation-key 2>/dev/null || true
    podman secret rm rh-registry-user 2>/dev/null || true
    podman secret rm rh-registry-password 2>/dev/null || true

    # Create new secrets
    printf '%s' "${BUNDLE_RH_ORG}" | podman secret create rh-org - >/dev/null
    printf '%s' "${BUNDLE_RH_ACTIVATION_KEY}" | podman secret create rh-activation-key - >/dev/null
    [ -n "${BUNDLE_RH_REGISTRY_USER:-}" ] && printf '%s' "${BUNDLE_RH_REGISTRY_USER}" | podman secret create rh-registry-user - >/dev/null || true
    [ -n "${BUNDLE_RH_REGISTRY_PASSWORD:-}" ] && printf '%s' "${BUNDLE_RH_REGISTRY_PASSWORD}" | podman secret create rh-registry-password - >/dev/null || true
  fi

  # Create entitlement directory with metadata only (no plaintext secrets)
  mkdir -p "$ent_dir"
  cat > "$ent_dir/README.txt" <<'EOF'
Red Hat entitlements for macOS

Credentials are stored securely:
- Bundle password: macOS Keychain (service: submariner-release-management)
- Org ID & activation key: Podman secrets (rh-org, rh-activation-key)
- Registry credentials: Podman secrets (rh-registry-user, rh-registry-password)

To use in containers, inject secrets as environment variables:
  podman run --secret rh-org,type=env,target=RH_ORG \
             --secret rh-activation-key,type=env,target=RH_ACTIVATION_KEY \
             ...

To view secrets:
  podman secret inspect rh-org

To rotate (after changing activation key):
  make setup-entitlements FORCE=1
EOF

  return 0
}

# get_credentials_from_bundle: Decrypt bundle and export credentials as env vars
# For scripts that need credentials (prints export commands to eval)
get_credentials_from_bundle() {
  local password plaintext

  [ -s "$BUNDLE_FILE" ] || return 1

  # Try Keychain first
  if command -v security &>/dev/null; then
    password=$(get_password_keychain 2>/dev/null) || password=""
  fi

  if [ -z "$password" ]; then
    password=$(cached_password)
  fi

  [ -n "$password" ] || return 1

  plaintext=$(bundle_decrypt "$password" "$BUNDLE_FILE") || return 1
  parse_bundle <<<"$plaintext"

  # Print export commands for caller to eval
  printf 'export RH_ORG="%s"\n' "${BUNDLE_RH_ORG}"
  printf 'export RH_ACTIVATION_KEY="%s"\n' "${BUNDLE_RH_ACTIVATION_KEY}"
  [ -n "${BUNDLE_RH_REGISTRY_USER:-}" ] && printf 'export RH_REGISTRY_USER="%s"\n' "${BUNDLE_RH_REGISTRY_USER}"
  [ -n "${BUNDLE_RH_REGISTRY_PASSWORD:-}" ] && printf 'export RH_REGISTRY_PASSWORD="%s"\n' "${BUNDLE_RH_REGISTRY_PASSWORD}"
}

# Legacy function - kept for compatibility, now uses secure implementation
extract_bundle_to_dir() {
  extract_bundle_to_podman_secrets "$@"
}
