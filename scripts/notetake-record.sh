#!/usr/bin/env bash
# Toggleable background audio recorder for live note-taking (class, meetings,
# anything you're talking through with an agent in real time).
#
# Records in short-lived segments, never one continuous file -- pw-record only
# writes a valid WAV header on clean process exit, so a file still being written
# is NOT safely readable by other tools (confirmed: sox fails with "invalid
# chunk ID" on a file read mid-recording). notetake-foldin.sh relies on this:
# each fold-in call stops the current segment (finalizing it), transcribes it,
# and immediately starts a new one, so there's always exactly one complete,
# valid segment file covering "since the last fold-in."
#
# Usage:
#   notetake-record.sh start [pipewire-source-name]
#   notetake-record.sh stop
#   notetake-record.sh status
#
# List available sources: pactl list sources short
set -euo pipefail

STATE_DIR="$HOME/.cache/notetake"
SESSION_FILE="$STATE_DIR/session-dir"
PID_FILE="$STATE_DIR/pid"
SEGMENT_FILE="$STATE_DIR/current-segment"
SOURCE_FILE="$STATE_DIR/source"
DEFAULT_SOURCE="alsa_input.pci-0000_07_00.6.HiFi__Mic1__source"

start_segment() {
  local session_dir="$1" source="$2"
  local seg="$session_dir/segment-$(date +%s).wav"
  pw-record --target "$source" "$seg" &
  disown
  echo $! > "$PID_FILE"
  echo "$seg" > "$SEGMENT_FILE"
}

case "${1:-}" in
  start)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "notetake: already recording (segment: $(cat "$SEGMENT_FILE" 2>/dev/null))" >&2
      exit 1
    fi
    mkdir -p "$STATE_DIR"
    source_arg="${2:-$DEFAULT_SOURCE}"
    session_dir="$STATE_DIR/session-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$session_dir"
    echo "$session_dir" > "$SESSION_FILE"
    echo "$source_arg" > "$SOURCE_FILE"
    start_segment "$session_dir" "$source_arg"
    echo "notetake: recording started -> $session_dir (source: $source_arg)"
    ;;
  stop)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      kill -TERM "$(cat "$PID_FILE")"
      wait "$(cat "$PID_FILE")" 2>/dev/null || true
    fi
    rm -f "$PID_FILE" "$SEGMENT_FILE"
    echo "notetake: recording stopped. Session kept at $(cat "$SESSION_FILE" 2>/dev/null || echo '(none)') -- delete it yourself when done with it."
    ;;
  status)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "notetake: recording (segment: $(cat "$SEGMENT_FILE"))"
    else
      echo "notetake: not recording"
    fi
    ;;
  *)
    echo "usage: notetake-record.sh {start [pipewire-source]|stop|status}" >&2
    exit 2
    ;;
esac
