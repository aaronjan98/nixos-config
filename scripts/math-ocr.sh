#!/usr/bin/env bash
set -euo pipefail

GRIM="${GRIM:-grim}"
SLURP="${SLURP:-slurp}"
WL_COPY="${WL_COPY:-wl-copy}"
NOTIFY="${NOTIFY:-notify-send}"

# Prefer pix2tex_cli if present
if command -v pix2tex_cli >/dev/null 2>&1; then
  OCR="pix2tex_cli"
elif command -v pix2tex >/dev/null 2>&1; then
  OCR="pix2tex"
else
  OCR=""
fi

# ---- Ensure HOME/XDG_CACHE_HOME are sane (pix2tex uses these) ----
real_home="$(getent passwd "$(id -un)" | cut -d: -f6 || true)"
if [ -z "${HOME:-}" ] || [ "${HOME:-}" = "/homeless-shelter" ]; then
  export HOME="${real_home:-/tmp}"
fi
if [ -z "${XDG_CACHE_HOME:-}" ] || [ "${XDG_CACHE_HOME:-}" = "/homeless-shelter" ]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi

cache_dir="$XDG_CACHE_HOME/math-ocr"
work_dir="$cache_dir/work"
ckpt_dir="$XDG_CACHE_HOME/pix2tex/checkpoints"

mkdir -p "$cache_dir" "$work_dir" "$ckpt_dir"

img="$cache_dir/last.png"
log="$cache_dir/last.log"
out="$cache_dir/last.txt"

: >"$log"
: >"$out"

logln() { printf '%s\n' "$*" >>"$log"; }

if [ -z "$OCR" ]; then
  logln "No pix2tex command found (pix2tex_cli/pix2tex)."
  "$NOTIFY" -u critical "Math OCR failed" "pix2tex not found in PATH.\nLog: $log"
  exit 1
fi

# ---- Debug header ----
logln "== math-ocr debug =="
logln "date: $(date -Is)"
logln "ocr: $OCR"
logln "HOME: ${HOME:-}"
logln "XDG_CACHE_HOME: ${XDG_CACHE_HOME:-}"
logln "cache_dir: $cache_dir"
logln "work_dir: $work_dir"
logln "pix2tex ckpt_dir: $ckpt_dir"
logln "WEIGHTS_PTH: ${WEIGHTS_PTH:-<unset>}"
logln "IMAGE_RESIZER_PTH: ${IMAGE_RESIZER_PTH:-<unset>}"
logln "which $OCR: $(command -v "$OCR" || true)"
logln "PATH: $PATH"
logln ""

# ---- Region capture ----
region="$("$SLURP" -b "1e000080" -c "e62600ff" -B "00000000" -w 2 -s "00000000")" || exit 0
logln "region: $region"

"$GRIM" -g "$region" "$img"
logln "saved image: $img"
logln "image info:"
(file "$img" >>"$log" 2>&1) || true
logln ""

# ---- Preseed checkpoints as REAL FILES (NOT symlinks) ----
# pix2tex may try to overwrite them; symlinks into /nix/store will explode (read-only).
seed_file() {
  local src="$1"
  local dst="$2"

  [ -n "$src" ] || return 0
  [ -f "$src" ] || return 0

  rm -f "$dst"
  cp -f "$src" "$dst"
  chmod u+rw "$dst" || true
}

seed_file "${WEIGHTS_PTH:-}" "$ckpt_dir/weights.pth"
seed_file "${IMAGE_RESIZER_PTH:-}" "$ckpt_dir/image_resizer.pth"

logln "checkpoint dir listing:"
(ls -lah "$ckpt_dir" >>"$log" 2>&1) || true
logln ""

# ---- Run OCR (force the checkpoint path explicitly) ----
weights_path="$ckpt_dir/weights.pth"

cmd=( "$OCR" "$img" -m "$weights_path" )

logln "running: ${cmd[*]}"
logln ""

set +e
(
  cd "$work_dir"
  "${cmd[@]}" >"$out" 2>>"$log"
)
rc=$?
set -e

logln ""
logln "exit: $rc"
logln "stdout bytes: $(wc -c <"$out" | tr -d ' ')"

latex="$(tr -d '\r' <"$out" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ $rc -ne 0 ] || [ -z "${latex// }" ]; then
  preview="$(tail -n 80 "$log" | sed 's/\t/  /g')"
  "$NOTIFY" -u critical "Math OCR failed" "cmd: $OCR (exit $rc)\n\n$preview\n\nLog: $log\nImage: $img"
  exit 1
fi

printf "%s" "$latex" | "$WL_COPY" --type "text/plain;charset=utf-8"
"$NOTIFY" "Math OCR" "Copied LaTeX to clipboard"

