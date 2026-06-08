#!/usr/bin/env bash
set -euo pipefail

SURYA_PYTHON="${SURYA_PYTHON:-python3}"
SURYA_PIP_SPEC="${SURYA_PIP_SPEC:-surya-ocr==0.16.0}"

if [ -z "${HOME:-}" ] || [ "${HOME:-}" = "/homeless-shelter" ]; then
  HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
  export HOME
fi

if [ -z "${XDG_CACHE_HOME:-}" ] || [ "${XDG_CACHE_HOME:-}" = "/homeless-shelter" ]; then
  XDG_CACHE_HOME="$HOME/.cache"
  export XDG_CACHE_HOME
fi
if [ -n "${SURYA_EXTRA_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="$SURYA_EXTRA_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

SURYA_RUNTIME_DIR="${SURYA_RUNTIME_DIR:-$HOME/.local/share/ocr-runtimes/surya}"
SURYA_VENV_DIR="${SURYA_VENV_DIR:-$SURYA_RUNTIME_DIR/.venv}"

LOG_DIR="$XDG_CACHE_HOME/ocr-combined"
LOG_FILE="${SURYA_BOOTSTRAP_LOG:-$LOG_DIR/bootstrap.log}"
STAMP_FILE="$SURYA_VENV_DIR/.surya-bootstrap-spec"

mkdir -p "$LOG_DIR" "$SURYA_RUNTIME_DIR"
: >"$LOG_FILE"

log() {
  printf '==> %s\n' "$*" | tee -a "$LOG_FILE"
}

warn() {
  printf 'WARN: %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

run() {
  log "Running: $*"
  "$@" >>"$LOG_FILE" 2>&1
}

venv_python_works() {
  [ -x "$SURYA_VENV_DIR/bin/python" ] && "$SURYA_VENV_DIR/bin/python" -c 'import sys; print(sys.executable)' >>"$LOG_FILE" 2>&1
}

create_or_repair_venv() {
  if venv_python_works; then
    log "Venv Python works: $SURYA_VENV_DIR"
    return
  fi

  if [ -d "$SURYA_VENV_DIR" ]; then
    log "Removing broken venv: $SURYA_VENV_DIR"
    rm -rf "$SURYA_VENV_DIR"
  fi

  run "$SURYA_PYTHON" -m venv "$SURYA_VENV_DIR"
}

surya_command_exists() {
  [ -x "$SURYA_VENV_DIR/bin/surya_ocr" ]
}

install_python_runtime() {
  local stamped_spec=""

  if [ -f "$STAMP_FILE" ]; then
    stamped_spec="$(cat "$STAMP_FILE")"
  fi

  if [ "$stamped_spec" = "$SURYA_PIP_SPEC" ] && surya_command_exists; then
    log "Surya runtime already installed for: $SURYA_PIP_SPEC"
    return
  fi

  run "$SURYA_VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
  run "$SURYA_VENV_DIR/bin/python" -m pip install "$SURYA_PIP_SPEC"

  printf '%s\n' "$SURYA_PIP_SPEC" >"$STAMP_FILE"
}

verify_runtime() {
  if ! surya_command_exists; then
    warn "No surya_ocr command found after install"
    exit 1
  fi

  run "$SURYA_VENV_DIR/bin/python" -c 'import surya; print("surya import ok")'
  run "$SURYA_VENV_DIR/bin/surya_ocr" --help

  if command -v llama-server >/dev/null 2>&1; then
    log "Found llama-server: $(command -v llama-server)"
  else
    warn "llama-server not found in PATH."
    warn "The Nix-installed ocr-combined wrapper provides llama.cpp at runtime."
    warn "Directly running the venv outside that wrapper may fail on CPU."
  fi
}

main() {
  log "Bootstrapping Surya OCR runtime"
  log "Runtime dir: $SURYA_RUNTIME_DIR"
  log "Venv dir: $SURYA_VENV_DIR"
  log "Pip spec: $SURYA_PIP_SPEC"
  log "Log file: $LOG_FILE"

  create_or_repair_venv
  install_python_runtime
  verify_runtime

  log "Surya OCR runtime ready"
}

main "$@"
