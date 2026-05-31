#!/usr/bin/env bash
set -euo pipefail

# record-session — record system mic until Ctrl+C, then transcribe via whisper.cpp.
#
# Usage:
#   record-session [label]
#
# Output:
#   ~/Documents/transcripts/YYYY-MM-DD-HHMMSS-<label>.wav
#   ~/Documents/transcripts/YYYY-MM-DD-HHMMSS-<label>.md
#
# Uses the multilingual small model so each segment is transcribed in its detected
# language. Translation, comparison, and other re-processing are intentionally out
# of scope — work from the WAV with other tools when needed.
#
# Model is downloaded once to ~/.cache/whisper-cpp/ on first run.

MODEL_NAME="ggml-small.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_NAME}"
MODEL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/whisper-cpp"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

OUT_DIR="$HOME/Documents/transcripts"
LABEL="${1:-session}"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
BASE="$OUT_DIR/${STAMP}-${LABEL}"
WAV="$BASE.wav"
TRANSCRIPT="$BASE.md"

mkdir -p "$OUT_DIR" "$MODEL_DIR"

if [ ! -f "$MODEL_PATH" ]; then
  echo "Downloading whisper model ($MODEL_NAME, ~466 MB) — one-time setup..."
  curl -L --fail --progress-bar -o "${MODEL_PATH}.tmp" "$MODEL_URL"
  mv "${MODEL_PATH}.tmp" "$MODEL_PATH"
fi

echo "Recording to: $WAV"
echo "Press Ctrl+C to stop and transcribe."
echo ""

REC_PID=""
on_interrupt() {
  echo ""
  echo "Stopping recording..."
  if [ -n "$REC_PID" ]; then
    kill -INT "$REC_PID" 2>/dev/null || true
  fi
}
trap on_interrupt INT

# setsid puts ffmpeg in its own process group so terminal Ctrl+C only reaches
# this script; the trap then forwards a single clean SIGINT to ffmpeg, which
# lets it write the WAV trailer instead of doing an "immediate exit".
setsid ffmpeg -hide_banner -loglevel error -nostdin -f pulse -i default -ac 1 -ar 16000 "$WAV" </dev/null &
REC_PID=$!
wait "$REC_PID" 2>/dev/null || true
trap - INT

if [ ! -s "$WAV" ]; then
  echo "Recording produced no audio. Check mic permissions or input source." >&2
  exit 1
fi

echo ""
echo "Transcribing with whisper.cpp ($MODEL_NAME) on 8 threads..."
whisper-cli \
  -m "$MODEL_PATH" \
  -f "$WAV" \
  -of "$BASE" \
  -otxt \
  -nt \
  -t 8 \
  -l auto \
  >/dev/null

{
  echo "# ${LABEL} — ${STAMP}"
  echo ""
  echo "**Audio:** \`${WAV}\`"
  echo ""
  echo "## Transcript"
  echo ""
  cat "${BASE}.txt"
} > "$TRANSCRIPT"

rm -f "${BASE}.txt"

echo ""
echo "Transcript: $TRANSCRIPT"
echo "Audio:      $WAV"
