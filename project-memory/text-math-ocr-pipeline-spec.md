# Text + Math OCR Pipeline Spec

**Status:** Checkpoint 8 blocked locally; Surya 2 warm runtime needs newer `llama.cpp`, stable local path restored to Surya 0.16
**Goal:** Build a reliable Mathpix-like workflow for screen captures and documents that can extract plain text, math LaTeX, and combined Markdown, while preserving failed OCR examples for correction and future model improvement.

---

## Plain-English Model

This project is bigger than `math-ocr`.

There are three different jobs that should not be confused:

1. **Math OCR**: turn an isolated formula image into LaTeX.
2. **Text OCR**: turn normal printed text in an image into plain text.
3. **Combined OCR**: turn a region/page containing both text and math into structured Markdown.

The current `math-ocr` implementation only solves job 1 mechanically. It can take a screenshot, run pix2tex, and copy LaTeX to the clipboard. It does not understand page layout, paragraphs, mixed text/math, or textbook-style pages.

The broader target is closer to Mathpix:

- capture a screen region or page image;
- identify text regions and math regions;
- run the correct OCR engine on each;
- merge the results into usable Markdown;
- save bad examples so the system can improve over time.

---

## Current State

### Completed pix2tex slice

`project-memory/math-ocr-pix2tex-venv-spec.md` owns the current pix2tex-only implementation.

Current status:

- `math-ocr` is installed from `~/nixos-config/tools`.
- `math-ocr` calls `~/Repositories/automation/pix2tex/.venv/bin/pix2tex`.
- `bootstrap-pix2tex` creates/repairs the local pix2tex repo and venv.
- `text-ocr` is implemented as a local Tesseract baseline using the same archive/review workflow.
- `ocr-combined` is implemented as a local Surya probe using the same archive/review workflow.
- `bootstrap-surya-ocr` creates/repairs the mutable Surya venv at `~/.local/share/ocr-runtimes/surya`.
- The current working local Surya pin is `surya-ocr==0.16.0`.
- Surya 2 warm mode was tested and blocked because the current Nix `llama-server` cannot load Surya 2's `qwen35` GGUF model architecture.
- `Super+M` is the intended math OCR hotkey.
- `nrt` has verified the wrapper in the current test generation.
- `nrs` has not been run for this branch unless the user later chooses to promote it.

Known limitation:

- pix2tex quality is inconsistent. It works on some simple formulas but fails badly on more complex expressions. This is model/input-bound, not a Nix plumbing issue.

### Related local notes

The broader OCR idea appears in the zettelkasten, not as a finished `~/nixos-config` project spec.

Relevant notes:

- `/home/aj/Repositories/self-hosted/zettelkasten/Staging/free alternatives to Mathpix.md`
- `/home/aj/Repositories/self-hosted/zettelkasten/Staging/retrain or fine-tune Pix2Text.md`
- `/home/aj/Repositories/self-hosted/zettelkasten/Inside/Paper/AI responses/Would Training or Refining Pix2Text Be a Good ML Portfolio Project?.md`
- `/home/aj/Repositories/self-hosted/zettelkasten/Inside/Projects/Install OCR on nix.md`

Interpretation:

- Surya is the current higher-priority all-in-one candidate for layout + text + math screen captures.
- Pix2Text remains relevant mainly because it appears in AJ's earlier notes and can be used for comparison.
- pix2tex / LaTeX-OCR is a narrower math-only component.
- The current NixOS work intentionally solved the pix2tex runtime slice first.

### Existing adjacent tooling

- `scripts/doc-scan.py` exists as a document image cleanup helper, not as a full OCR pipeline.
- `wol-sauron` exists, so the laptop already has a pattern for waking or targeting `sauron`.
- Prior project memory mentions AI services on `sauron`, including Ollama/API style workflows.

---

## Proposed Command Model

Use separate commands first. Do not prematurely force everything through one tool.

### `math-ocr`

Purpose:

- Capture a small region containing one formula.
- Return LaTeX.

Current backend:

- pix2tex from `~/Repositories/automation/pix2tex/.venv`.

Future improvements:

- Save every attempt to an OCR archive.
- Add correction capture.
- Add retry variants such as `--no-resize`, lower temperature, or alternative preprocessing.
- Optional remote backend on `sauron`.

