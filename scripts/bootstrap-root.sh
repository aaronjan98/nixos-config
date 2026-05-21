#!/usr/bin/env bash
set -euo pipefail

# Run as ROOT on a fresh NixOS basic install (nixos-install --no-flake).
# Handles everything from GPG import through the first nixos-rebuild switch.
#
# Pre-conditions:
#   1. nixos-config cloned to /root/nixos-config:
#        nix-shell -p git --run \
#          "git clone https://github.com/aaronjan98/nixos-config /root/nixos-config"
#   2. Run inside nix-shell with required tools:
#        nix-shell -p gnupg pass git netcat-gnu pinentry-curses age
#        bash /root/nixos-config/scripts/bootstrap-root.sh <flake-hostname>
#
# Usage: bootstrap-root.sh <flake-hostname>
#   e.g. bootstrap-root.sh framework-13

NIXOS_CONFIG_DIR="/root/nixos-config"
PASS_DIR="/root/.password-store"
BUNDLE_DIR="/tmp/secrets-bundle"
NC_PORT=9999

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ask() {
    local prompt="$1" default="${2:-}" reply
    read -r -p "${prompt}${default:+ [${default}]}: " reply
    printf '%s' "${reply:-${default}}"
}

ask_yn() {
    local reply
    read -r -p "$1 [y/N]: " reply
    [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# ─── pre-flight ──────────────────────────────────────────────────────────────

check_root() {
    [[ "${EUID}" -eq 0 ]] || die "Must be run as root."
}

check_tools() {
    local missing=()
    for t in gpg pass git nc age-keygen pinentry-curses; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
        die "Missing tools: ${missing[*]}
Run inside:
  nix-shell -p gnupg pass git netcat-gnu pinentry-curses age
  bash ${NIXOS_CONFIG_DIR}/scripts/bootstrap-root.sh <flake-hostname>"
    fi
}

check_repo() {
    [[ -d "${NIXOS_CONFIG_DIR}/.git" ]] || die \
        "nixos-config not at ${NIXOS_CONFIG_DIR}. Clone it first:
  nix-shell -p git --run \\
    \"git clone https://github.com/aaronjan98/nixos-config ${NIXOS_CONFIG_DIR}\""
}

# ─── steps ───────────────────────────────────────────────────────────────────

configure_pinentry() {
    log "Configuring pinentry-curses for GPG..."
    mkdir -p /root/.gnupg
    chmod 700 /root/.gnupg
    printf 'pinentry-program %s\n' "$(command -v pinentry-curses)" \
        > /root/.gnupg/gpg-agent.conf
    gpgconf --kill gpg-agent 2>/dev/null || true
    info "Done."
}

receive_secrets_bundle() {
    log "Receiving secrets bundle from ThinkPad..."

    # Open NixOS firewall; fall back to raw iptables on non-NixOS live envs
    iptables -I nixos-fw -p tcp --dport "${NC_PORT}" -j nixos-fw-accept 2>/dev/null \
        || iptables -I INPUT -p tcp --dport "${NC_PORT}" -j ACCEPT 2>/dev/null \
        || warn "Could not open firewall — bundle transfer may fail."

    mkdir -p "${BUNDLE_DIR}"

    local myip
    myip="$(ip route get 8.8.8.8 2>/dev/null | awk '/src/{print $7; exit}' || echo '<unknown>')"

    printf '\n'
    printf '  This machine IP : %s\n' "${myip}"
    printf '\n'
    printf '  On ThinkPad, run:\n'
    printf '    bash ~/nixos-config/scripts/send-secrets-to-new-machine.sh %s\n' "${myip}"
    printf '\n'
    info "Listening on port ${NC_PORT} — waiting for ThinkPad..."

    nc -l "${NC_PORT}" | tar xzf - -C "${BUNDLE_DIR}"

    iptables -D nixos-fw -p tcp --dport "${NC_PORT}" -j nixos-fw-accept 2>/dev/null \
        || iptables -D INPUT -p tcp --dport "${NC_PORT}" -j ACCEPT 2>/dev/null \
        || true

    info "Bundle received."
}

install_ssh_key() {
    log "Installing SSH key..."
    [[ -f "${BUNDLE_DIR}/id_rsa" ]] || die "id_rsa missing from bundle."
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    cp "${BUNDLE_DIR}/id_rsa" /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa
    [[ -f "${BUNDLE_DIR}/id_rsa.pub" ]] \
        && cp "${BUNDLE_DIR}/id_rsa.pub" /root/.ssh/id_rsa.pub \
        && chmod 644 /root/.ssh/id_rsa.pub || true
    info "Installed to /root/.ssh/id_rsa."
}

import_gpg_keys() {
    log "Importing GPG keys (passphrase prompt will appear)..."
    [[ -f "${BUNDLE_DIR}/gpg-pub.asc" ]]  || die "gpg-pub.asc missing from bundle."
    [[ -f "${BUNDLE_DIR}/gpg-priv.asc" ]] || die "gpg-priv.asc missing from bundle."
    gpg --import "${BUNDLE_DIR}/gpg-pub.asc"
    gpg --import "${BUNDLE_DIR}/gpg-priv.asc"
    info "GPG keys imported."
}

set_gpg_trust() {
    log "Setting GPG key trust to ultimate..."
    local fprint
    fprint="$(gpg --with-colons --fingerprint 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')"
    [[ -n "${fprint}" ]] || { warn "No GPG fingerprint found. Skipping trust."; return; }
    printf '%s:6:\n' "${fprint}" | gpg --import-ownertrust
    info "Ultimate trust set for ${fprint}."
}

clone_password_store() {
    log "Cloning password store..."
    if [[ -d "${PASS_DIR}/.git" ]]; then
        info "Already exists at ${PASS_DIR}. Pulling..."
        git -C "${PASS_DIR}" pull
        return
    fi
    PASSWORD_STORE_DIR="${PASS_DIR}" \
        git clone ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git \
        "${PASS_DIR}"
    info "Cloned to ${PASS_DIR}."
}

restore_secrets() {
    log "Running restore-secrets.sh..."
    HOME=/root PASSWORD_STORE_DIR="${PASS_DIR}" \
        bash "${NIXOS_CONFIG_DIR}/scripts/restore-secrets.sh"
}

ensure_age_key() {
    log "Checking SOPS age key..."
    local key_file="/var/lib/sops-nix/key.txt"

    if [[ -f "${key_file}" ]]; then
        info "Age key present at ${key_file}."
        return
    fi

    info "Not found — generating a new age key for this machine..."
    local tmp_key
    tmp_key="$(mktemp)"
    trap 'rm -f "${tmp_key}"' RETURN

    age-keygen -o "${tmp_key}"
    local pubkey
    pubkey="$(grep '# public key:' "${tmp_key}" | awk '{print $NF}')"

    mkdir -p "$(dirname "${key_file}")"
    install -m 600 "${tmp_key}" "${key_file}"

    # Store in pass for future bootstraps
    PASSWORD_STORE_DIR="${PASS_DIR}" \
        pass insert --multiline "laptop/$(hostname)/sops/age" < "${tmp_key}"

    cat <<EOF

  ┌─────────────────────────────────────────────────────────────────┐
  │  NEW AGE KEY — ACTION REQUIRED ON THINKPAD BEFORE CONTINUING    │
  ├─────────────────────────────────────────────────────────────────┤
  │  Public key:                                                    │
  │    ${pubkey}
  │                                                                 │
  │  On ThinkPad, run:                                              │
  │    cd ~/nixos-config                                            │
  │    sops --rotate --add-age ${pubkey} \\
  │      secrets/users.yaml secrets/hf-token.yaml \\               │
  │      secrets/context7.yaml secrets/opencode.yaml \\            │
  │      secrets/forgejo.yaml                                      │
  │    g ci -am 'secrets: add $(hostname) age key'                  │
  │    g pushall                                                    │
  └─────────────────────────────────────────────────────────────────┘

EOF
    read -r -p "Press Enter after pushing the updated secrets..." _
    log "Pulling updated secrets..."
    git -C "${NIXOS_CONFIG_DIR}" pull
}

sync_distfiles() {
    log "Syncing Wolfram distfiles from NAS..."
    if bash "${NIXOS_CONFIG_DIR}/scripts/sync-distfiles.sh" wolfram; then
        local wolfram_file
        wolfram_file="$(find /var/lib/distfiles/wolfram -name '*.sh' 2>/dev/null | head -1)"
        if [[ -n "${wolfram_file}" ]]; then
            info "Adding to Nix store: ${wolfram_file}"
            nix --extra-experimental-features 'nix-command' store add-file "${wolfram_file}" \
                || warn "nix store add-file failed — Wolfram build may fail."
        fi
    else
        warn "Distfiles sync failed (NAS unreachable?). Wolfram build will fail."
        warn "Run 'bash ${NIXOS_CONFIG_DIR}/scripts/sync-distfiles.sh wolfram' once NAS is reachable."
    fi
}

nixos_rebuild() {
    local host="$1"
    log "nixos-rebuild switch --flake ${NIXOS_CONFIG_DIR}#${host}"
    nixos-rebuild switch --flake "${NIXOS_CONFIG_DIR}#${host}"
}

cleanup() {
    rm -rf "${BUNDLE_DIR}"
}

# ─── main ────────────────────────────────────────────────────────────────────

main() {
    local flake_host="${1:-}"

    check_root
    check_tools
    check_repo

    [[ -n "${flake_host}" ]] \
        || flake_host="$(ask 'Flake hostname (e.g. framework-13)')"
    [[ -n "${flake_host}" ]] || die "Flake hostname required."

    configure_pinentry
    receive_secrets_bundle
    install_ssh_key
    import_gpg_keys
    set_gpg_trust
    clone_password_store
    restore_secrets
    ensure_age_key

    if ask_yn "Sync Wolfram distfiles from NAS now?"; then
        sync_distfiles
    else
        warn "Skipping distfiles. Run sync-distfiles.sh before nixos-rebuild if Wolfram is needed."
    fi

    cleanup
    nixos_rebuild "${flake_host}"

    cat <<EOF

==> First rebuild complete.

Next: log in as aj, then run:
  git clone https://github.com/aaronjan98/nixos-config ~/nixos-config
  bash ~/nixos-config/scripts/post-rebuild-setup.sh
EOF
}

main "$@"
