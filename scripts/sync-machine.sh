#!/usr/bin/env bash
set -euo pipefail

# sync-machine.sh — pull or push all synced data layers when switching laptops.
#
# Usage:
#   sync-machine.sh --arrive   (run when sitting down at this machine)
#   sync-machine.sh --leave    (run before switching to another machine)
#
# Arrive: pulls git repos + Documents from NAS + workspace repos
# Leave:  pushes Documents to NAS + warns about any uncommitted git changes

NAS_HOST="${NAS_HOST:-aj@qwerty.home}"
NAS_DOCS_REMOTE="${NAS_DOCS_REMOTE:-/mnt/storage/desktop-sync/Documents}"
NAS_PICS_REMOTE="${NAS_PICS_REMOTE:-/mnt/storage/desktop-sync/Pictures}"
LOCAL_DOCS="${LOCAL_DOCS:-${HOME}/Documents}"
LOCAL_PICS="${LOCAL_PICS:-${HOME}/Pictures}"
ZETTELKASTEN="${ZETTELKASTEN:-${HOME}/Repositories/self-hosted/zettelkasten}"
NIXOS_CONFIG="${HOME}/nixos-config"
PASS_DIR="${HOME}/.password-store"
DOTFILES_DIR="${HOME}/.dotfiles"

RSYNC_SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15)

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

# ─── rsync helpers ───────────────────────────────────────────────────────────

_rsync_pull() {
    local label="$1" remote="$2" local_dir="$3"
    log "Pulling ${label} from NAS..."
    # No --delete on pull: preserve local files not yet pushed to NAS.
    rsync -avhz --progress \
        -e "ssh ${RSYNC_SSH_OPTS[*]}" \
        "${NAS_HOST}:${remote}/" "${local_dir}/" \
        || warn "${label} pull failed (NAS unreachable? Try: tailscale up)"
}

_rsync_push() {
    local label="$1" remote="$2" local_dir="$3"
    log "Pushing ${label} to NAS..."
    # --delete: NAS mirrors current state; always pull first on the other machine.
    rsync -avhz --progress --delete \
        -e "ssh ${RSYNC_SSH_OPTS[*]}" \
        "${local_dir}/" "${NAS_HOST}:${remote}/" \
        || warn "${label} push failed (NAS unreachable? Try: tailscale up)"
}

rsync_pull_docs() { _rsync_pull "Documents" "${NAS_DOCS_REMOTE}" "${LOCAL_DOCS}"; }
rsync_push_docs() { _rsync_push "Documents" "${NAS_DOCS_REMOTE}" "${LOCAL_DOCS}"; }
rsync_pull_pics() { _rsync_pull "Pictures"  "${NAS_PICS_REMOTE}" "${LOCAL_PICS}"; }
rsync_push_pics() { _rsync_push "Pictures"  "${NAS_PICS_REMOTE}" "${LOCAL_PICS}"; }

# ─── commands ────────────────────────────────────────────────────────────────

cmd_arrive() {
    git_pull "nixos-config" "${NIXOS_CONFIG}"
    dotfiles_pull
    git_pull "pass" "${PASS_DIR}"
    git_pull "zettelkasten" "${ZETTELKASTEN}"
    rsync_pull_docs
    rsync_pull_pics

    log "Syncing workspace repos..."
    bash "${NIXOS_CONFIG}/scripts/sync-workspace-repos.sh"

    log "Arrive sync complete."
    info "If nixos-config changed, run: nrs"
    info "Source your shell if aliases changed: source ~/.bashrc"
}

cmd_leave() {
    log "Checking for uncommitted changes..."
    check_uncommitted "nixos-config" "${NIXOS_CONFIG}"
    check_uncommitted "pass"         "${PASS_DIR}"
    check_uncommitted "zettelkasten" "${ZETTELKASTEN}"

    rsync_push_docs
    rsync_push_pics

    log "Leave sync complete."
    info "Push git repos before closing: g pushall / dot pushall"
}

# ─── main ────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --arrive) cmd_arrive ;;
    --leave)  cmd_leave  ;;
    *)
        printf 'Usage: %s --arrive | --leave\n' "$(basename "$0")"
        printf '\n'
        printf '  --arrive  pull all layers when sitting down at this machine\n'
        printf '  --leave   push Documents and warn about uncommitted changes\n'
        exit 1
        ;;
esac
