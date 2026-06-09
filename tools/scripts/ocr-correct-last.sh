#!/usr/bin/env bash
set -euo pipefail

WL_PASTE="${WL_PASTE:-wl-paste}"
NOTIFY="${NOTIFY:-notify-send}"
JQ="${JQ:-jq}"

real_home="$(getent passwd "$(id -un)" | cut -d: -f6 || true)"
if [ -z "${HOME:-}" ] || [ "${HOME:-}" = "/homeless-shelter" ]; then
  export HOME="${real_home:-/tmp}"
fi

capture_root="${OCR_CAPTURE_DIR:-$HOME/.local/share/ocr-captures}"
latest="$capture_root/latest"
from_clipboard=false
target="${latest}"

usage() {
  cat <<'EOF'
Usage:
  ocr-correct-last
  ocr-correct-last --from-clipboard
  ocr-correct-last <attempt-id-or-dir>
  ocr-correct-last --from-clipboard <attempt-id-or-dir>

Open or update an OCR attempt review file.

The primary correction interface is:
  ~/.local/share/ocr-captures/attempts/<attempt-id>/review.md

With no arguments, this opens the latest attempt's review.md in $VISUAL or $EDITOR.
With --from-clipboard, the current text clipboard replaces the `## Correction` block.
If an attempt id or directory is provided, that older attempt is targeted instead of latest.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --from-clipboard)
      from_clipboard=true
      shift
      ;;
    *)
      target="$1"
      shift
      ;;
  esac
done

resolve_attempt_dir() {
  local candidate="$1"

  if [ -e "$candidate" ]; then
    readlink -f "$candidate"
    return
  fi

  if [ -d "$capture_root/attempts/$candidate" ]; then
    readlink -f "$capture_root/attempts/$candidate"
    return
  fi

  printf 'OCR attempt not found: %s\n' "$candidate" >&2
  exit 1
}

replace_correction_block() {
  local review="$1"
  local replacement="$2"
  local tmp

  tmp="$(mktemp)"
  awk -v replacement_file="$replacement" '
    BEGIN {
      in_correction = 0
      fence_count = 0
      replacement = ""
      while ((getline line < replacement_file) > 0) {
        replacement = replacement line ORS
      }
      close(replacement_file)
    }
    /^status: / {
      print "status: corrected"
      next
    }
    $0 == "## Correction" {
      print
      in_correction = 1
      fence_count = 0
      next
    }
    in_correction && /^```/ {
      fence_count++
      print
      if (fence_count == 1) {
        printf "%s", replacement
      }
      if (fence_count >= 2) {
        in_correction = 0
      }
      next
    }
    in_correction && fence_count == 1 {
      next
    }
    { print }
  ' "$review" >"$tmp"
  mv "$tmp" "$review"
}

attempt_dir="$(resolve_attempt_dir "$target")"
if [ ! -d "$attempt_dir" ]; then
  printf 'OCR attempt is not a directory: %s\n' "$attempt_dir" >&2
  exit 1
fi

review="$attempt_dir/review.md"
correction_metadata="$attempt_dir/correction-metadata.json"

if [ ! -f "$review" ]; then
  printf 'OCR attempt has no review.md: %s\n' "$attempt_dir" >&2
  exit 1
fi

if [ "$from_clipboard" = true ]; then
  clipboard_tmp="$(mktemp)"
  "$WL_PASTE" --type "text/plain" >"$clipboard_tmp"
  replace_correction_block "$review" "$clipboard_tmp"
  corrected_bytes="$(wc -c <"$clipboard_tmp" | tr -d ' ')"
  rm -f "$clipboard_tmp"

  "$JQ" -n \
    --arg corrected_at "$(date -Is)" \
    --arg source "clipboard" \
    --arg attempt_dir "$attempt_dir" \
    --arg review "$review" \
    --arg corrected_bytes "$corrected_bytes" \
    '{
      corrected_at: $corrected_at,
      source: $source,
      attempt_dir: $attempt_dir,
      review: $review,
      corrected_bytes: ($corrected_bytes | tonumber? // 0)
    }' >"$correction_metadata"

  "$NOTIFY" "OCR correction saved" "$review"
  printf 'Saved correction in: %s\n' "$review"
else
  editor="${VISUAL:-${EDITOR:-}}"
  if [ -z "$editor" ]; then
    printf 'Set VISUAL or EDITOR, or edit directly: %s\n' "$review" >&2
    exit 1
  fi

  "$editor" "$review"
  printf 'Edited review: %s\n' "$review"
fi
