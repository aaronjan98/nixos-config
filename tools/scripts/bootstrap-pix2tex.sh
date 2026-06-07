#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${PIX2TEX_REPO_URL:-ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/pix2tex.git}"
SOURCE_REMOTE="${PIX2TEX_REMOTE:-home}"
PINNED_REV="${PIX2TEX_REV:-5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80}"
RUNTIME_DIR="${PIX2TEX_RUNTIME_DIR:-$HOME/Repositories/automation/pix2tex}"
VENV_DIR="${PIX2TEX_VENV_DIR:-$RUNTIME_DIR/.venv}"
PYTHON="${PIX2TEX_PYTHON:-python3}"
TORCH_INDEX_URL="${PIX2TEX_TORCH_INDEX_URL:-https://download.pytorch.org/whl/cpu}"

if [ -z "${HOME:-}" ] || [ "${HOME:-}" = "/homeless-shelter" ]; then
  HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
  export HOME
fi

if [ -z "${XDG_CACHE_HOME:-}" ] || [ "${XDG_CACHE_HOME:-}" = "/homeless-shelter" ]; then
  XDG_CACHE_HOME="$HOME/.cache"
  export XDG_CACHE_HOME
fi

LOG_DIR="$XDG_CACHE_HOME/math-ocr"
LOG_FILE="${PIX2TEX_BOOTSTRAP_LOG:-$LOG_DIR/bootstrap.log}"
CONSTRAINTS_FILE="${PIX2TEX_CONSTRAINTS_FILE:-$LOG_DIR/pix2tex-constraints.txt}"

mkdir -p "$LOG_DIR"
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

ensure_repo() {
  if [ -d "$RUNTIME_DIR/.git" ]; then
    log "Repo exists: $RUNTIME_DIR"
  elif [ -e "$RUNTIME_DIR" ]; then
    warn "Runtime path exists but is not a git repo: $RUNTIME_DIR"
    exit 1
  else
    mkdir -p "$(dirname "$RUNTIME_DIR")"
    if ! run git clone --origin "$SOURCE_REMOTE" "$REPO_URL" "$RUNTIME_DIR"; then
      warn "Could not clone pix2tex from: $REPO_URL"
      warn "If this is the local git server path, make sure the bare repo exists there first."
      warn "Override for one run with: PIX2TEX_REPO_URL=<url> bootstrap-pix2tex"
      exit 1
    fi
  fi

  if git -C "$RUNTIME_DIR" remote get-url "$SOURCE_REMOTE" >/dev/null 2>&1; then
    log "Using source remote: $SOURCE_REMOTE"
  else
    run git -C "$RUNTIME_DIR" remote add "$SOURCE_REMOTE" "$REPO_URL"
  fi

  local exclude_file="$RUNTIME_DIR/.git/info/exclude"
  if ! grep -qxF ".venv/" "$exclude_file"; then
    printf '\n.venv/\n' >>"$exclude_file"
  fi
}

checkout_pinned_rev() {
  run git -C "$RUNTIME_DIR" fetch --tags "$SOURCE_REMOTE"

  if ! git -C "$RUNTIME_DIR" cat-file -e "$PINNED_REV^{commit}" 2>>"$LOG_FILE"; then
    run git -C "$RUNTIME_DIR" fetch "$SOURCE_REMOTE" "$PINNED_REV"
  fi

  if ! git -C "$RUNTIME_DIR" diff --quiet --ignore-submodules --; then
    warn "pix2tex repo has local tracked changes; refusing to overwrite them"
    warn "Repo: $RUNTIME_DIR"
    exit 1
  fi

  if ! git -C "$RUNTIME_DIR" diff --cached --quiet --ignore-submodules --; then
    warn "pix2tex repo has staged changes; refusing to overwrite them"
    warn "Repo: $RUNTIME_DIR"
    exit 1
  fi

  local current_rev
  current_rev="$(git -C "$RUNTIME_DIR" rev-parse HEAD 2>>"$LOG_FILE" || true)"
  if [ "$current_rev" = "$PINNED_REV" ]; then
    log "Repo already at pinned revision: $PINNED_REV"
  else
    run git -C "$RUNTIME_DIR" checkout --detach "$PINNED_REV"
  fi
}

venv_python_works() {
  [ -x "$VENV_DIR/bin/python" ] && "$VENV_DIR/bin/python" -c 'import sys; print(sys.executable)' >>"$LOG_FILE" 2>&1
}

create_or_repair_venv() {
  if venv_python_works; then
    log "Venv Python works: $VENV_DIR"
    return
  fi

  if [ -d "$VENV_DIR" ]; then
    log "Removing broken venv: $VENV_DIR"
    rm -rf "$VENV_DIR"
  fi

  run "$PYTHON" -m venv "$VENV_DIR"
}

ocr_command_exists() {
  [ -x "$VENV_DIR/bin/pix2tex" ] || [ -x "$VENV_DIR/bin/pix2tex_cli" ]
}

write_constraints() {
  cat >"$CONSTRAINTS_FILE" <<'EOF'
albumentations==1.3.1
huggingface-hub<1.0
numpy<2.0
pandas<3.0
pydantic<3.0
tokenizers<0.22
transformers<5.0
EOF
}

install_python_runtime() {
  local stamp_file="$VENV_DIR/.pix2tex-bootstrap-rev"
  local stamped_rev=""

  if [ -f "$stamp_file" ]; then
    stamped_rev="$(cat "$stamp_file")"
  fi

  if [ "$stamped_rev" = "$PINNED_REV" ] && ocr_command_exists; then
    log "Python runtime already installed for pinned revision"
    return
  fi

  write_constraints
  log "Using constraints: $CONSTRAINTS_FILE"

  run "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
  run "$VENV_DIR/bin/python" -m pip install --index-url "$TORCH_INDEX_URL" torch torchvision torchaudio
  run "$VENV_DIR/bin/python" -m pip install --constraint "$CONSTRAINTS_FILE" -e "$RUNTIME_DIR"

  printf '%s\n' "$PINNED_REV" >"$stamp_file"
}

verify_runtime() {
  if [ -x "$VENV_DIR/bin/pix2tex" ]; then
    log "Found OCR command: $VENV_DIR/bin/pix2tex"
  elif [ -x "$VENV_DIR/bin/pix2tex_cli" ]; then
    log "Found OCR command: $VENV_DIR/bin/pix2tex_cli"
  else
    warn "No pix2tex command found in venv after install"
    exit 1
  fi
}

main() {
  log "Bootstrapping pix2tex runtime"
  log "Runtime dir: $RUNTIME_DIR"
  log "Pinned rev: $PINNED_REV"
  log "Log file: $LOG_FILE"

  ensure_repo
  checkout_pinned_rev
  create_or_repair_venv
  install_python_runtime
  verify_runtime

  log "pix2tex runtime ready"
}

main "$@"