### `text-ocr`

Purpose:

- Capture a region containing normal printed text.
- Return plain text.

Candidate local backends:

- Tesseract for mature local OCR and a cheap baseline.
- OCRmyPDF/Tesseract for document/page workflows.
- PaddleOCR/EasyOCR only if accuracy justifies the Python runtime complexity.

Candidate remote backend:

- A small OCR API on `sauron`, especially if a heavier Python model gives better results than Tesseract.

Output:

- Plain text copied to clipboard.
- Raw attempt saved to the OCR archive.

Current baseline:

- `text-ocr` captures a selected screen region.
- It runs Tesseract locally with `TEXT_OCR_LANG=eng` and `TEXT_OCR_PSM=6` by default.
- It saves the attempt as `~/.local/share/ocr-captures/attempts/<timestamp>_text`.
- It intentionally does not implement `OCR_BACKEND=sauron` yet.

### `ocr-combined`

Purpose:

- Capture a region or page containing paragraphs plus formulas.
- Return Markdown with text and math.

Candidate backends:

1. Custom pipeline:
   - detect layout / regions;
   - send text regions to `text-ocr`;
   - send math regions to `math-ocr`;
   - merge output into Markdown.
2. Surya-style all-in-one pipeline:
   - run a newer document OCR/layout model that can emit text, math, tables, and reading order;
   - use local or `sauron` runtime depending on speed and install complexity.
3. Pix2Text-style all-in-one pipeline.

Recommendation:

- Keep `math-ocr` and `text-ocr` as baseline commands and comparison tools.
- Do not assume a hand-rolled splitter is the fastest path anymore.
- Benchmark Surya on saved screen captures before investing heavily in custom merging logic.
- Keep Pix2Text as a lower-priority candidate backend/prototype, especially for historical comparison with AJ's earlier notes.
- Keep the command boundary separate so either strategy can be swapped behind `ocr-combined`.

Current Surya probe:

- `ocr-combined` captures a selected screen region.
- It saves the input as `~/.local/share/ocr-captures/attempts/<timestamp>_combined/input.png`.
- It runs `~/.local/share/ocr-runtimes/surya/.venv/bin/surya_ocr input.png --output_dir <attempt>/surya`.
- It extracts Surya block `html` in reading order into `normalized-output.txt`.
- It normalizes Surya `<math>...</math>` tags into Markdown inline math `$...$`.
- It saves the original Surya JSON at `surya/results.json` and `raw-output.txt`.
- It intentionally does not implement `OCR_BACKEND=sauron` yet.
- `ocr-combined-stop` stops the warm Surya server and clears Surya's spawn lock.
- Local warm mode is not currently installed as a supported command because Surya 2 requires newer `llama.cpp` support than the host package provides.

Why Surya fits screen capture:

- Surya's CLI accepts an image path as `DATA_PATH`, not only PDFs.
- The screen capture pipeline already produces an image path (`input.png`).
- Surya's OCR output includes layout-labeled blocks, reading order, `html`, bounding boxes, and confidence.
- Surya 2 handles equations inline in the full-page OCR output using `<math>...</math>` tags, so it is a plausible first combined OCR backend.
- The main caveat is runtime cost: Surya 2 needs an inference backend (`llama.cpp` on CPU/Apple Silicon or `vllm` on NVIDIA GPU).

Output:

- HTML/Markdown-ish combined output copied to clipboard.
- Attempt bundle saved to the OCR archive.

---

## Local vs Remote Runtime Model

The command surface should be local and stable. The expensive OCR backend may be local or remote.

### Local laptop mode

Pros:

- Works offline.
- No network dependency.
- Easier privacy model.

Cons:

- Startup can be slow because ML models load each invocation.
- CPU-only inference may be poor for heavier models.
- Training/fine-tuning is not practical on the laptop CPU.

### Remote `sauron` mode

Pros:

- Can keep models warm in a daemon.
- Can use stronger CPU/GPU resources if available.
- Laptop command becomes fast: screenshot upload → API response → clipboard.
- Centralizes mutable Python/ML environments away from NixOS laptop rebuilds.

Cons:

- Requires network access and host availability.
- Requires authentication and a safe API boundary.
- Must handle wake/retry/failure behavior cleanly.
- Sensitive screenshots leave the laptop, even if only to a trusted home server.

