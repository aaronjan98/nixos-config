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

copy_if_exists() {
  local src="$1"
  local dst="$2"

  if [[ -f "$src" ]]; then
    ensure_dir "$(dirname "$dst")"
    cp "$src" "$dst"
    log "Copied: $dst"
  fi
}

restore_routing_files() {
  log "Restoring top-level ROUTER.md"
  copy_if_exists "${SNAPSHOT_ROOT}/ROUTER.md" "${LIVE_ROOT}/ROUTER.md"

  log "Restoring area-level CONTEXT.md files"
  local area_dir
  shopt -s nullglob
  for area_dir in "${SNAPSHOT_ROOT}"/*; do
    [[ -d "$area_dir" ]] || continue
    local area_name
    area_name="$(basename "$area_dir")"
    copy_if_exists "${area_dir}/CONTEXT.md" "${LIVE_ROOT}/${area_name}/CONTEXT.md"
  done
  shopt -u nullglob
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
  done < "$MANIFEST_PATH"
}

main() {
  ensure_dir "$LIVE_ROOT"
  restore_routing_files
  clone_missing_repos
  log "Workspace bootstrap complete"
}

main "$@"
