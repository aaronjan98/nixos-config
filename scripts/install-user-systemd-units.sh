#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${HOME}/nixos-config/systemd/user"
TARGET_DIR="${HOME}/.config/systemd/user"

log() {
  printf '==> %s\n' "$*"
}

ensure_dir() {
  mkdir -p "$1"
}

main() {
  ensure_dir "$TARGET_DIR"

  log "Installing tracked user systemd units from ${SOURCE_DIR}"
  cp "${SOURCE_DIR}"/* "${TARGET_DIR}"/

  log "Reloading user systemd daemon"
  systemctl --user daemon-reload

  log "Enabling export-workspace-state.timer by default"
  systemctl --user enable --now export-workspace-state.timer

  log "Enabling sync-arrive.service on graphical login"
  # No --now: this fires automatically when graphical-session.target next activates.
  systemctl --user enable sync-arrive.service

  log "Leaving video-summary units disabled by default"
  systemctl --user disable --now video-summary.timer 2>/dev/null || true
  systemctl --user disable --now video-summary.path 2>/dev/null || true

  log "Installation complete"
}
main "$@"