### Recommended policy

Make backend selection explicit:

```text
OCR_BACKEND=local
OCR_BACKEND=sauron
OCR_BACKEND=auto
```

Recommended first behavior:

- `local`: use local tools only.
- `sauron`: require reachable remote API; fail clearly if unavailable.
- `auto`: try `sauron`, then fall back to local if the command can do so without surprising the user.

Resolved decision:

- `sauron` should be optional and easy to turn on/off for local-versus-remote testing.
- Do not silently send screenshots to `sauron` unless the command/config explicitly says remote mode is allowed.

### Remote OCR API checkpoint

The remote OCR path should reuse the video-summary operational pattern, not invent a new deployment model.

Sauron facts:

- Host aliases: `sauron` externally and `sauron.home` on LAN.
- Wake command on the laptop: `wol-sauron`.
- Existing video-summary client wakes Sauron, waits for SSH, then calls a localhost FastAPI service through SSH.
- Existing server app pattern: `/opt/ai-services/<service>/`, Python venv inside that directory, systemd service as user `aj`, LAN/localhost API.

Recommended first remote OCR slice:

1. Add a separate service on Sauron at `/opt/ai-services/ocr-api`, not an endpoint inside `summarizer-api`. Implemented.
2. Use `surya-ocr==0.16.0` first because it is the currently working local combined OCR runtime. Implemented.
3. Expose `POST /ocr/combined` accepting raw PNG bytes and returning JSON with normalized text plus raw Surya output. Implemented.
4. Run the service on localhost only, e.g. `127.0.0.1:8011`, and call it through `ssh sauron 'curl ... --data-binary @-'`. Implemented.
5. Add `OCR_BACKEND=sauron` to `ocr-combined`; the command still captures locally, archives locally, wakes Sauron, waits for SSH, POSTs the screenshot, copies the returned text to the clipboard, and stores the remote response in the same attempt bundle. Implemented and validated with a saved screenshot.
6. Add `ocr-combined-sauron` as the explicit remote wrapper so local and Sauron speed tests can use separate commands and keybinds.
7. Keep `OCR_BACKEND=local` as the default unless the user explicitly switches the backend.

Current remote service state:

- Service path: `/opt/ai-services/ocr-api`.
- Systemd unit: `/etc/systemd/system/ocr-api.service`.
- Tracked source repo: `/opt/ai-services/ocr-api`, branch `main`.
- Remote: `home = sweetpea-git:/srv/git/repos/sauron-ocr-api.git`.
- Forgejo: `https://git.aaronjanovitch.com/aj/sauron-ocr-api`.
- Health endpoint: `ssh sauron 'curl -fsS http://127.0.0.1:8011/health'`.

Why this first slice is not Surya 2:

- Local Surya 2 warm mode failed because the current Nix `llama-server` could not load Surya 2's `qwen35` GGUF architecture.
- Sauron might still become the Surya 2 host later if it gets a compatible newer `llama.cpp` or another backend, but the first useful checkpoint is remote transport and API shape.
- A separate OCR API keeps the door open to swap its backend from Surya 0.16 CLI to in-process Surya predictors, Surya 2, Pix2Text, or a custom pipeline without changing the laptop command surface.

What "hot" means right now:

- The Sauron service is now hot in the model-resident sense: `ocr-api.service` loads Surya predictors into the FastAPI process and reuses them across requests.
- The service exposes `/warmup`; the laptop wrapper calls it before `POST /ocr/combined` when `SAURON_WARMUP=1`.
- The loaded objects are Surya 0.16 `FoundationPredictor`, `DetectionPredictor`, and `RecognitionPredictor`.
- Sauron auto-suspend still applies. The laptop command sends Wake-on-LAN, waits for SSH, then calls the localhost API through SSH. If Sauron is asleep, the first request includes wake time; if it is already awake, it skips most of that overhead.
- Current remote backend is `surya-ocr==0.16.0` with `torch==2.7.1+cu126`, not Surya 2.0.
- CUDA 12.6 is intentional: newer CUDA 13 PyTorch wheels initialize on Sauron after driver 580, but they do not ship kernels for the Quadro M5000's `sm_52` compute capability.
- Validation on a saved screenshot showed startup model load around 5s and hot in-process CUDA OCR around 22.5s server-side.

