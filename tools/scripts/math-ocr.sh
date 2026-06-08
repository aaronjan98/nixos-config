#!/usr/bin/env bash
set -euo pipefail

GRIM="${GRIM:-grim}"
SLURP="${SLURP:-slurp}"
WL_COPY="${WL_COPY:-wl-copy}"
NOTIFY="${NOTIFY:-notify-send}"
SYSTEMD_RUN="${SYSTEMD_RUN:-systemd-run}"
JQ="${JQ:-jq}"

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
capture_root="${OCR_CAPTURE_DIR:-$HOME/.local/share/ocr-captures}"
attempt_timestamp="$(date +%Y-%m-%dT%H-%M-%S.%N%z)"
attempt_id="${attempt_timestamp}_math"
attempt_dir="$capture_root/attempts/$attempt_id"
metadata="$attempt_dir/metadata.json"
attempt_review="$attempt_dir/review.md"
capture_readme="$capture_root/README.md"
capture_review="$capture_root/review.md"

mkdir -p "$cache_dir" "$work_dir" "$attempt_dir"

img="$attempt_dir/input.png"
log="$attempt_dir/backend.log"
out="$attempt_dir/raw-output.txt"
normalized_out="$attempt_dir/normalized-output.txt"
readme="$attempt_dir/README.md"
clip="$normalized_out"
region=""
start_epoch_ns="$(date +%s%N)"

: >"$log"
: >"$out"
: >"$normalized_out"

cat >"$readme" <<EOF
# OCR Attempt Correction

Edit review.md directly if the OCR result is wrong.

Useful files:

- input.png — captured image
- raw-output.txt — raw engine output
- normalized-output.txt — normalized clipboard output
- review.md — editable review/correction file
- metadata.json — attempt metadata
- backend.log — debug log

The training/evaluation workflow should treat review.md as the human-facing source of truth.
EOF

if [ ! -f "$capture_readme" ]; then
  cat >"$capture_readme" <<'EOF'
# OCR Captures

This directory stores OCR attempts.

Start here:

- `review.md` — review queue/history; remove entries you do not care about.
- `attempts/<attempt-id>/review.md` — screenshot, raw output, normalized output, correction, and notes for one attempt.
- `latest` — newest OCR attempt of any type.
- `latest-math` — newest math OCR attempt.
- `latest-text` — newest text OCR attempt.
- `latest-combined` — newest combined OCR attempt.

Recommended workflow:

1. Open `review.md` to find attempts that need review.
2. Open the linked `attempts/<attempt-id>/review.md`.
3. Edit the `## Correction` block if the OCR is wrong.
4. Set front matter `status:` to `corrected`, `accepted`, or `ignored`.
5. Remove the entry from this queue if it is not useful to keep reviewing.

Convenience commands:

- `ocr-correct-last` — open `latest/review.md` in `$VISUAL` or `$EDITOR`.
- `ocr-correct-last --from-clipboard` — replace `latest/review.md`'s `## Correction` block with the current clipboard and set `status: corrected`.
- `ocr-correct-last <attempt-id-or-dir>` — open an older attempt's `review.md`.

Capture commands:

- `math-ocr` — isolated formula to LaTeX.
- `text-ocr` — selected text region to plain text.
- `ocr-combined` — selected text+math region to Markdown/HTML using Surya.

Each attempt is safe to edit manually. For model improvement, the important field is the `## Correction` section in an attempt's `review.md`.

The default location is `~/.local/share/ocr-captures`. Override it with `OCR_CAPTURE_DIR`.
EOF
fi

if [ ! -f "$capture_review" ]; then
  cat >"$capture_review" <<'EOF'
# OCR Review Queue

This file is the triage/history list for OCR attempts.

How to use it:

1. Open the linked per-attempt `review.md`.
2. Compare the screenshot with the raw/normalized OCR output.
3. Edit that attempt's `## Correction` block if the OCR is wrong.
4. Remove entries here when you do not care about that attempt.

Removing an entry here does not delete the attempt bundle. It only hides that attempt from this review queue.

Status is stored in each attempt's `review.md` front matter:

- `needs-review` — model output has not been checked.
- `corrected` — correction was provided.
- `accepted` — output was good as-is.
- `ignored` — not useful for training/evaluation.

## Attempts
EOF
fi

ln -sfn "$attempt_dir" "$capture_root/latest"
ln -sfn "$attempt_dir" "$capture_root/latest-math"
ln -sfn "$attempt_dir" "$cache_dir/last-attempt"
ln -sfn "$img" "$cache_dir/last.png"
ln -sfn "$log" "$cache_dir/last.log"
ln -sfn "$out" "$cache_dir/last.txt"
ln -sfn "$normalized_out" "$cache_dir/last-clipboard.txt"
ln -sfn "$attempt_review" "$cache_dir/last-review.md"

logln() { printf '%s\n' "$*" >>"$log"; }

elapsed_ms() {
  local end_epoch_ns
  end_epoch_ns="$(date +%s%N)"
  printf '%s' $(((end_epoch_ns - start_epoch_ns) / 1000000))
}

