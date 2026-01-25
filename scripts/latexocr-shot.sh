#!/usr/bin/env bash
set -euo pipefail

tmp="${XDG_RUNTIME_DIR:-/tmp}/latexocr-$(date +%s).png"

# Select region and capture
grim -g "$(slurp)" "$tmp"

# Run math OCR
out="$(latexocr "$tmp" 2>/dev/null | tr -d '\r')"

rm -f "$tmp"

# Copy LaTeX to clipboard
printf "%s" "$out" | wl-copy

# Optional notification
command -v notify-send >/dev/null 2>&1 && \
  notify-send "Math OCR" "LaTeX copied to clipboard"

