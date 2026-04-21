# 2026-04-21 — Roadmap & backlog session

## What was worked on

A long session establishing a cross-repo ROADMAP routing system and documenting a large backlog of bugs and features across four repos: nixos-config, quickshell, homelab/Raymer, and the dotfiles (~/.config).

---

## Key decisions

### ROADMAP routing convention
Added a routing table to `~/.config/ai/shared/agent-orientation.md` so all agents know where to file bugs/features:
- NixOS system config → `~/nixos-config/docs/ROADMAP.md`
- Dotfiles/desktop cross-cutting → `~/.config/ROADMAP.md` (delegates to area ROADMAPs)
- Quickshell → `~/.config/quickshell/ROADMAP.md` (created this session)
- Homelab (Raymer) → `~/Repositories/self-hosted/homelab/Raymer/ROADMAP.md` (created this session)

Also updated `Raymer/CONTEXT.md` and `~/.config/ROADMAP.md` index to reflect the new files.

---

## Bugs documented

### nixos-config (`docs/ROADMAP.md`)
- **Keyboard backlight not restored after lid close/open** — confirmed bug; root cause: `before_sleep_cmd` runs `screen-blackout-on` which reads current kbd brightness (already 0 if idle blackout fired) and saves 0 as the restore value. Fix: guard against overwriting a non-zero saved state. File: `modules/hypr-idle-lock.nix`

### quickshell (`~/.config/quickshell/ROADMAP.md`)
- **Escape doesn't close power or notification popups** — PowerPopup has the handler but missing `WlrLayershell.keyboardFocus`; NotificationCenter is a plain Rectangle with no handler at all
- **Top-right island cursor/click-to-close** — Wifi/Brightness/Bluetooth icons lose hand cursor when popup opens and require cursor nudge to close; NotificationIcon missing cursorShape entirely; PowerIcon is the working reference
- **Night light slider** — no live preview during drag (intentional but wrong); flash to white on commit (stop→40ms→start gap exposes unfiltered display)
- **Frame corner gaps on light wallpapers** — rectangular strips + rounded inner glow leave triangular gaps; only dark wallpapers work today

### ~/.config/ROADMAP.md
- **Claude Code notification fires regardless of focus** — `HYPRLAND_INSTANCE_SIGNATURE` and `TMUX` not propagated to hook subprocess; both focus checks silently fail → always notifies

---

## Features documented

### nixos-config (`docs/ROADMAP.md`)
- **Battery charge threshold** — AlDente-style 80% cap via sysfs `/sys/class/power_supply/BAT0/charge_control_end_threshold`; needs polkit wrapper + boot-restore systemd service; ThinkPad-specific module
- **Kanata: TCP server + launcher layer + profiles** — `tcp-port` in defcfg for bidirectional IPC; launcher layer (Super tap-hold, letter→app launch); `kanata-default.kbd` profile; open question: Super tap conflicts with home-row mods
- **Live gesture-tracked workspace transitions** — Hyprland limitation: animation only fires at gesture end; investigate Hyprland plugin path first, then MangoWC/niri as compositor alternatives; switching compositor would require rewriting all `Quickshell.Hyprland` IPC calls
- **Framework 13 AMD as second host** — refactor `configuration.nix` into a shared base; new host dir + flake registration

### quickshell (`~/.config/quickshell/ROADMAP.md`)

**Architectural foundations section added** — 8 things to implement from the start:
1. Fix popup pattern first (keyboard focus + escape + cursor)
2. Build `EffectsState.qml` singleton before any shader feature
3. Use Hyprland IPC socket, never `hyprctl` subprocess in hot paths (60 forks/sec = ~1–2% CPU)
4. Extract shared shader utilities (smoothstep, uniforms) before writing second shader
5. Wrap bar content in `layer.enabled` once — can't stack multiple conflicting layer wrappers
6. Fix frame corner gap before theme switcher
7. Pause cava when silent, from the start
8. Appearance panel is infrastructure — build skeleton before individual effects

**Performance budget table added** — all features combined cost ~2–4% CPU idle (within 5% target) if IPC socket is used correctly and cava pauses when silent. GPU load from fluid wallpaper is the variable; disable on battery via effects panel.

**Features:**
- Left bar: Kanata mode island (N/C/M/L + sliding bubble + per-mode color + bidirectional via TCP)
- Left bar: pinned app launcher dock with notification badges
- Left bar: workspace bootstrap scripts (per-domain layout restoration; standalone feature, Kanata script mode is just one trigger)
- Top bar: music visualizer (cava FIFO → frequency array → shader) + shader ripple spreading to rest of bar
- Top bar: network activity history graph (/proc/net/dev → rolling array → Canvas/shader)
- Workspace pills: app icons + expand-to-show-all + notification badges on inactive pills
- Workspace switch: ripple effect (pure QML, no shader needed)
- Chaser: light beam around content frame border (parametric `t` shader)
- Chaser: light beam around focused window (counter-clockwise, full-screen overlay, `Hyprland.focusedClient`)
- Generative art wallpaper system (Quickshell Background layer + GLSL scenes + cursor via IPC)
- Appearance & effects control panel (unified popup for theme + all effect toggles)
- Nix icon: hover spin animation (resume from frozen angle, not restart from 0)
- Battery health popup (UI side; backend in nixos-config)

