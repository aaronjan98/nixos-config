# Script Inventory

This document lists the operational scripts in `~/nixos-config/scripts` and explains when they should be used.

## `bootstrap-workspace.sh`
Purpose:
- recreate `~/Repositories`
- restore top-level and area-level routing files from the tracked workspace snapshot
- clone repos into their expected locations

Typical use:
- initial setup on a new machine
- rebuilding workspace structure after a clean reinstall

## `export-workspace-state.sh`
Purpose:
- scan the live `~/Repositories` tree
- export top-level and area-level routing files to the tracked workspace snapshot
- update the root repo manifest

Typical use:
- regular maintenance
- automatically via systemd timer

## `install-user-systemd-units.sh`
Purpose:
- install tracked user systemd units from `~/nixos-config/systemd/user/` into `~/.config/systemd/user/`
- reload user systemd
- enable `export-workspace-state.timer`

Typical use:
- after cloning `nixos-config` on a new machine
- whenever tracked user units have changed

## `restore-secrets.sh`
Purpose:
- restore SSH files from `pass`
- restore the SOPS age key from `pass`
- prepare the machine for private repo access and secret-backed Nix usage

Notes:
- this is the bootstrap bridge between `pass` and `sops-nix`
- once the age key is restored and a rebuild succeeds, repo-tracked SOPS secrets can be materialized under `/run/...`

Typical use:
- early in new-machine setup, after GPG and `pass` are functional

## `bootstrap-root.sh`
Purpose:
- full root-phase bootstrap for a new machine
- configures pinentry, receives SSH + GPG keys from ThinkPad via netcat,
  imports GPG, clones pass, runs `restore-secrets.sh`, handles missing age
  key (generates + stores + pauses for ThinkPad action), syncs distfiles,
  runs `nixos-rebuild switch`

Typical use:
- first thing to run on a new machine after cloning nixos-config as root

Usage: `bash bootstrap-root.sh <flake-hostname>`

Requires: run inside `nix-shell -p gnupg pass git netcat-gnu pinentry-curses age`

## `send-secrets-to-new-machine.sh`
Purpose:
- bundle SSH key + GPG keys and send to a new machine via netcat
- run on ThinkPad when `bootstrap-root.sh` pauses and prompts for it

Typical use:
- called once per new machine bootstrap

Usage: `send-secrets-to-new-machine.sh <new-machine-ip> [port]`

## `post-rebuild-setup.sh`
Purpose:
- aj-phase setup after the first successful `nixos-rebuild switch`
- sets GPG trust, adds git remotes to nixos-config and dotfiles,
  checks out dotfiles, generates ed25519 SSH key, authenticates Tailscale,
  runs `bootstrap-new-machine.sh`

Typical use:
- run as aj immediately after logging in post-first-rebuild

Usage: `bash ~/nixos-config/scripts/post-rebuild-setup.sh`

## `bootstrap-new-machine.sh`
Purpose:
- orchestrate the workspace-level setup sequence (called by `post-rebuild-setup.sh`)
- install user systemd units, seed local git server, sync distfiles,
  bootstrap workspace, sync workspace repos

Typical use:
- called automatically by `post-rebuild-setup.sh`; can also be run standalone

## `ai-router.sh`
Purpose:
- choose how Claude Code is launched
- support:
  - cloud mode
  - local mode
  - auto mode

Typical use:
- normal interactive use should prefer cloud mode
- local mode is currently experimental and kept mainly for future use or limited testing

Behavior:
- `--cloud` launches normal Claude
- `--local` launches Claude with local backend environment overrides
- `--auto` uses routing logic, but current policy should strongly prefer cloud unless local is explicitly requested

Notes:
- local backend support is wired up but is not currently part of the normal recommended workflow
- bulk filesystem changes should still follow the script-first rule
## `new-homelab-repo.sh`
Purpose:
- create a new bare repo on sweetpea as the `git` user
- create a matching private (or public) Forgejo repo at `git.aaronjanovitch.com`
- install the `/srv/git/hooks/forgejo-sync` post-receive hook so every push auto-mirrors to Forgejo

