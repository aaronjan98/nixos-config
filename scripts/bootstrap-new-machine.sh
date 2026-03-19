#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="${HOME}/nixos-config/scripts"

RESTORE_SECRETS="${SCRIPTS_DIR}/restore-secrets.sh"
INSTALL_UNITS="${SCRIPTS_DIR}/install-user-systemd-units.sh"
SEED_GIT_SERVER="${SCRIPTS_DIR}/seed-local-git-server.sh"
SYNC_DISTFILES="${SCRIPTS_DIR}/sync-distfiles.sh"
BOOTSTRAP_WORKSPACE="${SCRIPTS_DIR}/bootstrap-workspace.sh"
SYNC_WORKSPACE="${SCRIPTS_DIR}/sync-workspace-repos.sh"

NIXOS_REBUILD_CMD="sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14"

log() {
  printf '==> %s\n' "$*"
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

require_script() {
  [[ -x "$1" ]] || {
    warn "Required executable script not found: $1"
    exit 1
  }
}

ask_yes_no() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N]: " reply || true
  case "${reply:-}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

run_step() {
  local label="$1"
  local script="$2"

  log "$label"
  "$script"
}

main() {
  require_cmd git
  require_cmd systemctl
  require_cmd sudo

  require_script "$INSTALL_UNITS"
  require_script "$SEED_GIT_SERVER"
  require_script "$SYNC_DISTFILES"
  require_script "$BOOTSTRAP_WORKSPACE"
  require_script "$SYNC_WORKSPACE"

  log "Starting guided new-machine bootstrap"

  if [[ -x "$RESTORE_SECRETS" ]]; then
    if ask_yes_no "Run restore-secrets.sh now? This requires working GPG and pass."; then
      run_step "Restoring secrets" "$RESTORE_SECRETS"
    else
      warn "Skipping secrets restore. You may need to run it before private repo access or nixos-rebuild."
    fi
  else
    warn "restore-secrets.sh not found or not executable; skipping secrets phase"
  fi

  run_step "Installing tracked user systemd units" "$INSTALL_UNITS"
  run_step "Seeding local git server" "$SEED_GIT_SERVER"
  run_step "Syncing distfiles" "$SYNC_DISTFILES"
  run_step "Bootstrapping workspace layout" "$BOOTSTRAP_WORKSPACE"
  run_step "Syncing workspace repos" "$SYNC_WORKSPACE"

  log "Bootstrap sequence complete"
  printf '\n'
  printf 'Next step:\n'
  printf '  %s\n' "$NIXOS_REBUILD_CMD"
  printf '\n'
  printf "Alias reminder:\n"
  printf "  nrs='sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14'\n"
}

main "$@"
