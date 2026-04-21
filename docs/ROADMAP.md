# ROADMAP.md

This file tracks deferred fixes, design ideas, and future feature work for this NixOS configuration and its operational tooling.

---

## Ongoing issues

### Keyboard backlight not restored after lid close/open
Status: confirmed

Problem:
- closing the laptop lid and reopening it leaves the keyboard backlight off

Root cause:
- `before_sleep_cmd` runs `screen-blackout-on`, which reads and saves the current kbd brightness then sets it to 0
- if the 5-minute idle blackout already fired before the lid was closed, kbd brightness is already 0 at that point — so `screen-blackout-on` saves 0 as the restore value and `screen-blackout-off` on resume restores to 0

Relevant file: `modules/hypr-idle-lock.nix`

---

## Future features

### math-ocr / pix2tex: reimplement using venv runtime model

**Background**: multiple attempts were made to package pix2tex (LaTeX-OCR) as a pure NixOS system package. All failed for the same fundamental reasons:
1. pix2tex expects to write to its checkpoints directory at runtime — Nix store paths are immutable
2. The CLI, model config, and checkpoint weights must match exactly — even minor version drift in nixpkgs causes `state_dict` key mismatches
3. PyTorch + fast-moving ML apps assume a mutable Python environment; Nix Python packaging is not a good fit here

The working approach (proven on Fedora) and the settled design for NixOS is documented in detail in:
`~/Repositories/self-hosted/zettelkasten/Inside/Projects/prompt next AI to setup pix2tex with venv runtime in nix.md`

**Why pure Nix is confirmed wrong here**: the only community NixOS packaging attempt (SimonYde/pix2tex.nix) was archived and abandoned by May 2025 with the maintainer explicitly dropping it. pix2tex upstream (lukas-blecher/LaTeX-OCR) has accumulated deprecated dependencies (albumentations, torchtext abandoned) and a security vulnerability (insecure pickle deserialization). Do not attempt to package it system-wide again.

**Correct architecture (do not retry pure Nix packaging):**

Layer 1 — Nix (immutable, declarative):
- `grim`, `slurp`, `wl-clipboard`, `libnotify` as system packages
- `math-ocr` wrapper script installed as a system command (rewrite `tools/scripts/math-ocr.sh`)
- `bootstrap-pix2tex` script installed as a system command — clones repo and sets up venv on first run
- systemd user service (`bootstrap-pix2tex.service`, type oneshot) that runs `bootstrap-pix2tex` at login — ensures the repo and venv exist on a fresh machine without manual intervention

Layer 2 — User-space runtime (mutable, git-pinned):
- pix2tex repo cloned from local git server: `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/pix2tex.git`
- Python venv inside or next to the repo
- `torch` (CPU wheels) + `pix2tex` installed inside venv by the bootstrap script
- Checkpoints and caches live in `$HOME/.cache/pix2tex/` — mutable, never in Nix store

**Files to delete (dead weight from failed attempts):**
- `pkgs/pix2tex/` — custom Nix derivation, commented out of flake.nix; delete entire directory
- `pkgs/math-ocr/` — wraps the above; also dead; delete entire directory
- `modules/math-ocr.nix` — old module approach, commented out in configuration.nix; delete
- `scripts/math-ocr.sh` — superseded by `tools/scripts/math-ocr.sh`; delete
- `scripts/pix2tex-config.yaml` — model training config that has no place in this repo; delete
- Clean up the commented-out lines in `flake.nix` (lines 31, 79) and `configuration.nix` (lines 17, 370)

**Files to keep and rewrite:**
- `tools/scripts/math-ocr.sh` — rewrite to: check venv exists → activate → run pix2tex on screenshot → copy LaTeX to clipboard; no weight-preseeding, no `-m` flag
- `tools/pkgs/math-ocr.nix` — keep as the system-installed wrapper; remove the commented `#pkgs.pix2tex`; add a second `writeShellScriptBin` for `bootstrap-pix2tex`; add the systemd user service definition (`systemd.user.services.bootstrap-pix2tex`)

**NixOS-specific gotcha to handle in bootstrap script:**
Python venv interpreter paths embed the Nix store hash (e.g. `/nix/store/xxxx-python3.11/bin/python3`). If NixOS rebuilds Python, the venv's interpreter symlink breaks silently. The bootstrap script should detect a broken venv interpreter (test `-x "$VENV/bin/python"`) and recreate the venv if needed before installing packages.

Relevant files:
- `tools/scripts/math-ocr.sh` — rewrite
- `tools/pkgs/math-ocr.nix` — update
- `hosts/thinkpad-t14/configuration.nix` — clean up commented lines
- `flake.nix` — clean up commented lines