Typical use:
- starting a new project that should live on the homelab git server and appear in Forgejo

Usage: `new-homelab-repo <name>` (private by default) or `new-homelab-repo <name> --public`

Requires: `$FORGEJO_TOKEN` in the environment (exported from `~/.bashrc` via `/run/secrets/forgejo_token`)

## `install-forgejo-hooks.sh`
Purpose:
- install the forgejo-sync post-receive hook on all sweetpea bare repos that already have a matching Forgejo repo
- safe to re-run; skips repos that are already wired up or have no Forgejo counterpart

Typical use:
- after adding Forgejo repos that correspond to existing bare repos
- one-time backfill when bringing a new machine up to date

Requires: `$FORGEJO_TOKEN` in the environment

## `rsync-git-server-mirror.sh`
Purpose:
- mirror the homelab git server into the local git server

Typical use:
- when refreshing the local git mirror from home

## `seed-local-git-server.sh`
Purpose:
- set up the local git server structure on the machine

Typical use:
- new machine setup
- preparing a local git mirror workflow

## `sync-distfiles.sh`
Purpose:
- copy cached distfiles/binaries from the NAS-backed distfiles location into the local distfiles location

Typical use:
- before builds or installs that benefit from cached distfiles
- during new-machine bootstrap

When to use this pattern vs. a normal fetchzip/fetchurl derivation:
- Use `requireFile` + NAS when Nix **cannot fetch the source automatically** — e.g. the download
  requires a login, license acceptance, or has no stable public URL (Wolfram is the canonical example).
- Use `fetchzip`/`fetchurl` directly when the source is publicly available at a stable URL
  (npm packages, GitHub releases, etc.). The NAS is not needed for these.

Workflow for a `requireFile`-backed package:
1. Manually download the binary/installer and place it on the NAS under
   `/mnt/storage/distfiles/<package-name>/`
2. On the target machine: `sync-distfiles <package-name>`
3. Add the file to the Nix store: `nix store add-file /var/lib/distfiles/<package-name>/<file>`
4. The derivation's `requireFile` will now resolve and the build can proceed.

## `sync-workspace-repos.sh`
Purpose:
- keep workspace repos aligned with the root manifest
- clone missing repos
- fetch and safely update existing repos

Typical use:
- multi-machine upkeep
- after bootstrap

## `math-ocr.sh`
Purpose:
- operational helper for the math OCR workflow
- captures a selected region, runs pix2tex, copies normalized LaTeX, and records an OCR attempt for later review

Archive:
- root: `~/.local/share/ocr-captures`
- queue/history: `~/.local/share/ocr-captures/review.md`
- latest attempt of any type: `~/.local/share/ocr-captures/latest`
- latest math attempt: `~/.local/share/ocr-captures/latest-math`
- latest text attempt: `~/.local/share/ocr-captures/latest-text`
- per-attempt review file: `~/.local/share/ocr-captures/attempts/<attempt-id>/review.md`

Correction workflow:
- edit the `## Correction` block in an attempt's `review.md`
- use `~/.local/share/ocr-captures/review.md` as the triage queue; each entry links to its screenshot and per-attempt review file
- remove entries from `~/.local/share/ocr-captures/review.md` if they are not useful for future OCR improvement; this does not delete the attempt bundle
- optional helper: `ocr-correct-last --from-clipboard` replaces the latest attempt's `## Correction` block with the current clipboard text
- optional helper: `ocr-correct-last <attempt-id-or-dir>` opens an older attempt's `review.md`

## `text-ocr.sh`
Purpose:
- operational helper for plain text OCR
- captures a selected region, runs Tesseract, copies normalized plain text, and records an OCR attempt for later review
- provides a local baseline for comparison against heavier combined OCR tools such as Surya

