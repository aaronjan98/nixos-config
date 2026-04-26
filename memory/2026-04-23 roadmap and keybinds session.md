# 2026-04-23 — Roadmap additions and Hyprland keybind work

## What was worked on

Continued roadmap documentation and live Hyprland keybind implementation across several config repos.

---

## Roadmap additions

### opencode (`~/.config/opencode/ROADMAP.md`)
- **Default model falls back to removed ollama model on launch** — opencode defaults to `glm flash` (or similar) from ollama, which is no longer installed; likely a stale model entry in `opencode.json` or the DB. Fix: update/remove the model entry to point to Anthropic provider.
- Note: the migration-on-every-launch bug was already documented (upstream issue anomalyco/opencode#16885).

### Quickshell (`~/.config/quickshell/ROADMAP.md`)
- **Brightness sliders out of sync with hardware keys** — backing service doesn't watch for external brightness changes; slider drifts if you use keyboard keys before opening the popup. Fix: live sysfs watch or DBus subscription in `BrightnessCtl.qml`.
- **Battery popup: power mode switcher** — extended existing charge limit toggle entry to include a power mode switcher (power-saver / balanced / performance) via `energy_performance_preference` sysfs or `power-profiles-daemon` DBus.
- **Calendar icon in top-right pill** — new `CalendarIcon` before `W.Clock`, opens a unified popup with Calendly (REST API), Obsidian daily notes (file watch), and any other calendar feeds. New files: `CalendarIcon.qml`, `CalendarPopup.qml`, `CalendarService.qml`.

### Hyprland (`~/.config/hypr/ROADMAP.md`)
- **Floating windows: auto-center and default size on Super+V** — documented two options (passive `windowrulev2` vs active script). Currently implemented via Option A (see below).
- **Floating windows render behind Quickshell bars** — documented as a Wayland layer-shell limitation; `TopBar`/`LeftBar` default to `WlrLayer.Top`. No standard fix; design around it or investigate Hyprland `layerrule`.
- **Super+Z stateful float-zoom toggle** — attempted and reverted (see below).

---

## Live changes implemented

### `nixos-config/modules/screenshot-tools.nix`
- Added `sleep 0.08` to `shot-full-save` and `shot-full-save-monitor` — same race fix already present in `shot-region-save`. Fuzzel menu was still composited when grim captured the frame for fullscreen options.

### `~/.config/hypr/conf.d/20-binds.conf`
- `Super+Z` = `fullscreen, 1` — maximize to work area (stays within bars; other windows don't reflow, tmux-style)
- `Super+V` now has a second dispatch: `centerwindow` — auto-centers immediately on float toggle (windowrulev2 `center` rule only fires on window open, not on state change)
- `Super+C` = `centerwindow` — re-center a floating window after dragging

### `~/.config/hypr/conf.d/40-windowrules.conf`
- `windowrulev2 = size 1100 700, floating:1, pinned:0` — default float size, considerably smaller than tiling 1800×980; overrides tiling size rules since this file is sourced last
- `windowrulev2 = center, floating:1, pinned:0` — pairs with above; pinned (PiP) windows excluded

---

## Attempted and reverted

### Super+Z stateful float-zoom toggle
- Goal: first press saves state (size, position, float/tiled) → floats to 1800×980 centered; second press restores everything
- Implemented as `~/.config/hypr/scripts/float-zoom` bash script using `hyprctl activewindow -j` + per-window state files in `/tmp/hypr-float-zoom/<addr>`
- **Did not work reliably** — unclear root cause (possibly `movewindowpixel exact` syntax, dispatch timing, or state not persisting as expected)
- **Reverted**: script deleted, `Super+Z` restored to simple `fullscreen, 1`
- Documented in `~/.config/hypr/ROADMAP.md` with next investigation steps

---

## Key decisions
- `windowrulev2` source order matters: `40-windowrules.conf` is sourced after `20-binds.conf` so floating size rules there correctly override tiling size rules
- Pinned windows excluded from float size/center rules since they have intentional positions
- `WlrLayer.Top` for TopBar/LeftBar is a protocol constraint, not a bug — floating windows behind bars is expected behavior

## Open questions / next steps
- Verify `movewindowpixel exact X Y,address:ADDR` dispatch syntax when revisiting float-zoom
- Decide on Super+Z float-zoom behavior: pure bash script vs Quickshell service approach
- Float default size 1100×700 — confirm this feels right in practice or adjust