### Battery charge threshold (AlDente-style 80% cap)
Goal:
- Allow the user to cap battery charging at 80% at runtime, toggled from the Quickshell battery popup (see quickshell ROADMAP)
- On ThinkPad T14, the threshold is exposed at `/sys/class/power_supply/BAT0/charge_control_end_threshold` — writing `80` caps charging, writing `100` restores full charging

System-level requirements:
- The sysfs file requires root to write; the Quickshell UI runs as user — needs a privilege escalation mechanism:
  - **Preferred**: a polkit action + small setuid wrapper script (`battery-threshold`) that validates the input (only accepts 80 or 100) and writes to sysfs — callable from Quickshell via `Process`
  - **Alternative**: `services.tlp` in NixOS with `STOP_CHARGE_THRESH_BAT0=80` — but TLP manages this declaratively at boot, not dynamically at runtime from the UI
- Persist the chosen threshold across reboots: a systemd `oneshot` service that restores the last-written threshold value on boot (reading from a state file in `/etc` or `/var/lib`)

NixOS changes:
- Add a `modules/battery-health.nix` module that:
  - Installs the `battery-threshold` wrapper script via `pkgs.writeShellScriptBin` with appropriate setuid or polkit wiring
  - Optionally installs the boot-time restore systemd service
- Import the module in `hosts/thinkpad-t14/configuration.nix` (ThinkPad-specific; Framework would need its own threshold path)

Open questions:
- Whether to use polkit (cleaner, no setuid) or a simple setuid shell script (simpler to set up in NixOS)
- Whether TLP should be involved at all, or manage the threshold entirely via the custom module

### Kanata: TCP server, launcher layer, and multi-profile support
Goal:
- Enable the Kanata TCP server so Quickshell can receive layer-change events and send mode/profile switch commands (required by the left bar mode indicator island — see quickshell ROADMAP)
- Add a `launcher` layer (L mode) to the kanata config: single tap of Super enters launcher mode, where each letter key launches a configured app
- Add a `default` profile `.kbd` file alongside the existing `kanata-internal.kbd` (the "aj" profile)

Changes needed in `hosts/thinkpad-t14/kanata/kanata-internal.kbd`:
1. Add `tcp-port 7979` (or similar) to `defcfg` so the TCP server starts with kanata
2. Add a `(deflayer launcher ...)` that maps letter keys to app-launch commands via `cmd` actions
3. Decide on Super tap-to-enter: currently Super (lmet) is used as a chord modifier — a one-shot or tap-hold-press on lmet with a short tap timeout could enter launcher layer

New file `hosts/thinkpad-t14/kanata/kanata-default.kbd`:
- A simpler "default" profile without home-row mods or custom chords, for contexts where the full aj layout is unwanted

Open questions before implementing:
- Confirm TCP port doesn't conflict with other services
- Decide which keys in launcher mode launch which apps (user-defined mapping)
- Decide whether launcher mode exits automatically after one keypress or requires explicit exit (e.g. Esc or caps tap)
- Super tap conflict: lmet is currently used as a chord modifier in home-row mods (`dmet`, `kmet`) — a short tap timeout may cause misfires

Future: script-execution mode (a further named layer where letter keys execute arbitrary scripts — workspace bootstrap scripts being one category, but others are possible too); design is TBD but should be represented as another mode letter in the Quickshell island. The scripts themselves are documented as a standalone feature in `~/.config/ROADMAP.md`.

Relevant files:
- `hosts/thinkpad-t14/kanata/kanata-internal.kbd`
- `modules/kanata.nix`

### Live gesture-tracked workspace transitions
Goal:
- Workspace switching animations should track finger position in real time during a trackpad swipe, so the transition scrubs proportionally as the gesture progresses — not just snapping/animating after the finger lifts
- Direction must match the gesture: left/right swipes drive horizontal slot switching, up/down swipes drive vertical domain switching (matching the current 2D workspace convention)

Current state in Hyprland:
- `gestures { workspace_swipe = true }` enables swipe-to-switch but the animation is committed at gesture end — there is no mechanism to feed continuous libinput gesture delta (dx/dy per event) into the workspace animation position
- This is a known architectural limitation; Hyprland does not expose a real-time gesture progress API to plugins or the shell layer

Paths to investigate (in order of preference):
1. **Hyprland plugin**: intercept raw libinput gesture events via the plugin API, compute normalised progress (0–1), and drive workspace translation directly — most invasive but avoids compositor switch
2. **MangoWC**: user has noted this as a candidate — research required (uncertain if this compositor supports live gesture tracking; investigate before committing)
3. **niri**: a Wayland compositor explicitly built around scrollable, gesture-position-tracked workspaces; its navigation model matches exactly what is described here; primary downside is that the entire Quickshell shell configuration would need to be re-validated against niri's layer-shell behaviour