Defaults:
- backend: `OCR_BACKEND=local`
- language: `TEXT_OCR_LANG=eng`
- Tesseract page segmentation mode: `TEXT_OCR_PSM=6`

Archive:
- uses the same `~/.local/share/ocr-captures` archive and `review.md` correction workflow as `math-ocr`
- per-attempt folders are named `YYYY-MM-DDTHH-MM-SS..._text`
- the latest attempt is still available through `~/.local/share/ocr-captures/latest`
- the latest text attempt is available through `~/.local/share/ocr-captures/latest-text`

Notes:
- `OCR_BACKEND=sauron` and `OCR_BACKEND=auto` are intentionally not implemented yet for `text-ocr`
- clear printed text should work first; mixed text+math remains the separate `ocr-combined` checkpoint

## `ocr-combined.sh`
Purpose:
- operational helper for the combined text+math OCR workflow
- captures a selected region, runs Surya, copies normalized HTML/Markdown-ish output, and records an OCR attempt for later review

Runtime:
- uses a mutable Surya Python venv at `~/.local/share/ocr-runtimes/surya/.venv`
- bootstrap with `bootstrap-surya-ocr`
- local CPU mode depends on Surya's `llama.cpp` backend; the Nix wrapper provides `llama-server`
- `SURYA_KEEP_SERVER=1 ocr-combined` leaves Surya's inference server running for faster repeated use

Archive:
- uses the same `~/.local/share/ocr-captures` archive and `review.md` correction workflow as `math-ocr` and `text-ocr`
- per-attempt folders are named `YYYY-MM-DDTHH-MM-SS..._combined`
- the latest combined attempt is available through `~/.local/share/ocr-captures/latest-combined`
- Surya's original JSON is saved as `surya/results.json` and copied to `raw-output.txt`

Notes:
- output is currently Surya block `html` / `text_lines` joined in reading order
- the wrapper normalizes Surya `<math>...</math>` tags to Markdown inline math `$...$`
- `OCR_BACKEND=sauron` and `OCR_BACKEND=auto` are intentionally not implemented yet for `ocr-combined`

## `bootstrap-surya-ocr.sh`
Purpose:
- create/repair the mutable Surya venv used by `ocr-combined`
- install the pinned pip package `surya-ocr==0.16.0`
- verify `surya_ocr` is available and can import Surya

Runtime location:
- default: `~/.local/share/ocr-runtimes/surya`
- override with `SURYA_RUNTIME_DIR`

Logs:
- `~/.cache/ocr-combined/bootstrap.log`

## `record-session` (system command)
Purpose:
- record system mic to a WAV file until Ctrl+C, then transcribe with whisper.cpp (small.en model) and write a markdown transcript

Usage:
```bash
record-session [label]      # e.g. record-session consulate-call
```

Output (under `~/Documents/transcripts/`):
- `YYYY-MM-DD-HHMMSS-<label>.wav` — raw recording (16 kHz mono)
- `YYYY-MM-DD-HHMMSS-<label>.md` — transcript with header and whisper output

Model:
- `ggml-small.bin` (~466 MB) — multilingual whisper.cpp small model; downloaded on first run to `~/.cache/whisper-cpp/`
- Auto-detects language per ~30 s segment and transcribes each in its original language (no translation)
- Runs CPU-only on this hardware at roughly real-time × 0.3–0.5

Translation, comparison, and other re-processing are intentionally out of scope — the WAV is preserved so any downstream tool (a different whisper model, a translation pass, an LLM) can work from it.

Notes:
- Captures the **default PulseAudio source** via PipeWire's pulse compat layer (ffmpeg `-f pulse -i default`). Switch the default input in `pavucontrol` or `wpctl` if needed before invoking.
- For phone-on-speaker call recording, place the phone near the laptop mic. Quality is muddy but typically 85–92% accurate with `small.en`.
- WAV files are kept (not deleted) so the audio can be re-transcribed later with a different model if quality matters.
- Source script: `tools/scripts/record-session.sh`; package wrapper: `tools/pkgs/record-session.nix`; wired into `hosts/common/default.nix` via `nix-tools.packages.<system>.record-session`.

