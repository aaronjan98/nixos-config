#!/usr/bin/env bash
set -euo pipefail

# sync-machine.sh — pull or check git layers when switching laptops.
#
# Documents and Pictures are handled by Syncthing in the background; this
# script only touches the git-tracked layers that need explicit pull/push.
#
# Usage:
#   sync-machine.sh --arrive   (run when sitting down at this machine)
#   sync-machine.sh --leave    (run before switching to another machine)
#
# Arrive: pulls git repos + reconstructs workspace
# Leave:  warns about any uncommitted git changes

ZETTELKASTEN="${ZETTELKASTEN:-${HOME}/Repositories/self-hosted/zettelkasten}"
NIXOS_CONFIG="${HOME}/nixos-config"
PASS_DIR="${HOME}/.password-store"
DOTFILES_DIR="${HOME}/.dotfiles"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ─── git helpers ─────────────────────────────────────────────────────────────

git_pull() {
    local name="$1" dir="$2"
    log "Pulling ${name}..."
    if [[ ! -d "${dir}" ]]; then
        warn "${name}: not found at ${dir} — skipping."
        return
    fi
    git -C "${dir}" pull --ff-only 2>&1 \
        || warn "${name}: could not fast-forward (diverged?). Pull manually."
}

dotfiles_pull() {
    log "Pulling dotfiles..."
    [[ -d "${DOTFILES_DIR}" ]] || { warn "dotfiles bare repo not found."; return; }
    git --git-dir="${DOTFILES_DIR}" --work-tree="${HOME}" \
        pull home main --ff-only 2>&1 \
        || warn "dotfiles: could not fast-forward. Pull manually with: dot pull home main"
}

check_uncommitted() {
    local name="$1" dir="$2"
    [[ -d "${dir}/.git" ]] || return 0
    if ! git -C "${dir}" diff --quiet 2>/dev/null \
        || ! git -C "${dir}" diff --cached --quiet 2>/dev/null; then
        warn "${name}: has uncommitted changes — commit and push before leaving."
    fi
}

# ─── commands ────────────────────────────────────────────────────────────────

cmd_arrive() {
    git_pull "nixos-config" "${NIXOS_CONFIG}"

    log "Restoring workspace routing files from snapshot..."
    bash "${NIXOS_CONFIG}/scripts/bootstrap-workspace.sh"

    dotfiles_pull
    git_pull "pass" "${PASS_DIR}"
    git_pull "zettelkasten" "${ZETTELKASTEN}"

    log "Syncing workspace repos..."
    bash "${NIXOS_CONFIG}/scripts/sync-workspace-repos.sh"

    log "Arrive sync complete."
    info "Documents and Pictures sync continuously via Syncthing — no action needed here."
    info "If nixos-config changed, run: nrs"
    info "Source your shell if aliases changed: source ~/.bashrc"
}

cmd_leave() {
    log "Checking for uncommitted changes..."
    check_uncommitted "nixos-config" "${NIXOS_CONFIG}"
    check_uncommitted "pass"         "${PASS_DIR}"
    check_uncommitted "zettelkasten" "${ZETTELKASTEN}"

    log "Leave sync complete."
    info "Push git repos before closing: g pushall / dot pushall"
    info "Documents and Pictures are already syncing via Syncthing."
}

# ─── main ────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --arrive) cmd_arrive ;;
    --leave)  cmd_leave  ;;
    *)
        printf 'Usage: %s --arrive | --leave\n' "$(basename "$0")"
        printf '\n'
        printf '  --arrive  pull all git layers when sitting down at this machine\n'
        printf '  --leave   warn about uncommitted changes\n'
        exit 1
        ;;
esac
