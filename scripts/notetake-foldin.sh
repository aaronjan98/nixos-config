#!/usr/bin/env bash
# Rotate the current notetake-record.sh segment (finalizing it so it has a valid
# WAV header), transcribe it with whisper-cli, print the text, and immediately
# start a new segment so recording keeps going with no gap beyond the rotation
# itself (sub-second). Run this whenever you want "what was just said" as text
# to hand to the agent -- see notetake-record.sh for why segments are required.
#
# Usage: notetake-foldin.sh
# Prints the transcript of everything recorded since the last fold-in (or since
# `notetake-record.sh start`, on the first call) to stdout.
set -euo pipefail

STATE_DIR="$HOME/.cache/notetake"
SESSION_FILE="$STATE_DIR/session-dir"
PID_FILE="$STATE_DIR/pid"
SEGMENT_FILE="$STATE_DIR/current-segment"
SOURCE_FILE="$STATE_DIR/source"
MODEL_DIR="$STATE_DIR/models"
MODEL="${NOTETAKE_WHISPER_MODEL:-$MODEL_DIR/ggml-base.en.bin}"

if [[ ! -f "$PID_FILE" ]] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "notetake: not currently recording -- run notetake-record.sh start first" >&2
  exit 1
fi

old_pid="$(cat "$PID_FILE")"
old_segment="$(cat "$SEGMENT_FILE")"
session_dir="$(cat "$SESSION_FILE")"
source="$(cat "$SOURCE_FILE")"

# Finalize the current segment by stopping it -- pw-record only writes a valid
# WAV header on clean exit, not while still recording.
kill -TERM "$old_pid"
wait "$old_pid" 2>/dev/null || true

# Start the next segment immediately so recording keeps going.
new_seg="$session_dir/segment-$(date +%s).wav"
pw-record --target "$source" "$new_seg" &
disown
echo $! > "$PID_FILE"
echo "$new_seg" > "$SEGMENT_FILE"

# Transcribe the just-finalized segment (download the model once, on first use).
if [[ ! -f "$MODEL" ]]; then
  mkdir -p "$MODEL_DIR"
  nix-shell -p whisper-cpp --run "whisper-cpp-download-ggml-model base.en '$MODEL_DIR'" >&2
fi
nix-shell -p whisper-cpp --run "whisper-cli -m '$MODEL' -f '$old_segment' -nt -np" 2>/dev/null