## `doc-scan.py`
Purpose:
- turn a phone photo of a document into a flatbed-style scan
- interactive 4-corner perspective correction + CLAHE contrast boost

Usage:
```bash
nix-shell -p 'python3.withPackages(p: [p.opencv4 p.numpy p.matplotlib p.tkinter])' \
    --run "python3 ~/nixos-config/scripts/doc-scan.py <input.jpg> <output.jpg>"
```
A matplotlib (TkAgg) window opens; click the 4 page corners in order TL → TR → BR → BL, then the window auto-closes and the corrected scan is written.

To compress under a size cap (e.g. for visa portals):
```bash
nix-shell -p imagemagick \
    --run "magick <scan.jpg> -resize 2400x -define jpeg:extent=1900KB <scan-small.jpg>"
```

Notes:
- nixpkgs `opencv4` lacks GTK/Qt GUI bindings, and matplotlib's `Qt5Agg` backend has no Wayland plugin; that's why this uses matplotlib with `TkAgg` and `p.tkinter` in the nix-shell.
- Not yet packaged. If usage grows, graduate it to a `doc-scan` system command following the `math-ocr` precedent (`modules/`, `pkgs/`, `tools/`, `hosts/common/default.nix`).

## `tmux-battery.sh`
Purpose:
- tmux helper/status script

## `update-all-pinned-packages.sh`
Purpose:
- run the tracked pinned-package update scripts in sequence
- refresh all configured local package pins in one command
- optionally verify the combined result with one Nix build

Notes:
- currently orchestrates `update-pi.sh` and `update-openai-codex.sh`
- calls the individual update scripts with `--no-build`, then runs one final verification build by default
- resolves the flake host from the current machine hostname (same idea as `nrs`), so the verification build follows whichever laptop you are on

Typical use:
- when multiple locally pinned tools should be refreshed together
- when you want one command for the current pinned-package update set instead of running each updater manually

## `update-pi.sh`
Purpose:
- update the pinned `pkgs/pi` package from the upstream npm release
- regenerate `pkgs/pi/package-lock.json`
- refresh the source hash and npm dependency hash in `pkgs/pi/default.nix`
- optionally verify the result with a Nix build

Notes:
- Pi is packaged as a local `buildNpmPackage` derivation, so this script handles both the upstream source tarball pin and the npm dependency pin
- verification builds target the current machine's flake host using the same hostname mapping pattern as `nrs`

Typical use:
- when Pi reports a new upstream release and the machine should stay on the reproducible Nix-managed install path
- when refreshing the pinned local derivation instead of using `npm install -g`

## `update-openai-codex.sh`
Purpose:
- update the pinned `pkgs/openai-codex` package from the upstream npm release
- refresh the version and source hash in `pkgs/openai-codex/default.nix`
- optionally verify the result with a Nix build

Notes:
- Codex is packaged from a prebuilt upstream tarball, so this script is simpler than the Pi updater and does not manage an npm lockfile
- verification builds target the current machine's flake host using the same hostname mapping pattern as `nrs`

Typical use:
- when Codex CLI reports a new upstream release and the machine should stay on the reproducible Nix-managed install path
- when refreshing the pinned local derivation instead of replacing it with a global installer

---

## Planned / not yet implemented

### `backup-secrets.sh`
Intended as the inverse of `restore-secrets.sh`.
Purpose:
- read SSH material from `~/.ssh/`
- store each file into `pass` under the hostname-derived prefix `laptop/<hostname>/ssh/<filename>`
- prepare or refresh the password-store entries that `restore-secrets.sh` depends on

See `CONTEXT.md` for the open design questions that must be resolved before this is written.
