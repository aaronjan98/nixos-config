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
REPOS_ROOT="${HOME}/Repositories"
WORKSPACE_MANIFEST="${HOME}/nixos-config/tools/workspace/Repositories/repos.tsv"
LEAVE_STATUS_FILE="/tmp/sync-leave.status"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ─── git helpers ─────────────────────────────────────────────────────────────

git_pull() {
    # Always pulls explicitly from 'home' (the Forgejo-backed remote), never
    # the branch's tracking ref. These repos also have a 'local' bare-repo
    # mirror on this machine (git-server.nix) that only updates on an
    # explicit push and is never the sync source — if a branch's upstream
    # ever gets set to 'local' (as pass's silently was), a plain
    # `git pull --ff-only` would report "already up to date" while pulling
    # from that stale mirror instead of Forgejo. See
    # nixos-config/memory/2026-09-03 pass-sync-tracked-local-mirror.md.
    local name="$1" dir="$2"
    log "Pulling ${name}..."
    if [[ ! -d "${dir}" ]]; then
        warn "${name}: not found at ${dir} — skipping."
        return
    fi
    git -C "${dir}" pull home main --ff-only 2>&1 \
        || warn "${name}: could not fast-forward from home (diverged?). Pull manually."
}

dotfiles_pull() {
    log "Pulling dotfiles..."
    [[ -d "${DOTFILES_DIR}" ]] || { warn "dotfiles bare repo not found."; return; }
    git --git-dir="${DOTFILES_DIR}" --work-tree="${HOME}" \
        pull home main --ff-only 2>&1 \
        || warn "dotfiles: could not fast-forward. Pull manually with: dot pull home main"
}

repo_is_dirty() {
    local dir="$1"
    [[ -d "${dir}/.git" ]] || return 1
    [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]
}

# Dotfiles uses $HOME as worktree, so untracked-files would include the entire
# home directory. Restrict to tracked file changes only via -uno.
dotfiles_is_dirty() {
    [[ -d "$DOTFILES_DIR" ]] || return 1
    local out
    out="$(git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" \
        status --porcelain -uno 2>/dev/null || true)"
    [[ -n "$out" ]]
}

# ─── commands ────────────────────────────────────────────────────────────────

# repos.tsv/remotes.tsv are pure mechanical output of export-workspace-state.sh
# (regenerated hourly from each repo's `git remote -v`) — always safe to discard
# and re-derive later. Everything else under the snapshot tree (CONTEXT.md,
# MEMORY.md, memory/) is a mirror of hand-authored docs from the live tree, so
# it is never discarded automatically — just flagged for the user to commit.
reconcile_generated_snapshot_files() {
    local snapshot_dir="${NIXOS_CONFIG}/tools/workspace/Repositories"
    [[ -d "${NIXOS_CONFIG}/.git" ]] || return

    local f
    for f in "${snapshot_dir}/repos.tsv" "${snapshot_dir}/remotes.tsv"; do
        [[ -f "$f" ]] || continue
        if ! git -C "${NIXOS_CONFIG}" diff --quiet -- "$f" 2>/dev/null; then
            log "Discarding local regeneration of $(basename "$f") (mechanical — safe to re-derive)"
            git -C "${NIXOS_CONFIG}" checkout -- "$f"
        fi
    done

    local other_dirty
    other_dirty="$(git -C "${NIXOS_CONFIG}" status --porcelain -- "${snapshot_dir}" \
        | grep -v -e 'repos\.tsv' -e 'remotes\.tsv' || true)"
    if [[ -n "$other_dirty" ]]; then
        warn "Hand-authored changes under tools/workspace/Repositories/ — commit these yourself, pull may fail otherwise:"
        printf '%s\n' "$other_dirty" | sed 's/^/    /' >&2
    fi
}

cmd_arrive() {
    reconcile_generated_snapshot_files
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
    log "Checking all tracked repos for uncommitted changes..."

    local -a dirty=()

    # System-level repos
    if repo_is_dirty "$NIXOS_CONFIG"; then dirty+=("nixos-config"); fi
    if repo_is_dirty "$PASS_DIR";     then dirty+=("pass");         fi
    if dotfiles_is_dirty;             then dirty+=("dotfiles");     fi

    # Workspace repos — iterate the same manifest bootstrap/sync use, so the
    # scope here matches what sync-arrive pulls.
    if [[ -f "$WORKSPACE_MANIFEST" ]]; then
        local rel _name _url
        while IFS=$'\t' read -r rel _name _url; do
            [[ -z "$rel" ]] && continue
            [[ "${rel:0:1}" == "#" ]] && continue
            if repo_is_dirty "${REPOS_ROOT}/${rel}"; then
                dirty+=("Repositories/${rel}")
            fi
        done < "$WORKSPACE_MANIFEST"
    else
        warn "Workspace manifest not found: ${WORKSPACE_MANIFEST}"
    fi

    if [[ ${#dirty[@]} -eq 0 ]]; then
        printf 'All repos clean — safe to close lid.\n' | tee "$LEAVE_STATUS_FILE"
        log "Leave check complete: no dirty repos."
        info "Documents and Pictures sync continuously via Syncthing."
        return 0
    fi

    {
        printf '%d repo(s) with uncommitted changes:\n' "${#dirty[@]}"
        local d
        for d in "${dirty[@]}"; do
            printf '  • %s\n' "$d"
        done
    } | tee "$LEAVE_STATUS_FILE"

    log "Leave check complete: ${#dirty[@]} dirty repo(s) — review before closing lid."
    return 2
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
