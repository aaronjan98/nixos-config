# ROADMAP.md

This file tracks deferred fixes, design ideas, and future feature work for this NixOS configuration and its operational tooling.

---

## Ongoing issues

### Fn+F4 mic mute key does not toggle microphone (ThinkPad)
Status: confirmed, undiagnosed

Problem:
- F4 LED is lit at boot (indicating mic is muted by default)
- Pressing Fn+F4 should toggle mic mute but does not work
- The `XF86AudioMicMute` keysym is already bound in `~/.config/hypr/conf.d/20-binds.conf` → `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`

Possible causes (not yet investigated):
- `thinkpad_acpi` kernel module is intercepting Fn+F4 at the hardware level before it reaches the OS as `XF86AudioMicMute` — may need `options thinkpad_acpi hotkey_mask=...` or similar to pass the event through
- The key is generating a different keycode than `XF86AudioMicMute` on this model — worth checking with `wev` or `xev` to see what event is actually emitted
- The default muted state at boot is set by something outside wpctl and may not correspond to the `@DEFAULT_AUDIO_SOURCE@` sink wpctl targets

Relevant files:
- `~/.config/hypr/conf.d/20-binds.conf` — existing binding
- `hosts/thinkpad-t14/configuration.nix` — may need `boot.extraModprobeConfig` for thinkpad_acpi options

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

### WIP-branch helper for moving uncommitted work between hosts

Syncthing handles file-sync (Documents/Pictures). Git repos remain pull/push-driven on purpose — file-syncing `.git/` is unsafe (mutable binary database, non-atomic across files, sync-conflict files inside `.git/` corrupt the repo).

That leaves a real workflow gap: uncommitted WIP on host A is not visible on host B without committing. Proposed helpers:

- `wip-leave` — for each tracked repo with uncommitted changes, stage everything, commit as `wip: <host> <iso-timestamp>`, push to a `wip/<host>` branch.
- `wip-arrive` — for each repo with a matching `wip/<host>` branch newer than `main`, check out that branch and `git reset --soft HEAD~1` so the changes reappear as uncommitted, then delete the remote WIP branch.

This captures the "Syncthing for repos" feeling using git's atomic primitives. Relevant files when implementing: `scripts/sync-machine.sh` (hook into `--leave` / `--arrive`), the per-repo iteration logic from the suspend preflight.

---

### Local-AI-driven auto-commit on Super+E

Status: blocked on local-LLM capability

Goal:
- Have `Super+E` (sync-leave) optionally hand off each dirty repo to a
  local AI agent that can:
  1. Read the diff (`git diff` + `git diff --staged`)
  2. Author a meaningful, repo-aware commit message
  3. Stage + commit + push to the appropriate remote(s)
- The current `sync-leave` is intentionally read-only (notification only)
  because automated commit messages on uncommitted work would be noise
  without genuine summarisation quality. A capable local model would close
  this gap and let the user actually walk away from the laptop after a
  single keypress.

Why deferred:
- Needs a local model that is **good at tool calling** (file reads, shell
  commands, git operations) **and fast enough** to commit ~5–15 repos in
  under a minute. As of now no shipping local model in the user's
  hardware budget meets both bars reliably. Cloud models meet the bar but
  defeat the "works offline, on suspend" property.

Design notes for when this is unblocked:
- Add a `sync-machine.sh --leave-auto` mode (or flag) that delegates to a
  per-repo agent run; keep the current `--leave` as the safe default.
- Agent should refuse to commit when the diff exceeds some sanity
  threshold (e.g. >500 lines or >20 files), to avoid one runaway commit
  flattening real work. Fall back to the notification-only path with a
  "too big — commit by hand" toast in that case.
- Push step should respect existing remote conventions (e.g. `g pushall`
  semantics) and skip repos without an upstream rather than guessing.
- Worth pairing with the WIP-branch helper above: the agent's automated
  commits could land on `wip/<host>` first and only graduate to `main`
  on explicit user approval.

Relevant files when implementing:
- `scripts/sync-machine.sh` — add the `--leave-auto` codepath
- `~/.config/hypr/scripts/sync-toast` — wire `Super+E` (or a new keybind)
  to the auto mode
- `~/.config/hypr/conf.d/20-binds.conf` — keybind

---

### Live transcription with running AI commentary (`record-session` extension)

Status: deferred — current `record-session` is record-then-transcribe only

