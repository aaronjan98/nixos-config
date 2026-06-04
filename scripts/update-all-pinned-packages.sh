#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

UPDATE_SCRIPTS=(
  "update-pi.sh"
  "update-openai-codex.sh"
)

log() {
  printf '==> %s\n' "$*"
}

info() {
  printf '    %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Required command not found: $1"
    exit 1
  }
}

resolve_flake_host() {
  local host="${NIXOS_FLAKE_HOST:-$(hostname)}"

  case "$host" in
    nixos) echo "thinkpad-t14" ;;
    *) echo "$host" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  scripts/update-all-pinned-packages.sh [--no-build]

Examples:
  scripts/update-all-pinned-packages.sh
  scripts/update-all-pinned-packages.sh --no-build

Behavior:
  - runs each tracked pinned-package update script in sequence
  - updates each package to its latest upstream version
  - runs one final Nix build to verify the combined result by default

Current package set:
  - pi
  - openai-codex

Notes:
  - the individual update scripts are run with --no-build so the system is only
    verified once at the end
  - this script updates tracked files only; activate the result separately with:
      nrs
EOF
}

run_update_script() {
  local script_name="$1"
  local script_path="${SCRIPT_DIR}/${script_name}"

  if [[ ! -f "$script_path" ]]; then
    warn "Update script not found: $script_path"
    return 127
  fi

  log "Running ${script_name}"
  if bash "$script_path" --no-build; then
    return 0
  fi

  local exit_code="$?"
  warn "${script_name} failed with exit code ${exit_code}"
  return "$exit_code"
}

main() {
  local run_build=1
  local script_name
  local exit_code
  local -a succeeded=()
  local -a failed=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-build)
        run_build=0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done

  if [[ ! -d "$REPO_ROOT/scripts" ]]; then
    warn "Expected repo root not found: $REPO_ROOT"
    exit 1
  fi

  require_cmd bash
  require_cmd nix

  local flake_host
  flake_host="$(resolve_flake_host)"
  local build_target=".#nixosConfigurations.${flake_host}.config.system.build.toplevel"

  for script_name in "${UPDATE_SCRIPTS[@]}"; do
    if run_update_script "$script_name"; then
      succeeded+=("$script_name")
    else
      exit_code="$?"
      failed+=("${script_name}:${exit_code}")
      warn "Continuing to remaining update scripts"
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Skipping combined verification build because one or more update scripts failed"

    printf '\nSuccessful scripts:\n'
    if [[ ${#succeeded[@]} -gt 0 ]]; then
      for script_name in "${succeeded[@]}"; do
        info "$script_name"
      done
    else
      info "(none)"
    fi

    printf '\nFailed scripts:\n'
    for script_name in "${failed[@]}"; do
      warn "$script_name"
    done

    exit 1
  fi

  if [[ "$run_build" -eq 1 ]]; then
    log "Building ${flake_host} NixOS system to verify combined updates"
    if ! nix build "$build_target" --impure --extra-experimental-features 'nix-command flakes' --option warn-dirty false; then
      warn "Combined verification build failed after all update scripts completed"
      exit 1
    fi
  else
    log "Skipping verification build (--no-build)"
  fi

  log "Pinned package update run is ready"
  printf '\nUpdated via:\n'
  for script_name in "${UPDATE_SCRIPTS[@]}"; do
    info "$script_name"
  done
  printf '\nNext steps:\n'
  printf '  1. Review the diff\n'
  printf '  2. Run: nrs\n'
  printf '     (explicit: sudo nixos-rebuild switch --flake ~/nixos-config#%s)\n' "$flake_host"
  printf '  3. Verify: pi --version && codex --version\n'
}

main "$@"
