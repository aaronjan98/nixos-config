#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_ROOT="${HOME}/nixos-config/tools/workspace/Repositories"
LIVE_ROOT="${HOME}/Repositories"
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


restore_routing_files() {
  log "Restoring routing files from snapshot"
  # The snapshot already stops at git repo boundaries, so rsync the whole tree.
  # repos.tsv / remotes.tsv are snapshot metadata — not part of ~/Repositories/.
  rsync -a \
    --exclude='repos.tsv' \
    --exclude='remotes.tsv' \
    "${SNAPSHOT_ROOT}/" "${LIVE_ROOT}/"
}

apply_remotes_for_repo() {
  local rel_path="$1"
  local target_dir="${LIVE_ROOT}/${rel_path}"

  if [[ ! -d "${target_dir}/.git" ]]; then
    warn "remotes.tsv references missing repo: ${rel_path}"
    return
  fi

  local -a desired_names=()
  local -a desired_urls=()
  local p name url
  while IFS=$'\t' read -r p name url; do
    [[ -z "$p" ]] && continue
    [[ "${p:0:1}" == "#" ]] && continue
    [[ "$p" == "$rel_path" ]] || continue
    [[ -z "$name" ]] && continue
    desired_names+=("$name")
    desired_urls+=("$url")
  done < "$REMOTES_PATH"

  local current_name found i
  while IFS= read -r current_name; do
    [[ -z "$current_name" ]] && continue
    found=0
    for i in "${!desired_names[@]}"; do
      [[ "${desired_names[i]}" == "$current_name" ]] && { found=1; break; }
    done
    if [[ $found -eq 0 ]]; then
      log "  ${rel_path}: removing remote ${current_name}"
      git -C "$target_dir" remote remove "$current_name"
    fi
  done < <(git -C "$target_dir" remote)

  local current_url
  for i in "${!desired_names[@]}"; do
    name="${desired_names[i]}"
    url="${desired_urls[i]}"
    if current_url="$(git -C "$target_dir" remote get-url "$name" 2>/dev/null)"; then
      if [[ "$current_url" != "$url" ]]; then
        log "  ${rel_path}: set-url ${name} ${current_url} -> ${url}"
        git -C "$target_dir" remote set-url "$name" "$url"
      fi
    else
      log "  ${rel_path}: add remote ${name} -> ${url}"
      git -C "$target_dir" remote add "$name" "$url"
    fi
  done

  # Heal upstream tracking. A fresh `git clone <url>` sets origin and points
  # branch.<main>.remote=origin; removing origin above leaves that config
  # dangling so `@{u}` no longer resolves and sync-workspace-repos.sh
  # correctly refuses to pull. Re-pin the branch to a real remote — preferring
  # `home` (self-hosted) if present, falling back to the first listed remote.
  local branch
  branch="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    return  # detached HEAD or unborn branch — skip silently
  fi

  if git -C "$target_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    return  # upstream already resolves to an existing remote — leave it alone
  fi

  local primary=""
  for i in "${!desired_names[@]}"; do
    if [[ "${desired_names[i]}" == "home" ]]; then
      primary="home"
      break
    fi
  done
  if [[ -z "$primary" && ${#desired_names[@]} -gt 0 ]]; then
    primary="${desired_names[0]}"
  fi
  if [[ -z "$primary" ]]; then
    warn "  ${rel_path}: no remotes in manifest, cannot set upstream"
    return
  fi

  if ! git -C "$target_dir" show-ref --verify --quiet "refs/remotes/${primary}/${branch}"; then
    log "  ${rel_path}: fetching ${primary} to discover ${branch}"
    if ! git -C "$target_dir" fetch --quiet "$primary" 2>/dev/null; then
      warn "  ${rel_path}: fetch from ${primary} failed, cannot set upstream"
      return
    fi
  fi

  if ! git -C "$target_dir" show-ref --verify --quiet "refs/remotes/${primary}/${branch}"; then
    warn "  ${rel_path}: ${primary} has no branch '${branch}', cannot set upstream"
    return
  fi

  log "  ${rel_path}: set upstream ${branch} -> ${primary}/${branch}"
  git -C "$target_dir" branch --set-upstream-to="${primary}/${branch}" "$branch"
}

apply_remotes() {
  if [[ ! -f "$REMOTES_PATH" ]]; then
    warn "remotes manifest not found, skipping remote sync: $REMOTES_PATH"
    return
  fi

  log "Applying per-repo remotes from $REMOTES_PATH"

  local rel_path
  while IFS= read -r rel_path; do
    [[ -z "$rel_path" ]] && continue
    apply_remotes_for_repo "$rel_path"
  done < <(awk -F'\t' '$1 !~ /^#/ && $1 != "" {print $1}' "$REMOTES_PATH" | sort -u)
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
  apply_remotes
  log "Workspace bootstrap complete"
}

main "$@"
