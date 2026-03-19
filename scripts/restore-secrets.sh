#!/usr/bin/env bash
set -euo pipefail

HOSTNAME_SHORT="$(hostname)"
PASS_SSH_PREFIX="laptop/${HOSTNAME_SHORT}/ssh"
PASS_AGE_ENTRY="laptop/thinkpad-t14-nixos/sops/age"

SSH_DIR="${HOME}/.ssh"
AGE_TARGET_DIR="/var/lib/sops-nix"
AGE_TARGET_FILE="${AGE_TARGET_DIR}/key.txt"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Required command not found: $1"
    exit 1
  }
}

pass_entry_exists() {
  pass show "$1" >/dev/null 2>&1
}

restore_ssh_file() {
  local name="$1"
  local dest="${SSH_DIR}/${name}"

  pass "${PASS_SSH_PREFIX}/${name}" > "${dest}"

  case "${name}" in
    *.pub|known_hosts|known_hosts.old|authorized_keys)
      chmod 644 "${dest}"
      ;;
    *)
      chmod 600 "${dest}"
      ;;
  esac

  log "Restored SSH file: ${dest}"
}

restore_known_ssh_files() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"

  local names=(
    authorized_keys
    calKeyPair.pem
    config
    id_ed25519.fedora
    id_ed25519.fedora.pub
    id_ed25519.jetra
    id_ed25519.jetra.pub
    id_ed25519.kamatera
    id_ed25519.kamatera.pub
    id_ed25519.linode
    id_ed25519.linode.pub
    id_ed25519.oreos
    id_ed25519.oreos.pub
    id_oracle.key
    id_oracle.key.pub
    id_rsa
    id_rsa.pub
    known_hosts
    known_hosts.old
  )

  local restored_any=0
  local name
  for name in "${names[@]}"; do
    if pass_entry_exists "${PASS_SSH_PREFIX}/${name}"; then
      restore_ssh_file "${name}"
      restored_any=1
    fi
  done

  if [[ "${restored_any}" -eq 0 ]]; then
    warn "No SSH files restored from pass prefix: ${PASS_SSH_PREFIX}"
    warn "Check hostname or pass entry naming."
  fi
}

restore_age_key() {
  if ! pass_entry_exists "${PASS_AGE_ENTRY}"; then
    warn "SOPS age key entry not found in pass: ${PASS_AGE_ENTRY}"
    return
  fi

  log "Restoring SOPS age key to ${AGE_TARGET_FILE}"
  sudo mkdir -p "${AGE_TARGET_DIR}"
  pass "${PASS_AGE_ENTRY}" | sudo tee "${AGE_TARGET_FILE}" >/dev/null
  sudo chmod 600 "${AGE_TARGET_FILE}"
  log "Restored SOPS age key"
}

main() {
  require_cmd gpg
  require_cmd pass
  require_cmd sudo

  log "Using hostname-derived SSH pass prefix: ${PASS_SSH_PREFIX}"
  log "Using fixed SOPS age pass entry: ${PASS_AGE_ENTRY}"

  restore_known_ssh_files
  restore_age_key

  log "Secrets restore complete"
}

main "$@"
