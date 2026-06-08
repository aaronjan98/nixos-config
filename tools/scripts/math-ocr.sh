#!/usr/bin/env bash
set -euo pipefail

GRIM="${GRIM:-grim}"
SLURP="${SLURP:-slurp}"
WL_COPY="${WL_COPY:-wl-copy}"
NOTIFY="${NOTIFY:-notify-send}"
SYSTEMD_RUN="${SYSTEMD_RUN:-systemd-run}"

# ---- Ensure HOME/XDG_CACHE_HOME are sane (pix2tex uses these) ----
real_home="$(getent passwd "$(id -un)" | cut -d: -f6 || true)"
if [ -z "${HOME:-}" ] || [ "${HOME:-}" = "/homeless-shelter" ]; then
  export HOME="${real_home:-/tmp}"
fi
if [ -z "${XDG_CACHE_HOME:-}" ] || [ "${XDG_CACHE_HOME:-}" = "/homeless-shelter" ]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi
if [ -n "${PIX2TEX_EXTRA_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="$PIX2TEX_EXTRA_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

RUNTIME_DIR="${PIX2TEX_RUNTIME_DIR:-$HOME/Repositories/automation/pix2tex}"
VENV_DIR="${PIX2TEX_VENV_DIR:-$RUNTIME_DIR/.venv}"

cache_dir="$XDG_CACHE_HOME/math-ocr"
work_dir="$cache_dir/work"
model_ckpt_dir="$RUNTIME_DIR/pix2tex/model/checkpoints"

mkdir -p "$cache_dir" "$work_dir"

img="$cache_dir/last.png"
log="$cache_dir/last.log"
out="$cache_dir/last.txt"
clip="$cache_dir/last-clipboard.txt"

: >"$log"
: >"$out"
: >"$clip"

logln() { printf '%s\n' "$*" >>"$log"; }

strip_outer_latex_group() {
  local text="$1"
  local suffix=""
  local last_char="${text: -1}"

  case "$last_char" in
    "." | "!" | "?" | "," | ":" | ";")
      suffix="$last_char"
      text="${text:0:${#text}-1}"
      ;;
  esac

  if [[ "$text" != \{* ]] || [[ "$text" != *\} ]]; then
    printf '%s%s' "$text" "$suffix"
    return
  fi

  local length="${#text}"
  local depth=0
  local escaped=0
  local close_index=-1
  local index
  local char

  for ((index = 0; index < length; index++)); do
    char="${text:index:1}"

    if [ "$escaped" -eq 1 ]; then
      escaped=0
      continue
    fi

    case "$char" in
      "\\")
        escaped=1
        ;;
      "{")
        depth=$((depth + 1))
        ;;
      "}")
        depth=$((depth - 1))
        if [ "$depth" -eq 0 ]; then
          close_index="$index"
          break
        fi
        if [ "$depth" -lt 0 ]; then
          break
        fi
        ;;
    esac
  done

  if [ "$close_index" -eq $((length - 1)) ]; then
    printf '%s%s' "${text:1:length-2}" "$suffix"
  else
    printf '%s%s' "$text" "$suffix"
  fi
}

if [ -x "$VENV_DIR/bin/pix2tex" ]; then
  OCR="$VENV_DIR/bin/pix2tex"
elif [ -x "$VENV_DIR/bin/pix2tex_cli" ]; then
  OCR="$VENV_DIR/bin/pix2tex_cli"
else
  logln "No pix2tex command found in venv."
  logln "RUNTIME_DIR: $RUNTIME_DIR"
  logln "VENV_DIR: $VENV_DIR"
  logln "Expected: $VENV_DIR/bin/pix2tex or $VENV_DIR/bin/pix2tex_cli"
  "$NOTIFY" -u critical "Math OCR failed" "pix2tex venv is not ready. Run: bootstrap-pix2tex\nLog: $log"
  exit 1
fi

# ---- Debug header ----
logln "== math-ocr debug =="
logln "date: $(date -Is)"
logln "ocr: $OCR"
logln "HOME: ${HOME:-}"
logln "XDG_CACHE_HOME: ${XDG_CACHE_HOME:-}"
logln "RUNTIME_DIR: $RUNTIME_DIR"
logln "VENV_DIR: $VENV_DIR"
logln "PIX2TEX_EXTRA_LIBRARY_PATH: ${PIX2TEX_EXTRA_LIBRARY_PATH:-}"
logln "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-}"
logln "cache_dir: $cache_dir"
logln "work_dir: $work_dir"
logln "pix2tex model_ckpt_dir: $model_ckpt_dir"
logln "which $OCR: $(command -v "$OCR" || true)"
logln "PATH: $PATH"
logln ""

# ---- Region capture ----
region="$("$SLURP" -b "00000000" -c "e62600ff" -B "00000000" -w 2 -s "1e000080")" || exit 0
logln "region: $region"

"$GRIM" -g "$region" "$img"
logln "saved image: $img"
logln "image info:"
(file "$img" >>"$log" 2>&1) || true
logln ""

# NOTE: we DO NOT pre-seed/copy weights into the cache.
# Let pix2tex/pip-managed code handle downloading and managing the correct model files.
# This avoids state-dict/version mismatch errors.

logln "pix2tex model checkpoint dir listing (before running pix2tex):"
(ls -lah "$model_ckpt_dir" >>"$log" 2>&1) || true
logln ""

# ---- Run OCR from a cache work directory, not from the source checkout ----
cmd=( "$OCR" --no-cuda "$img" )

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
latex="${latex#"$img": }"
latex="${latex#"$img":}"
latex="$(printf '%s' "$latex" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
latex="$(strip_outer_latex_group "$latex")"

if [ $rc -ne 0 ] || [ -z "${latex// }" ]; then
  preview="$(tail -n 80 "$log" | sed 's/\t/  /g')"
  "$NOTIFY" -u critical "Math OCR failed" "cmd: $OCR (exit $rc)\n\n$preview\n\nLog: $log\nImage: $img"
  exit 1
fi

printf "%s" "$latex" >"$clip"

copy_unit="math-ocr-clipboard-$(date +%s%N)"
copy_rc=0

logln "copying to clipboard via user systemd unit: $copy_unit"
if command -v "$SYSTEMD_RUN" >/dev/null 2>&1; then
  set +e
  "$SYSTEMD_RUN" --user --quiet --collect \
    --unit "$copy_unit" \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}" \
    --setenv="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-}" \
    "${BASH:-bash}" -lc "exec \"\$1\" --foreground --type \"text/plain;charset=utf-8\" < \"\$2\"" \
    _ "$WL_COPY" "$clip" >>"$log" 2>&1
  copy_rc=$?
  set -e
else
  copy_rc=127
fi

if [ "$copy_rc" -ne 0 ]; then
  logln "systemd-run clipboard copy failed with exit $copy_rc; falling back to direct wl-copy"
  "$WL_COPY" --type "text/plain;charset=utf-8" <"$clip"
else
  logln "clipboard holder started"
fi

"$NOTIFY" "Math OCR" "Copied LaTeX to clipboard"