---

## Feedback Archive

The feedback archive is the bridge between daily use and future model improvement.

Every OCR command should save an attempt bundle before copying output.

Recommended path:

```text
~/.local/share/ocr-captures/
  README.md
  review.md                     # triage/history queue; safe to edit/remove entries
  latest -> attempts/<attempt-id>          # newest attempt of any type
  latest-math -> attempts/<attempt-id>     # newest math attempt
  latest-text -> attempts/<attempt-id>     # newest text attempt
  latest-combined -> attempts/<attempt-id> # newest combined attempt
  attempts/
    2026-06-07T23-15-22_math/
      README.md
      input.png
      metadata.json
      raw-output.txt
      normalized-output.txt
      review.md                   # screenshot, raw output, normalized output, correction, notes
      render-status.json          # optional for LaTeX/Markdown validation
      backend.log
```

Resolved decision:

- Use `~/.local/share/ocr-captures` as the archive root.

### Metadata

`metadata.json` should include:

- timestamp;
- command: `math-ocr`, `text-ocr`, or `ocr-combined`;
- backend: `local`, `sauron`, or `auto`;
- selected region geometry;
- host and user;
- engine name and version/commit if known;
- command arguments;
- runtime duration;
- output byte count;
- success/failure status.

### Why this matters

Without this archive, bad OCR outputs disappear into the clipboard and there is no training/evaluation data.

With this archive, each mistake becomes a useful example:

- input image;
- model guess;
- user correction, usually by editing the `## Correction` block in `review.md`;
- backend metadata.

This supports:

- manual review;
- accuracy benchmarking;
- prompt/model comparisons;
- future fine-tuning datasets.

---

## Correction Workflow

Add editable correction files before attempting training.

Resolved preference:

- Every attempt should contain `review.md` immediately.
- AJ can correct any previous attempt by editing `~/.local/share/ocr-captures/attempts/<attempt-id>/review.md`.
- The `## Correction` block in `review.md` is the primary human-editable correction field.
- `~/.local/share/ocr-captures/review.md` is only the triage/history queue; removing entries from it should not delete attempt bundles.
- Correction commands are convenience helpers, not the primary data model.

### `ocr-correct`

Purpose:

- Edit the most recent OCR output and save the corrected result.
- Optional convenience command; direct file editing is preferred for older attempts.

Suggested flow:

1. User runs `math-ocr`, `text-ocr`, or `ocr-combined`.
2. Output is copied to clipboard.
3. If wrong, user runs `ocr-correct`.
4. The command opens `$EDITOR` with the last normalized output.
5. Saved text updates the `## Correction` block in the attempt bundle's `review.md`.

### `ocr-correct-last --from-clipboard`

Purpose:

- Let the user correct OCR output in any editor/chat/tool, copy the corrected version, then attach it to the latest attempt.

Suggested flow:

```text
ocr-correct-last --from-clipboard
```

This is useful because AJ often already knows the correct LaTeX after seeing the bad output.

### `ocr-review`

Purpose:

- List recent failed or corrected OCR attempts.

Useful filters:

- `ocr-review --math`
- `ocr-review --text`
- `ocr-review --combined`
- `ocr-review --uncorrected`
- `ocr-review --corrected`

### `ocr-export-dataset`

Purpose:

- Export corrected attempts into a dataset format suitable for evaluation or training.

Possible exports:

- pix2tex-style image + LaTeX pairs;
- Pix2Text-style image + Markdown pairs;
- text OCR image + text pairs;
- JSONL for analysis.

---

## Training and Fine-Tuning Position

Do not start with training.

Reason:

- Training requires high-quality paired examples.
- The laptop is not the right place for serious training.
- Fine-tuning before collecting examples risks optimizing for guesses instead of measured failure cases.

Recommended sequence:

1. Build feedback archive.
2. Collect corrections during real use.
3. Add evaluation scripts.
4. Compare local pix2tex, Pix2Text, and possibly remote models.
5. Only then decide whether fine-tuning is justified.

Minimum useful dataset target:

- 50 examples: useful for qualitative review.
- 200 examples: useful for measuring recurring failure modes.
- 500+ examples: starts to become meaningful for fine-tuning or model adaptation.

