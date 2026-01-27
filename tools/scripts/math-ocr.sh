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

# NOTE: we DO NOT pre-seed/copy weights into the cache.
# Let pix2tex/pip-managed code handle downloading and managing the correct model files.
# This avoids state-dict/version mismatch errors.

logln "checkpoint dir listing (before running pix2tex):"
(ls -lah "$ckpt_dir" >>"$log" 2>&1) || true
logln ""

# Make relative "checkpoints/..." work if pix2tex expects it from cwd
ln -sfn "$ckpt_dir" "$work_dir/checkpoints"
logln "work checkpoints link:"
(ls -lah "$work_dir/checkpoints" >>"$log" 2>&1) || true
logln ""

# ---- Run OCR (from work_dir so relative checkpoints/ paths resolve) ----
cmd=( "$OCR" "$img" )

logln "running (cwd=$work_dir): ${cmd[*]}"
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

