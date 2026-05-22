#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_ROOT="${HOME}/nixos-config/tools/workspace/Repositories"
LIVE_ROOT="${HOME}/Repositories"
MANIFEST_PATH="${SNAPSHOT_ROOT}/repos.tsv"
HOME_BASE="ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos"
LOCAL_PREFIX="ssh://git@localhost"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

ensure_dir() {
  mkdir -p "$1"
}


restore_routing_files() {
  log "Restoring routing files from snapshot"
  # The snapshot already stops at git repo boundaries, so rsync the whole tree.
  # repos.tsv is snapshot metadata — it should not appear in ~/Repositories/.
  rsync -a --exclude='repos.tsv' "${SNAPSHOT_ROOT}/" "${LIVE_ROOT}/"
}

# After cloning, rename origin to local/hub and add home remote as appropriate.
# - localhost URL: origin → local, add home (homelab)
# - GitHub URL:    origin → hub
setup_remotes() {
  local target_dir="$1"
  local remote_url="$2"

  if [[ "$remote_url" == "${LOCAL_PREFIX}"* ]]; then
    git -C "$target_dir" remote rename origin local
    local repo_file
    repo_file="$(basename "$remote_url")"
    git -C "$target_dir" remote add home "${HOME_BASE}/${repo_file}"
  elif [[ "$remote_url" == *"github.com"* ]]; then
    git -C "$target_dir" remote rename origin hub
  fi
}

clone_missing_repos() {
  if [[ ! -f "$MANIFEST_PATH" ]]; then
    warn "Manifest not found: $MANIFEST_PATH"
    exit 1
  fi

  log "Ensuring repos from manifest exist in ${LIVE_ROOT}"

  while IFS=$'\t' read -r relative_path repo_name remote_url; do
    [[ -z "${relative_path}" ]] && continue
    [[ "${relative_path:0:1}" == "#" ]] && continue

    local target_dir
    target_dir="${LIVE_ROOT}/${relative_path}"

    ensure_dir "$(dirname "$target_dir")"

    if [[ -d "${target_dir}/.git" ]]; then
      log "Repo already exists, skipping clone: ${target_dir}"
      continue
    fi

    if [[ -e "$target_dir" && ! -d "${target_dir}/.git" ]]; then
      warn "Path exists but is not a git repo, skipping: ${target_dir}"
      continue
    fi

    if [[ -z "$remote_url" ]]; then
      warn "No remote URL for ${relative_path}, skipping clone"
      continue
    fi

    log "Cloning ${remote_url} -> ${target_dir}"
    git clone "$remote_url" "$target_dir"
    setup_remotes "$target_dir" "$remote_url"
  done < "$MANIFEST_PATH"
}

main() {
  ensure_dir "$LIVE_ROOT"
  restore_routing_files
  clone_missing_repos
  log "Workspace bootstrap complete"
}

main "$@"
