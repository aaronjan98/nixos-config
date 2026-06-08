# Text + Math OCR Pipeline Spec

**Status:** Checkpoint 3 implemented; system rebuild/user verification pending
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

- Pix2Text is the likely all-in-one candidate for layout + text + math.
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

- Tesseract for mature local OCR.
- OCRmyPDF/Tesseract for document/page workflows.
- PaddleOCR/EasyOCR only if accuracy justifies the Python runtime complexity.

Candidate remote backend:

- A small OCR API on `sauron`, especially if a heavier Python model gives better results than Tesseract.

Output:

- Plain text copied to clipboard.
- Raw attempt saved to the OCR archive.

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
2. Pix2Text-style all-in-one pipeline.

Recommendation:

- Start with the custom layout split + separate engines mental model because it matches AJ's intended workflow.
- Keep Pix2Text as a candidate backend/prototype, especially for benchmarking whether an all-in-one model handles layout better than a hand-rolled split.
- Keep the command boundary separate so either strategy can be swapped behind `ocr-combined`.

Output:

- Markdown copied to clipboard.
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

---

## Feedback Archive

The feedback archive is the bridge between daily use and future model improvement.

Every OCR command should save an attempt bundle before copying output.

Recommended path:

```text
~/.local/share/ocr-captures/
  README.md
  review.md                     # triage/history queue; safe to edit/remove entries
  latest -> attempts/<attempt-id>
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
| 4. Add text OCR command | Pending | `text-ocr` captures region and copies plain text |
| 5. Add combined OCR prototype | Pending | `ocr-combined` returns Markdown for simple text+math region |
| 6. Evaluate backend quality | Pending | Compare local pix2tex/Pix2Text/text OCR on saved examples |
| 7. Decide remote `sauron` service | Pending | API contract and auth model chosen |
| 8. Optional warm daemon | Pending | Local or remote daemon avoids model reload per invocation |
| 9. Dataset export | Pending | Corrected examples can export to training/eval format |
| 10. Training/fine-tuning decision | Pending | Enough corrected examples exist to justify training |

---

## Phase 1 Decisions

Resolved answers:

- Archive location: `~/.local/share/ocr-captures`.
- `sauron`: optional backend that can be turned on/off to compare local and remote behavior.
- Combined OCR: prefer a layout split pipeline first, where text regions and math regions go to separate engines and are then merged into Markdown; keep Pix2Text as a candidate all-in-one benchmark.

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
   - Recommended first local backend: Tesseract, because it is mature and easy to package.
   - Recommended research/prototype backend: Pix2Text, because it targets text + layout + math.

7. **Combined OCR strategy**
   - Resolved direction: custom layout split + separate engines first.
   - Keep Pix2Text as an all-in-one comparison backend.

---

## Recommended Next Checkpoint

Verify the feedback archive and correction workflow in the live system before changing OCR engines.

Reason:

- It immediately makes every bad pix2tex result useful.
- It avoids losing real examples.
- It gives objective data for choosing Pix2Text, Tesseract, a remote service, or fine-tuning.

Implemented in `~/nixos-config` but not necessarily installed until `nrt` or `nrs`:

1. `math-ocr` creates an attempt bundle under `~/.local/share/ocr-captures/attempts`.
2. `~/.local/share/ocr-captures/latest` points to the newest attempt.
3. `~/.local/share/ocr-captures/review.md` gets a queue entry with links to the screenshot and per-attempt review file.
4. `ocr-correct-last --from-clipboard` replaces the `## Correction` block in the latest attempt's `review.md`.
5. Raw output, normalized output, review file, input image, README, backend log, and `metadata.json` are saved per attempt.
6. Mock validation passed and `nix build ./tools#math-ocr --no-link --print-out-paths --option warn-dirty false` passed.

Live verification next:

1. Run `nrt`.
2. Trigger `math-ocr`.
3. Confirm `~/.local/share/ocr-captures/latest` contains the attempt.
4. Copy a corrected formula.
5. Run `ocr-correct-last --from-clipboard`.
6. Confirm `review.md` exists in the latest attempt and can be edited directly for current or older attempts.

Do not start training yet.
