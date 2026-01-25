#!/usr/bin/env bash
set -euo pipefail

# Ferrari red border + transparent-ish red background outside selection.
# NOTE: slurp's -b colors the *background outside* the selection, not the captured image.
BORDER="#E62600FF"
# More transparent than before (0x22 ~= 13% opacity)
BG="#E6260022"

# Tools (resolved via PATH from Nix module)
: "${SLURP:=slurp}"
: "${GRIM:=grim}"
: "${WL_COPY:=wl-copy}"
: "${NOTIFY:=notify-send}"
: "${PIX2TEX:=pix2tex}"

tmp="$(mktemp --suffix=.png)"
log="$(mktemp)"
cleanup() { rm -f "$tmp" "$log"; }
trap cleanup EXIT

# Pick a region
geom="$("$SLURP" -d -c "$BORDER" -b "$BG")" || exit 0

# Capture it
"$GRIM" -g "$geom" -t png "$tmp"

# Run OCR
# pix2tex prints LaTeX to stdout; errors to stderr
latex="$("$PIX2TEX" "$tmp" 2>"$log" || true)"

# Trim whitespace
latex="$(printf "%s" "$latex" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//')"

if [ -z "$latex" ]; then
  tailmsg="$(tail -n 12 "$log" | sed 's/[[:cntrl:]]//g')"
  "$NOTIFY" -u critical "Math OCR failed" "${tailmsg:-No output from pix2tex.}"
  exit 1
fi

# Copy to clipboard (Wayland)
printf "%s" "$latex" | "$WL_COPY" --type text/plain;charset=utf-8

# Notify (truncate body so notifications don't get huge)
short="$(printf "%s" "$latex" | head -c 160)"
"$NOTIFY" "Math OCR" "Copied LaTeX to clipboard:\n$short"

