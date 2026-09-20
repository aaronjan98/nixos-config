# Cliphist Fix + pix2tex Temperature Tweak

Date: 2026-09-19

## Cliphist clipboard history picker

### Problem
`cliphist-text`/`cliphist-image` systemd user services existed (`modules/cliphist.nix`) but were `failed` and had been dead for days. No keybind existed to browse clipboard history at all.

### Root cause
Services were `wantedBy = [ "default.target" ]`, which fires before Hyprland's Wayland session exists, so `wl-paste --watch` crash-looped on "Failed to connect to a Wayland server" and hit systemd's restart-limit. `graphical-session.target` is never activated on this Hyprland setup (confirmed via `modules/xremap.nix`'s existing comments/pattern), so binding to it would have been a silent no-op.

### Fix
- `modules/cliphist.nix`: dropped `wantedBy`; services now start via explicit `exec-once = systemctl --user start cliphist-text cliphist-image` in `~/.config/hypr/conf.d/10-programs.conf`, placed right after the `WAYLAND_DISPLAY` import-environment lines — same pattern as the existing `xremap` service.
- Added `bind = $mainMod CTRL, V, exec, sh -c 'cliphist list | ~/.config/hypr/scripts/fz -d | cliphist decode | wl-copy'` in `20-binds.conf` (`$mainMod,V`/`SHIFT,V` were already taken by togglefloating/pin). Initially used raw `fuzzel -d`, which rendered oversized (fuzzel.ini's base config is tuned for the Framework 13's HiDPI panel) — fixed by routing through the existing `~/.config/hypr/scripts/fz` host-scaled wrapper, matching the emoji picker and main menu.
- Committed: `nixos-config@5456411` (systemd fix), dotfiles repo (`dot`) commit `2a219f8` (hypr conf changes — `~/.config/hypr` is tracked via the `dot` bare-repo alias, not this repo).

## pix2tex clipboard corruption → temperature experiment

### Problem
User reported `latexocr`/`math-ocr` (`Super+M`) output pasted with invisible corruption: `\frac` → `rac`, `\alpha` → `lpha`, `\beta` → ` eta`.

### Root cause (confirmed via `cliphist decode <id> | cat -A`)
Real control bytes in the clipboard content — `^L` (form feed, 0x0C) replacing `\f` of `\frac`, `^G` (bell, 0x07) replacing `\a` of `\alpha`, `^H` (backspace, 0x08) replacing `\b` of `\beta`. Not a cliphist/wl-copy issue — verified the raw pix2tex stdout already contained these bytes.

Smoking gun: `\alpha`/`\beta` each appeared twice in the same OCR output — corrupted once, correct the other time. This points to non-deterministic sampling, not a deterministic bug: `pix2tex/models/transformer.py` samples each token from `softmax(logits / temperature)` (multinomial, not argmax), and `math-ocr.sh` never overrode the CLI's default `temperature=0.333`. Occasionally the model samples a rare/noisy vocab token that happens to decode to a raw control byte instead of the intended letter.

### Fix applied (experiment)
`tools/scripts/math-ocr.sh`: `cmd=( "$OCR" --no-cuda "$img" )` → `cmd=( "$OCR" --no-cuda --temperature 0.05 "$img" )`. Lower temperature sharpens the sampling distribution toward the model's top choice, making this specific corruption much less likely — traded off against losing the ability for a retry to "reroll" into a better answer on genuinely ambiguous glyphs (near-deterministic output means retries mostly reproduce the same result).

### Important scoping note
This only affects `math-ocr`/`Super+M`, which calls `pix2tex` directly. It does **not** apply to the user's actual daily-driver bindings:
- `Super+N` (`ocr-combined-warm`) and `Super+B` (`ocr-combined-sauron`) both use **Surya**, not pix2tex at all (confirmed: zero `pix2tex` references in `ocr-combined.sh`, `engine: surya` throughout). Surya's decoding has no equivalent temperature knob (checked `surya-ocr-server.py` — no temperature/sampling logic).
- `Super+X` (`ocr-custom-split-sauron`) does local Tesseract layout splitting + heuristic math-span detection, sending only cropped math regions to Sauron's Surya-based API — also not pix2tex.
- User doesn't actually use `Super+M`/`Super+T` (math-ocr/text-ocr standalone) day-to-day, so this fix is currently dormant. Kept as-is per the project's own spec doc, which explicitly calls these out as baseline/comparison tools worth keeping regardless of daily use.
- Committed: `nixos-config` (see git log after this note for the commit hash).

## Reference
Full OCR pipeline design/history: `project-memory/text-math-ocr-pipeline-spec.md` (677 lines — architecture, all backend variants, local-vs-remote/Sauron rationale, correction workflow, speed strategy, decision log).
