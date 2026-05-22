#!/usr/bin/env bash
set -euo pipefail

LIVE_ROOT="${HOME}/Repositories"
SNAPSHOT_ROOT="${HOME}/nixos-config/tools/workspace/Repositories"
MANIFEST_PATH="${SNAPSHOT_ROOT}/repos.tsv"
REMOTES_PATH="${SNAPSHOT_ROOT}/remotes.tsv"

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
  fi
}

sync_dir_if_exists() {
  local src="$1"
  local dst="$2"

  if [[ -d "$src" ]]; then
    ensure_dir "$dst"
    rsync -a --delete "$src/" "$dst/"
  fi
}

get_remote_url() {
  local repo_dir="$1"
  local remote_name
  local remote_url

  for remote_name in local home hub origin; do
    if remote_url="$(git -C "$repo_dir" remote get-url "$remote_name" 2>/dev/null)"; then
      printf '%s\n' "$remote_url"
      return 0
    fi
  done

  printf '\n'
}

write_manifest_header() {
  cat > "$MANIFEST_PATH" <<'EOM'
# relative_path	repo_name	remote_url
EOM
}

write_remotes_header() {
  cat > "$REMOTES_PATH" <<'EOM'
# relative_path	remote_name	remote_url
EOM
}

record_remotes() {
  local repo_dir="$1"
  local rel_path="$2"
  local remote_name
  local remote_url

  while IFS= read -r remote_name; do
    [[ -z "$remote_name" ]] && continue
    remote_url="$(git -C "$repo_dir" remote get-url "$remote_name" 2>/dev/null)" || continue
    printf '%s\t%s\t%s\n' "$rel_path" "$remote_name" "$remote_url" >> "$REMOTES_PATH"
  done < <(git -C "$repo_dir" remote 2>/dev/null | sort)
}

record_repo() {
  local repo_dir="$1"
  local rel_path="$2"
  local repo_name
  local remote_url

  repo_name="$(basename "$repo_dir")"
  remote_url="$(get_remote_url "$repo_dir")"

  printf '%s\t%s\t%s\n' "$rel_path" "$repo_name" "$remote_url" >> "$MANIFEST_PATH"
  record_remotes "$repo_dir" "$rel_path"
}

discover_tree() {
  local current_dir="$1"
  local rel_path="$2"

  # Stop at repo boundary and only record manifest entry
  if [[ -d "${current_dir}/.git" ]]; then
    record_repo "$current_dir" "$rel_path"
    return
  fi

  # Mirror agent files for non-root, non-repo directories
  if [[ -n "$rel_path" ]]; then
    copy_if_exists "${current_dir}/CONTEXT.md"     "${SNAPSHOT_ROOT}/${rel_path}/CONTEXT.md"
    copy_if_exists "${current_dir}/MEMORY.md"      "${SNAPSHOT_ROOT}/${rel_path}/MEMORY.md"
    sync_dir_if_exists "${current_dir}/memory"         "${SNAPSHOT_ROOT}/${rel_path}/memory"
    sync_dir_if_exists "${current_dir}/project-memory" "${SNAPSHOT_ROOT}/${rel_path}/project-memory"
  fi

  local child
  local child_name
  local child_rel

  shopt -s nullglob
  for child in "${current_dir}"/*; do
    [[ -d "$child" ]] || continue
    child_name="$(basename "$child")"
    child_rel="${rel_path:+${rel_path}/}${child_name}"

    # If child is a repo, record it and do not create a snapshot directory
    if [[ -d "${child}/.git" ]]; then
      record_repo "$child" "$child_rel"
      continue
    fi

    discover_tree "$child" "$child_rel"
  done
  shopt -u nullglob
}

main() {
  if [[ ! -d "$LIVE_ROOT" ]]; then
    warn "Live workspace root does not exist: $LIVE_ROOT"
    exit 1
  fi

  ensure_dir "$SNAPSHOT_ROOT"

  log "Resetting snapshot routing directories"
  find "$SNAPSHOT_ROOT" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
  write_manifest_header
  write_remotes_header

  log "Copying top-level agent files"
  copy_if_exists "${LIVE_ROOT}/ROUTER.md"   "${SNAPSHOT_ROOT}/ROUTER.md"
  copy_if_exists "${LIVE_ROOT}/CONTEXT.md"  "${SNAPSHOT_ROOT}/CONTEXT.md"
  copy_if_exists "${LIVE_ROOT}/MEMORY.md"   "${SNAPSHOT_ROOT}/MEMORY.md"
  sync_dir_if_exists "${LIVE_ROOT}/memory"         "${SNAPSHOT_ROOT}/memory"
  sync_dir_if_exists "${LIVE_ROOT}/project-memory" "${SNAPSHOT_ROOT}/project-memory"

  log "Discovering live workspace structure"
  discover_tree "$LIVE_ROOT" ""

  log "Workspace export complete"
  log "Snapshot root: $SNAPSHOT_ROOT"
  log "Manifest: $MANIFEST_PATH"
  log "Remotes: $REMOTES_PATH"
}

main "$@"