write_metadata() {
  local status="$1"
  local exit_code="${2:-}"
  local duration_ms="${3:-0}"
  local output_bytes="${4:-0}"

  "$JQ" -n \
    --arg timestamp "$attempt_timestamp" \
    --arg attempt_id "$attempt_id" \
    --arg command "math-ocr" \
    --arg backend "${OCR_BACKEND:-local}" \
    --arg engine "pix2tex" \
    --arg engine_path "${OCR:-}" \
    --arg runtime_dir "$RUNTIME_DIR" \
    --arg venv_dir "$VENV_DIR" \
    --arg input "$img" \
    --arg raw_output "$out" \
    --arg normalized_output "$normalized_out" \
    --arg review "$attempt_review" \
    --arg log "$log" \
    --arg region "$region" \
    --arg host "$(hostname)" \
    --arg user "$(id -un)" \
    --arg status "$status" \
    --arg exit_code "$exit_code" \
    --arg duration_ms "$duration_ms" \
    --arg output_bytes "$output_bytes" \
    '{
      timestamp: $timestamp,
      attempt_id: $attempt_id,
      command: $command,
      backend: $backend,
      engine: {
        name: $engine,
        path: $engine_path,
        runtime_dir: $runtime_dir,
        venv_dir: $venv_dir
      },
      files: {
        input: $input,
        raw_output: $raw_output,
        normalized_output: $normalized_output,
        review: $review,
        log: $log
      },
      capture: {
        region: $region
      },
      host: $host,
      user: $user,
      status: $status,
      exit_code: ($exit_code | tonumber? // null),
      duration_ms: ($duration_ms | tonumber? // 0),
      output_bytes: ($output_bytes | tonumber? // 0)
    }' >"$metadata"
}

write_attempt_review() {
  local status="$1"
  local corrected_text="${2:-}"

  {
    cat <<EOF
---
id: $attempt_id
type: math
status: $status
backend: ${OCR_BACKEND:-local}
engine: pix2tex
input: input.png
created_at: $attempt_timestamp
region: "$region"
---

# OCR Attempt

![capture](input.png)

## How To Review

- If the OCR is wrong, edit the \`## Correction\` block.
- If the OCR is useful for training, set \`status: corrected\` after editing.
- If the OCR was already good, set \`status: accepted\`.
- If this attempt is not useful, set \`status: ignored\` or remove its entry from \`../../review.md\`.
- This file is the source of truth; \`../../review.md\` is only the queue/history index.

## Raw Output

\`\`\`text
EOF
    cat "$out"
    printf '\n'
    cat <<EOF
\`\`\`

## Normalized Output

\`\`\`latex
EOF
    cat "$normalized_out"
    printf '\n'
    cat <<EOF
\`\`\`

## Correction

\`\`\`latex
EOF
    printf '%s\n' "$corrected_text"
    cat <<'EOF'
```

## Notes

- 
EOF
  } >"$attempt_review"
}

append_review_queue_entry() {
  local status="$1"
  local relative_review="attempts/$attempt_id/review.md"
  {
    printf -- '- [ ] `%s` `%s` `%s`\n' "$attempt_timestamp" "math" "$status"
    printf '  - Review: [%s](%s)\n' "$relative_review" "$relative_review"
    printf '  - Image: [input.png](%s)\n' "attempts/$attempt_id/input.png"
    printf '  - Output: edit the `## Correction` block in the linked `review.md` if this was wrong.\n'
    printf '  - Notes:\n'
  } >>"$capture_review"
}

write_metadata "started"
write_attempt_review "started"

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
  write_metadata "failed" 127 "$(elapsed_ms)" 0
  write_attempt_review "failed"
  append_review_queue_entry "failed"
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
logln "capture_root: $capture_root"
logln "attempt_dir: $attempt_dir"
logln "metadata: $metadata"
logln "pix2tex model_ckpt_dir: $model_ckpt_dir"
logln "which $OCR: $(command -v "$OCR" || true)"
logln "PATH: $PATH"
logln ""

# ---- Region capture ----
region="$("$SLURP" -b "00000000" -c "e62600ff" -B "00000000" -w 2 -s "1e000080")" || {
  write_metadata "cancelled" 0 "$(elapsed_ms)" 0
  write_attempt_review "cancelled"
  exit 0
}
logln "region: $region"
write_metadata "captured" "" "$(elapsed_ms)" 0

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
stdout_bytes="$(wc -c <"$out" | tr -d ' ')"
logln "stdout bytes: $stdout_bytes"

latex="$(tr -d '\r' <"$out" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
latex="${latex#"$img": }"
latex="${latex#"$img":}"
latex="$(printf '%s' "$latex" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
latex="$(strip_outer_latex_group "$latex")"
printf "%s" "$latex" >"$normalized_out"

if [ $rc -ne 0 ] || [ -z "${latex// }" ]; then
  write_metadata "failed" "$rc" "$(elapsed_ms)" "$stdout_bytes"
  write_attempt_review "failed"
  append_review_queue_entry "failed"
  preview="$(tail -n 80 "$log" | sed 's/\t/  /g')"
  "$NOTIFY" -u critical "Math OCR failed" "cmd: $OCR (exit $rc)\n\n$preview\n\nLog: $log\nImage: $img"
  exit 1
fi

write_metadata "succeeded" "$rc" "$(elapsed_ms)" "$stdout_bytes"
write_attempt_review "needs-review" "$latex"
append_review_queue_entry "needs-review"

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
