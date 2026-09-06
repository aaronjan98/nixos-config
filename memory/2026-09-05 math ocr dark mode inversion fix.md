# Math OCR Dark-Mode Background Inversion Fix

Date: 2026-09-05

## Problem & Root Cause

The user reported that capturing an equation like `\left( e^{t^2/10} y \right)' = \frac{8}{5} e^{t^2/10}` using `Super+N` copied garbled output to the clipboard:
```
40
2
t
$e^{\circ}$
```
And noted that it inconsistently gave correct output sometimes, and nonsense or nothing other times.

### Findings

1. **Dark background image capture**:
   - Inspected the latest saved attempt screenshot in `~/.local/share/ocr-captures/attempts/2026-09-05T11-38-48.297054568-0700_combined/input.png`.
   - Measured mean brightness: **9.7 / 255** (~3.8% brightness) — white text on dark background from a dark theme / IDE / dark PDF.
   - Machine learning OCR models (Surya, pix2tex) are trained on standard black text on white paper.
   - When given a dark mode capture, Surya's bounding box detector and recognition model fail or hallucinate random character fragments (`40 \n 2 \n t \n $e^{\circ}$`) or return 0 text lines.
   - **Why it was inconsistent**: When capturing equations on light backgrounds (white web pages, white PDFs, light themes), the OCR succeeded. When capturing on dark backgrounds, it failed.

2. **Verification**:
   - Inverted the exact failed capture screenshot (`input.png`) to produce a light background (`/tmp/inverted_test.png`).
   - Passed it to `surya-ocr-server`.
   - Result was 100% pristine:
     `$$\left(e^{t^{2}/10}y\right)^{\prime}=\frac{8}{5}e^{t^{2}/10}$$`

## Changes Made

1. **`surya-ocr-server.py`**:
   - Added automatic dark background detection using PIL + NumPy: when mean brightness of the capture is `< 115` (out of 255), it applies `ImageOps.invert(image)` before running detection and recognition.

2. **`ocr-combined.sh`**:
   - Added image mean brightness check after `grim` capture using `magick`: if mean `< 0.45`, negates colors (`magick "$img" -negate "$img"`) before passing to local cold, warm, or remote backends.

3. **`math-ocr.sh`**:
   - Added image mean brightness check after `grim` capture using `magick`: if mean `< 0.45`, negates colors (`magick "$img" -negate "$img"`) before running `pix2tex`.

4. **`tools/pkgs/math-ocr.nix`**:
   - Added `pkgs.imagemagick` to `math-ocr` runtimeInputs and `combinedRuntimeInputs`.
   - Verified Nix build with `nix build ./tools#math-ocr --no-link --print-out-paths`.

5. **Documentation**:
   - Updated `project-memory/text-math-ocr-pipeline-spec.md` with dark background inversion details.

## Next Steps for User

To apply the updated tools and restart the warm `surya-ocr-server`:
1. Run `nrt` to verify configuration, then `nrs` to apply changes.
2. Restart the user service if using warm mode: `systemctl --user restart surya-ocr-server`.