### homelab (`~/Repositories/self-hosted/homelab/Raymer/ROADMAP.md`)
- **Jellyfin seasons fail to load** — browser spins until manual service restart; machine: qwerty
- **Jellyfin: suppress scheduled tasks during active playback** — defer DB/scan tasks when sessions are detected

### ~/.config/ROADMAP.md
- **General notify-on-job-complete** — zsh preexec/precmd pattern with duration threshold + focus check; replaces per-agent hooks; fix env var propagation first
- **Workspace bootstrap scripts** — per-domain scripts to recreate app layout after reboot; idempotent; multiple trigger paths (CLI, keybind, future Kanata mode)

---

## Open questions

- Kanata Super tap-hold: conflicts with home-row mods (`dmet`, `kmet`) — needs timing analysis before implementing launcher mode
- Kanata TCP port: confirm no conflict with other services
- Launcher mode: does it auto-exit after one keypress or require explicit Esc?
- MangoWC: research whether this compositor supports live gesture tracking (may be post-knowledge-cutoff)
- Generative wallpaper fluid sim: may need resolution scaling if GPU bottlenecks; test on hardware
- Battery health: polkit vs setuid approach for the privilege escalation wrapper

---

## math-ocr / pix2tex research (session continuation)

### Research findings

Web research confirmed that the venv approach is the correct direction:

- **pix2tex is NOT packaged in nixpkgs**. The only community attempt (SimonYde/pix2tex.nix) was archived and abandoned by May 2025.
- **pix2tex upstream is degrading**: deprecated dependencies (albumentations, torchtext), a known security hole (insecure pickle.load deserialization in weights loading), and active installation friction.
- **No alternatives are packaged in nixpkgs** either — texify, nougat, marker all face the same ML runtime mutability constraints.
- **The venv pattern is officially documented in nixpkgs** (`venvShellHook`) as the correct escape hatch for ML tools that assume mutable state. This is not a hack; it is the recommended approach.

### ROADMAP entry updated

Added to `nixos-config/docs/ROADMAP.md` math-ocr section:
- Paragraph explaining why pure Nix is confirmed wrong (archived community packaging, upstream drift/security)
- `systemd user service` (`bootstrap-pix2tex.service`, type oneshot) as part of Layer 1 — runs bootstrap at login on fresh machines
- Updated `tools/pkgs/math-ocr.nix` task to also include the systemd service definition

### Dead files confirmed (not yet deleted)

- `pkgs/pix2tex/` — dead custom derivation
- `pkgs/math-ocr/` — dead wrapper
- `modules/math-ocr.nix` — commented out, superseded
- `scripts/math-ocr.sh` — superseded by `tools/scripts/math-ocr.sh`
- `scripts/pix2tex-config.yaml` — orphaned model training config
- Commented lines in `flake.nix` (lines 31, 79) and `configuration.nix` (lines 17, 370)

---

## Next steps

Recommended implementation order based on dependencies:
1. Fix popup pattern (escape + keyboard focus + cursor) — unblocks all future popups
2. Fix frame corner gap — unblocks theme switcher
3. Build `EffectsState.qml` + appearance panel skeleton — unblocks all shader features
4. Network stats visualizer — easy win, no shader dependencies
5. Workspace bootstrap scripts — standalone, can be done anytime
6. Battery charge threshold backend (nixos-config) + popup (quickshell)
7. Kanata TCP server wiring — prerequisite for mode island
8. Music visualizer (cava + shader) — after EffectsState is in place
9. Chaser effects — after bar layer.enabled is established
10. Generative wallpaper — last, most GPU-intensive

---

## Session continuation — Hyprland config + cursor

### What was added

**nixos-config/docs/ROADMAP.md** — two new features:
- Floating scratchpad terminal (Ghostty with fixed class + `windowrulev2` float/size/center)
- Hyprland window stacking (`group` / `changegroupactive f` → Ctrl+Tab)

**~/.config/ROADMAP.md**:
- Removed "Fix popup tmux terminal workflow" entry — user confirmed this is fixed

**~/.config/hypr/ROADMAP.md** — created new file; linked from `~/.config/ROADMAP.md`:
- **Feature**: Sticky tiled window (follows workspace switches via IPC daemon + `movetoworkspacesilent`)
- **Limitation**: Unified cross-app navigation with Alt+Shift (f-hold / `fj_chord`) not achievable — Hyprland global intercept prevents seamless nvim↔Hyprland navigation; conceded solution is `Super+arrow keys` for intra-workspace window focus
- **Bug**: nvim → Hyprland window bounce-back (focus lands on Hyprland window then snaps back to nvim; undiagnosed — possible causes: nvim FocusLost autocmd, double-dispatch from both layers, xremap re-intercepting)
- **Feature**: Cursor redesign — replace filled `--base-color "#192629"` with thin black stroke around red parts; try `--base-color transparent` first, fall back to patching SVGs in `preBuild`
- **Feature**: Cursor size at boot — move `XCURSOR_SIZE/THEME` from `00-env.conf` `env =` directives into `environment.sessionVariables` in `configuration.nix` so they're in `/etc/environment` before Hyprland initialises

### Implemented (live)
- `Super+Shift+V` → `pin` keybinding in `~/.config/hypr/conf.d/20-binds.conf` — pins/unpins a floating window so it follows across all workspaces (PiP use case)
