#!/usr/bin/env bash
set -euo pipefail

# Run on the SENDING machine (e.g. ThinkPad) while bootstrap-root.sh waits
# on the new machine. Bundles SSH key + GPG keys into a tar archive and
# sends it via netcat.
#
# Usage: send-secrets-to-new-machine.sh <new-machine-ip> [port]

NEW_MACHINE_IP="${1:?Usage: $0 <new-machine-ip> [port]}"
PORT="${2:-9999}"
SSH_KEY="${HOME}/.ssh/id_rsa"

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v gpg >/dev/null 2>&1 || die "gpg not found."
command -v nc  >/dev/null 2>&1 || die "nc not found. Install netcat-gnu."
[[ -f "${SSH_KEY}" ]] || die "SSH key not found at ${SSH_KEY}."

GPG_KEY_ID="$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec/{print $5; exit}')"
[[ -n "${GPG_KEY_ID}" ]] || die "No GPG secret key found."

log "GPG key: ${GPG_KEY_ID}"
log "Destination: ${NEW_MACHINE_IP}:${PORT}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

log "Exporting GPG keys..."
gpg --armor --export "${GPG_KEY_ID}" > "${tmpdir}/gpg-pub.asc"
gpg --armor --export-secret-keys "${GPG_KEY_ID}" > "${tmpdir}/gpg-priv.asc"

log "Bundling SSH key..."
cp "${SSH_KEY}" "${tmpdir}/id_rsa"
[[ -f "${SSH_KEY}.pub" ]] && cp "${SSH_KEY}.pub" "${tmpdir}/id_rsa.pub" || true

log "Sending to ${NEW_MACHINE_IP}:${PORT}..."
tar czf - -C "${tmpdir}" . | nc -N "${NEW_MACHINE_IP}" "${PORT}"

log "Done. Switch to the new machine — bootstrap will continue automatically."
