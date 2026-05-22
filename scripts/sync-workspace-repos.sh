#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_ROOT="${HOME}/nixos-config/tools/workspace/Repositories"
LIVE_ROOT="${HOME}/Repositories"
MANIFEST_PATH="${SNAPSHOT_ROOT}/repos.tsv"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

ensure_dir() {
  mkdir -p "$1"
}

repo_is_clean() {
  local repo_dir="$1"
  [[ -z "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]]
}

current_branch() {
  local repo_dir="$1"
  git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

has_upstream() {
  local repo_dir="$1"
  git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
}

sync_repo() {
  local target_dir="$1"
  local remote_url="$2"

  if [[ ! -d "${target_dir}/.git" ]]; then
    ensure_dir "$(dirname "$target_dir")"

    if [[ -z "$remote_url" ]]; then
      warn "No remote URL for missing repo, cannot clone: ${target_dir}"
      return
    fi

    log "Cloning ${remote_url} -> ${target_dir}"
    git clone "$remote_url" "$target_dir"
    return
  fi

  log "Fetching updates in ${target_dir}"
  # Iterate per-remote so a single dead remote (e.g. a `local` bare repo not
  # seeded on this laptop) only warns instead of killing the whole sync.
  local remote
  while IFS= read -r remote; do
    [[ -z "$remote" ]] && continue
    if ! git -C "$target_dir" fetch --prune "$remote" 2>&1; then
      warn "Fetch failed for remote '${remote}' in ${target_dir} — continuing"
    fi
  done < <(git -C "$target_dir" remote)

  if ! repo_is_clean "$target_dir"; then
    warn "Repo has local changes, skipping pull: ${target_dir}"
    return
  fi

  if ! has_upstream "$target_dir"; then
    warn "Repo has no upstream tracking branch, skipping pull: ${target_dir}"
    return
  fi

  local branch
  branch="$(current_branch "$target_dir")"

  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    warn "Detached HEAD or unknown branch, skipping pull: ${target_dir}"
    return
  fi

  log "Fast-forward pulling ${target_dir}"
  git -C "$target_dir" pull --ff-only
}

main() {
  if [[ ! -f "$MANIFEST_PATH" ]]; then
    warn "Manifest not found: $MANIFEST_PATH"
    exit 1
  fi

  ensure_dir "$LIVE_ROOT"

  while IFS=$'\t' read -r relative_path repo_name remote_url; do
    [[ -z "${relative_path}" ]] && continue
    [[ "${relative_path:0:1}" == "#" ]] && continue

    sync_repo "${LIVE_ROOT}/${relative_path}" "$remote_url"
  done < "$MANIFEST_PATH"

  log "Workspace repo sync complete"
}

main "$@"