Goal:
- Stream mic audio through whisper.cpp in real time
- Feed each finalized utterance to a (cloud or local) model that can offer running commentary, clarifying questions, or flag things to act on — useful during phone calls, lectures, advising meetings
- Today's flow is post-hoc: record → Ctrl+C → transcribe → paste transcript into a chat. The live-input version would close that loop

Why deferred:
- Live commentary needs a model with **low first-token latency on streaming text input** plus the ability to decide when to speak vs stay quiet. Cloud Claude meets latency but the "stay quiet most of the time" behavior requires careful prompting and ideally a dedicated streaming integration, not the standard chat loop
- Local models on this hardware (Ryzen 7 PRO 5850U, no CUDA) are too slow for useful streaming commentary on top of whisper.cpp already eating CPU
- The chunked-transcription path (sketched and rejected before settling on the post-hoc design) had quality issues at chunk boundaries that hurt accuracy where it matters most (named entities, numbers, dates)

Architecture sketch for when this is unblocked:
- `whisper.cpp` has a `whisper-stream` binary that does live mic transcription using SDL audio capture; package it from nixpkgs alongside `whisper-cpp` and wire a `record-session --live` flag
- Pipe finalized whisper segments (whisper emits when it commits a phrase) into a small daemon that batches them and queries the model
- Display commentary via `notify-send` toast or a Quickshell panel — definitely not blocking the user with a terminal in foreground
- Persist the same WAV + markdown transcript as the post-hoc flow so live mode is strictly additive

Relevant files when implementing:
- `tools/scripts/record-session.sh` — add a `--live` mode that calls `whisper-stream` instead of `ffmpeg + whisper-cli`
- `tools/pkgs/record-session.nix` — add `whisper-cpp` `stream` binary if it isn't in the default package output
- new: `tools/scripts/transcript-commentary.sh` (or daemon) — the model-querying loop

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

### Switch firewall management from iptables to nft

Goal:
- replace any ad-hoc `iptables` commands with `nft` equivalents once nft is available on the system

### Netbird overlay network (future)

When setting up Netbird as a Tailscale alternative or complement, **do not use the default `100.64.0.0/10` range** — it collides with Tailscale's CGNAT block. Pick a clean range that doesn't conflict with:

| Range | Already in use for |
|---|---|
| `10.0.50.0/24` | Home LAN |
| `192.168.30.0/24` | VLAN30 on sweetpea |
| `100.64.0.0/10` | Tailscale CGNAT |
| `172.17-19.0/16` | Docker bridges on sweetpea |

Recommended: **`10.10.0.0/16`** — well away from home LAN, easy to remember.

### Tailscale subnet route conflict on LAN (intermittent)

Symptom: when on the home LAN, `ip route get <lan-ip>` shows traffic routed via `tailscale0` instead of the local interface. Observed on framework-13 on 2026-05-26 right after the home network's subnet mask was changed.

Root cause hypothesis: sweetpea advertises `10.0.50.0/24` as a Tailscale subnet route (for off-network access to `.home` services). Tailscale clients have `--accept-routes` and normally detect local-subnet overlap and skip installing the conflicting route — but a race with NetworkManager / stale DHCP lease after the subnet change can cause Tailscale to win.

Workarounds when it happens:
- `sudo systemctl restart tailscaled` to force re-detection of local subnets
- `sudo tailscale down && sudo tailscale up` to refresh prefs
- Or just reboot

Longer-term fix to consider: switch `.home` access strategy from advertising the LAN subnet to using sweetpea's Tailscale IP directly (`*.home → 100.97.56.82` via dnsmasq), eliminating the route advertisement entirely. Requires all `.home` services to be reachable on sweetpea's Tailscale interface.

### Framework 13 AMD support
Goal:
- add a Framework 13 AMD as a second host by refactoring `hosts/thinkpad-t14/configuration.nix` into a shared base that other host configurations derive from

---

### NixOS specialisations / alternative system profiles
Status: partially resolved — `pentest` specialisation implemented in `hosts/common/default.nix`

What's in place:
- `pentest` specialisation available on all hosts: blacklists internal WiFi, enables libvirtd + virt-manager, adds full pentest toolset (burpsuite, metasploit, nmap, etc.)
- Activate in-place: `/run/current-system/specialisation/pentest/bin/switch-to-configuration switch`
- Revert: `/run/current-system/bin/switch-to-configuration switch`

Still open:
- whether additional profiles (battery-saving, minimal, etc.) are worth maintaining
- dotfiles/home-manager integration with profile changes is not addressed

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
