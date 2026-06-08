#!/usr/bin/env bash
set -euo pipefail

NOTIFY="${NOTIFY:-notify-send}"

message="Combined OCR is not implemented yet.

Planned behavior:
capture region → run combined text+math engine → copy Markdown → save review bundle.

Next implementation checkpoint: benchmark Surya against saved screen captures."

"$NOTIFY" "Combined OCR" "$message"
printf '%s\n' "$message" >&2
exit 64
