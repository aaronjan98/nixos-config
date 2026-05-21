#!/usr/bin/env bash
set -euo pipefail

# Run as AJ after the first successful nixos-rebuild switch.
# Sets up git remotes, dotfiles checkout, GPG trust, SSH key, Tailscale.
#
# Usage: bash ~/nixos-config/scripts/post-rebuild-setup.sh

NIXOS_CONFIG_DIR="${HOME}/nixos-config"
DOTFILES_DIR="${HOME}/.dotfiles"
HOMELAB_GIT="ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos"
GITHUB_USER="aaronjan98"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ─── steps ───────────────────────────────────────────────────────────────────

set_gpg_trust() {
    log "Setting GPG key trust to ultimate..."
    local fprint
    fprint="$(gpg --with-colons --fingerprint 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')"
    if [[ -z "${fprint}" ]]; then
        warn "No GPG key found — skipping. Re-run after importing your key."
        return
    fi
    printf '%s:6:\n' "${fprint}" | gpg --import-ownertrust
    info "Ultimate trust set for ${fprint}."
}

setup_nixos_config_remotes() {
    log "Setting up nixos-config git remotes..."
    [[ -d "${NIXOS_CONFIG_DIR}/.git" ]] \
        || die "${NIXOS_CONFIG_DIR} not found. Clone it first:
  git clone https://github.com/${GITHUB_USER}/nixos-config ~/nixos-config"

    local r="${NIXOS_CONFIG_DIR}"

    # If cloned via HTTPS as 'origin', rename and switch to SSH
    if git -C "${r}" remote get-url origin 2>/dev/null | grep -q 'github.com'; then
        git -C "${r}" remote set-url origin "git@github.com:${GITHUB_USER}/nixos-config.git"
        git -C "${r}" remote rename origin hub 2>/dev/null || true
    fi

    git -C "${r}" remote get-url hub   2>/dev/null \
        || git -C "${r}" remote add hub   "git@github.com:${GITHUB_USER}/nixos-config.git"
    git -C "${r}" remote get-url home  2>/dev/null \
        || git -C "${r}" remote add home  "${HOMELAB_GIT}/nixos-config.git"
    git -C "${r}" remote get-url local 2>/dev/null \
        || git -C "${r}" remote add local "ssh://git@localhost/srv/git/repos/nixos-config.git"

    info "Remotes: $(git -C "${r}" remote | tr '\n' ' ')"
}

setup_dotfiles() {
    log "Setting up dotfiles..."

    if [[ ! -d "${DOTFILES_DIR}" ]]; then
        info "Cloning dotfiles bare repo..."
        git clone --bare "${HOMELAB_GIT}/dotfiles.git" "${DOTFILES_DIR}"
        git --git-dir="${DOTFILES_DIR}" config status.showUntrackedFiles no
    fi

    # Add remotes
    git --git-dir="${DOTFILES_DIR}" remote get-url home  2>/dev/null \
        || git --git-dir="${DOTFILES_DIR}" remote add home  "${HOMELAB_GIT}/dotfiles.git"
    git --git-dir="${DOTFILES_DIR}" remote get-url hub   2>/dev/null \
        || git --git-dir="${DOTFILES_DIR}" remote add hub   "git@github.com:${GITHUB_USER}/dotfiles.git"
    git --git-dir="${DOTFILES_DIR}" remote get-url local 2>/dev/null \
        || git --git-dir="${DOTFILES_DIR}" remote add local "ssh://git@localhost:/srv/git/repos/dotfiles.git"

    info "Checking out dotfiles..."
    # Attempt checkout; on conflict, back up the offending files and retry
    if ! git --git-dir="${DOTFILES_DIR}" --work-tree="${HOME}" checkout 2>/dev/null; then
        local backup="${HOME}/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
        warn "Conflicts detected — backing up to ${backup}/"
        mkdir -p "${backup}"
        git --git-dir="${DOTFILES_DIR}" --work-tree="${HOME}" checkout 2>&1 \
            | awk '/^\s/{print $1}' \
            | while IFS= read -r f; do
                mkdir -p "${backup}/$(dirname "${f}")"
                mv "${HOME}/${f}" "${backup}/${f}" 2>/dev/null || true
              done
        git --git-dir="${DOTFILES_DIR}" --work-tree="${HOME}" checkout
    fi

    info "Dotfiles checked out."
}

generate_ed25519_key() {
    local keyfile="${HOME}/.ssh/id_ed25519"
    if [[ -f "${keyfile}" ]]; then
        info "ed25519 key already exists at ${keyfile}."
        return
    fi
    log "Generating ed25519 SSH key for this machine..."
    ssh-keygen -t ed25519 -C "aj@$(hostname)" -f "${keyfile}" -N ""

    cat <<EOF

  ==> Add this public key to hosts/$(hostname)/configuration.nix:

      aj.gitServer.authorizedKeys = [
        "$(cat "${keyfile}.pub")"
      ];

  Then commit, push, and run: nrs
EOF
}

auth_tailscale() {
    log "Checking Tailscale..."
    if tailscale status >/dev/null 2>&1; then
        info "Already connected: $(tailscale status --self | head -1)"
    else
        info "Not connected. Running tailscale up..."
        sudo tailscale up
    fi
}

run_bootstrap_workspace() {
    log "Running bootstrap-new-machine.sh (workspace + git server seed)..."
    local script="${NIXOS_CONFIG_DIR}/scripts/bootstrap-new-machine.sh"
    if [[ -x "${script}" ]]; then
        bash "${script}"
    else
        warn "bootstrap-new-machine.sh not found at ${script}."
    fi
}

# ─── main ────────────────────────────────────────────────────────────────────

main() {
    [[ "${EUID}" -ne 0 ]] || die "Run as aj, not root."

    set_gpg_trust
    setup_nixos_config_remotes
    setup_dotfiles
    generate_ed25519_key
    auth_tailscale
    run_bootstrap_workspace

    log "Post-rebuild setup complete."
    info "Source your shell: source ~/.bashrc"
}

main "$@"