Training target:

- Prefer `sauron` or another GPU/cloud workstation.
- Treat training as a separate project with its own repo/spec, not as an incidental NixOS wrapper feature.

---

## Speed Strategy

### Current bottleneck

The current pix2tex command loads the model every time. That is likely more important than raw CPU utilization.

### Better speed improvements

1. Warm daemon:
   - keep model loaded;
   - command sends image to daemon;
   - daemon returns text.

2. Remote warm daemon on `sauron`:
   - strongest candidate if local startup remains slow;
   - lets laptop command stay lightweight.

3. CPU threading:
   - set `OMP_NUM_THREADS`, `MKL_NUM_THREADS`, or PyTorch thread settings;
   - benchmark before making permanent;
   - may make laptop less responsive.

4. Preprocessing:
   - crop tightly;
   - normalize background/contrast;
   - resize to model-friendly dimensions;
   - can improve quality and sometimes speed.

---

## Proposed Implementation Phases

Progress is tracked here. Do not implement later phases until the prior checkpoint is verified.

| Checkpoint | Status | Exit Criteria |
|---|---|---|
| 1. Confirm architecture choices | Complete | User chooses local/remote defaults and command names |
| 2. Add attempt archive | Implemented | `math-ocr` saves input/output/metadata for each run |
| 3. Add correction files and commands | Implemented | User can edit corrected output for any attempt |
| 4. Add text OCR command | Implemented | `text-ocr` captures region and copies plain text |
| 5. Add combined OCR prototype | Implemented | `ocr-combined` runs Surya on screen capture and returns normalized block HTML |
| 6. Evaluate backend quality | In progress | Compare local pix2tex/Tesseract/Surya/Pix2Text on saved examples |
| 7. Decide remote `sauron` service | Pending | API contract and auth model chosen |
| 8. Optional warm daemon | Blocked locally | Surya 2 warm runtime requires newer `llama.cpp` support for `qwen35` than the current host package provides |
| 9. Dataset export | Pending | Corrected examples can export to training/eval format |
| 10. Training/fine-tuning decision | Pending | Enough corrected examples exist to justify training |

---

## Phase 1 Decisions

Resolved answers:

- Archive location: `~/.local/share/ocr-captures`.
- `sauron`: optional backend that can be turned on/off to compare local and remote behavior.
- Combined OCR: benchmark Surya before building custom layout splitting; keep custom routing and Pix2Text as comparison/fallback paths.

Remaining questions:

1. **Command names**
   - Recommended: `math-ocr`, `text-ocr`, `ocr-combined`, `ocr-correct`, `ocr-review`.

2. **Default backend**
   - Recommended now: local for `math-ocr`; explicit selectable backend for future `text-ocr` and `ocr-combined`.
   - If speed matters more than offline use, prototype `sauron` earlier.

3. **Remote privacy policy**
   - Resolved: only when `OCR_BACKEND=sauron` or `OCR_BACKEND=auto` is explicitly configured.

4. **Archive location**
   - Resolved: `~/.local/share/ocr-captures`.

5. **Correction UX**
   - Resolved: every attempt gets editable `review.md`; support `$EDITOR` and `--from-clipboard` as convenience paths.

6. **Text OCR backend**
   - Implemented first local backend: Tesseract, because it is mature and easy to package.
   - Its role is baseline/comparison, not final proof that text OCR is solved.

7. **Combined OCR strategy**
   - Implemented first probe with Surya.
   - Keep custom layout split as a fallback and learning path, using `math-ocr`/`text-ocr` as reusable components.
   - Keep Pix2Text as an all-in-one comparison backend, but lower priority than Surya.

---

## Recommended Next Checkpoint

Verify the feedback archive and correction workflow in the live system, then verify `text-ocr` before changing combined OCR engines.

Reason:

- It immediately makes every bad pix2tex result useful.
- It avoids losing real examples.
- It gives objective data for choosing Pix2Text, Tesseract, a remote service, or fine-tuning.

Implemented in `~/nixos-config` but not necessarily installed until `nrt` or `nrs`:

