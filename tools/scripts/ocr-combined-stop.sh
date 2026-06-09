#!/usr/bin/env bash
set -euo pipefail

JQ="${JQ:-jq}"
NOTIFY="${NOTIFY:-notify-send}"

cache_dir="${SURYA_CACHE_DIR:-$HOME/.cache/datalab/surya}"
sentinel="$cache_dir/llamacpp_server.json"
lock="$cache_dir/llamacpp_server.lock"
log="$cache_dir/llamacpp_server.log"
pid=""

if [ -f "$sentinel" ] && command -v "$JQ" >/dev/null 2>&1; then
  pid="$("$JQ" -r '.pid // empty' "$sentinel" 2>/dev/null || true)"
fi

if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
fi

rm -f "$sentinel" "$lock"

"$NOTIFY" "Combined OCR" "Stopped Surya warm server and cleared lock"
printf 'Stopped Surya warm server if it was running.\n'
printf 'Removed: %s\n' "$sentinel"
printf 'Removed: %s\n' "$lock"
printf 'Log remains: %s\n' "$log"