Trade-offs of switching compositor:
- All Hyprland-specific Quickshell bindings (`Quickshell.Hyprland`, `HyprlandIpc`, `Hyprland.focusedClient`, etc.) would need to be rewritten against the new compositor's IPC
- The 2D workspace domain/slot convention is currently encoded in Hyprland workspace numbering (domain 2 = workspaces 20–29, etc.) — a new compositor would need an equivalent model
- NixOS module: `wayland.windowManager.hyprland` → replacement module for chosen compositor

Decision required before implementing:
- Whether to attempt the Hyprland plugin path first or move straight to evaluating alternative compositors
- If switching: which compositor, and whether the Quickshell shell layer survives the move (most Wayland layer-shell behaviour is compositor-agnostic, but Hyprland-specific IPC calls are not)

### Floating scratchpad terminal
Goal:
- a keybinding that opens a correctly-sized, centered floating terminal for one-off commands — analogous to `Super+V` making a window float, but launching a dedicated terminal instance in that state from the start

Implementation:
- launch Ghostty with a fixed class name (e.g. `ghostty --class=ghostty-scratchpad`) bound to a key
- `windowrulev2` rules targeting that class: `float`, `size <width> <height>`, `center`
- size TBD by preference; ~60–70% of screen width × ~50% height is a reasonable starting point

Relevant file: wherever `windowrulev2` and keybinds live in the Hyprland config

### Hyprland window stacking (ctrl+tab to cycle)
Goal:
- stack multiple windows in the same slot and use `Ctrl+Tab` to bring the next one to the front, without switching workspaces

How this works in Hyprland:
- Hyprland `group` feature: `togglegroup` groups the focused window with others in the same tile; `changegroupactive f` cycles forward through group members
- keybindings needed: one to toggle group membership, one for `Ctrl+Tab` → `changegroupactive f`

Open question: whether grouping is the right primitive here or whether `cyclenext` / `focuscurrentorlast` is sufficient for floating windows

### Framework 13 AMD support
Goal:
- add a Framework 13 AMD as a second host by refactoring `hosts/thinkpad-t14/configuration.nix` into a shared base that other host configurations derive from

---

### NixOS specialisations / alternative system profiles
Goal:
- figure out whether named NixOS specialisations fit the daily workflow and are worth maintaining

Why this is interesting:
- `nixos-rebuild list-generations` already exposes the `Specialisation` field, but the current setup does not use it
- specialisations could support alternative profiles such as battery-saving, work, AI-heavy, gaming, or minimal modes

Open questions:
- which profiles are actually worth the maintenance cost
- how much should differ between the base system and a specialisation
- whether switching should happen mainly at boot, at runtime, or both
- how service and dotfiles behavior should integrate with profile changes

### `scripts/backup-secrets.sh`
Goal:
- implement the inverse of `restore-secrets.sh` so SSH material can be backed up into `pass`

Current shape:
- the script should read files from `~/.ssh/`
- it should write them into `pass` under `laptop/<hostname>/ssh/<filename>`

Open questions:
- scope: back up all of `~/.ssh/`, or only the fixed list used by `restore-secrets.sh`
- overwrite behavior: overwrite, skip, or prompt
- hostname: derive from `$(hostname)` or accept an argument
- auto-push: run `pass git push` automatically or leave it manual

References:
- `CONTEXT.md`
- `docs/SCRIPTS.md`

### Live runtime theme switcher
Goal:
- add a live theme switcher that works without a NixOS rebuild

Current decision:
- do **not** use Stylix for this workflow, because rebuild-based theme switching is the wrong fit
- preferred direction is `matugen` + generated per-theme configs + symlink switching + targeted reloads

Why it belongs here:
- this is a cross-cutting desktop feature that affects Quickshell, terminals, and other app themes

### Qylock / Quickshell lockscreen path
Goal:
- revisit the lockscreen implementation if the higher-fidelity QML animation path becomes worth the complexity

Current state:
- `hyprlock` is working now and remains the active solution
- the exact visual direction researched earlier would require moving to a `quickshell` / `qylock`-based lockscreen

Why it is deferred:
- it would be a meaningful architectural shift rather than a small tweak

---

## Candidate improvements

### Automatic Nix garbage collection
- current decision is to keep garbage collection manual for now
- if manual cleanup becomes annoying, later revisit enabling scheduled GC in the NixOS config

---

## How to use this file

- add deferred issues that are known but intentionally not fixed yet
- add feature ideas that should survive beyond a single chat session
- move stable architectural decisions into `MEMORY.md`
- keep day-specific implementation details in `memory/YYYY-MM-DD.md`
- keep script-specific design constraints in `CONTEXT.md` or the most relevant focused doc when appropriate