1. `math-ocr` creates an attempt bundle under `~/.local/share/ocr-captures/attempts`.
2. `~/.local/share/ocr-captures/latest` points to the newest attempt.
3. `~/.local/share/ocr-captures/latest-math` points to the newest math attempt.
4. `~/.local/share/ocr-captures/review.md` gets a queue entry with links to the screenshot and per-attempt review file.
5. `ocr-correct-last --from-clipboard` replaces the `## Correction` block in the latest attempt's `review.md`.
6. Raw output, normalized output, review file, input image, README, backend log, and `metadata.json` are saved per attempt.
7. Mock validation passed and `nix build ./tools#math-ocr --no-link --print-out-paths --option warn-dirty false` passed.

Live verification next:

1. Run `nrt`.
2. Trigger `math-ocr`.
3. Confirm `~/.local/share/ocr-captures/latest` contains the attempt.
4. Copy a corrected formula.
5. Run `ocr-correct-last --from-clipboard`.
6. Confirm `review.md` exists in the latest attempt and can be edited directly for current or older attempts.

Do not start training yet.

Checkpoint 4 implementation notes:

1. `text-ocr` is implemented in `tools/scripts/text-ocr.sh`.
2. It uses the same archive root, queue, `latest` symlink, and per-attempt `review.md` workflow as `math-ocr`.
3. It is exposed through `tools/pkgs/math-ocr.nix` alongside `math-ocr`, `ocr-correct-last`, and `bootstrap-pix2tex`.
4. It is a local-only baseline. `OCR_BACKEND=sauron` should fail clearly until a remote API exists.
5. The next live test should capture clear printed text first, not mixed text+math.

Checkpoint 5 keybind plan:

- `Super+M`: `math-ocr`.
- `Super+T`: `text-ocr`.
- `Super+N`: local `ocr-combined`.
- `Super+B`: remote `ocr-combined-sauron`.
- `Ctrl+Shift+N`: Neovide, moved away from `Super+N`.
- `Ctrl+Shift+T`: old Hyprland `togglesplit` binding.
- `ocr-combined` is now a Surya-backed probe command.

Checkpoint 5 implementation notes:

1. `ocr-combined` is implemented in `tools/scripts/ocr-combined.sh`.
2. `bootstrap-surya-ocr` is implemented in `tools/scripts/bootstrap-surya-ocr.sh`.
3. Surya runtime lives outside `~/nixos-config` at `~/.local/share/ocr-runtimes/surya`.
4. The wrapper uses the same archive root, queue, `latest` symlink, `latest-combined` symlink, and per-attempt `review.md` workflow as the other OCR commands.
5. Mock validation passed with a fake `surya_ocr` writing `surya/results.json`.
6. Live validation is still pending: run `nrt`, run `bootstrap-surya-ocr`, then trigger `Super+N` on a simple text+math region.

Checkpoint 8 implementation notes:

1. Surya 2 warm mode depends on `surya-ocr==0.20.0`, which exposes `--keep_server`.
2. Live testing showed Surya 2 downloads `surya-2.gguf` and asks `llama-server` to load a `qwen35` architecture model.
3. The current Nix `llama-server` failed with `unknown model architecture: 'qwen35'`, so warm mode cannot work with the current host package.
4. `ocr-combined-stop` remains useful for clearing `~/.cache/datalab/surya/llamacpp_server.lock` and stale sentinel files after failed Surya 2 startup attempts.
5. `bootstrap-surya-ocr` is restored to `surya-ocr==0.16.0` to keep the local `ocr-combined` path working.
6. Next options are either package a newer `llama.cpp` just for Surya 2, or move warm combined OCR to `sauron`.

Checkpoint 9 implementation notes:

1. `OCR_BACKEND=sauron ocr-combined` works through the Sauron OCR API and was validated with a saved screenshot.
2. `ocr-combined-sauron` is exposed by the Nix package as the explicit remote command.
3. Active comparison keybinds are `Super+N` for local `ocr-combined` and `Super+B` for remote `ocr-combined-sauron`.
4. The Sauron API is now an in-memory hot predictor service using Surya 0.16, not Surya 2.
5. `/warmup` loads the predictors, and the laptop wrapper calls `/warmup` before remote OCR by default.
6. Sauron now uses the Quadro M5000 through `torch==2.7.1+cu126`; `torch 2.12.0+cu130` is incompatible with this GPU because it lacks `sm_52` kernels.
