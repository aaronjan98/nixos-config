# 2026-04-24 — Roadmap additions and Hyprland keybind work

## What was worked on

Continued roadmap documentation, Hyprland keybind work, and bug diagnosis from the previous session.

---

## Roadmap additions

### opencode (`~/.config/opencode/ROADMAP.md`)
- **Default model falls back to removed ollama model** — stale model entry in `opencode.json` or DB. Fix: update/remove the model entry.

### Quickshell (`~/.config/quickshell/ROADMAP.md`)
- **Brightness sliders out of sync with hardware keys** — `BrightnessCtl.qml` doesn't watch for external changes; fix: live sysfs/DBus watch.
- **Battery popup: power mode switcher** — extended charge limit toggle entry to include power-saver/balanced/performance switcher via `energy_performance_preference` or `power-profiles-daemon`.
- **Calendar icon in top-right pill** — `CalendarIcon` before `W.Clock`, unified popup for Calendly (REST API), Obsidian daily notes (file watch), other feeds.
- **Domain dot click: wrong slot after keyboard navigation** — two root causes diagnosed (see below).

### Hyprland (`~/.config/hypr/ROADMAP.md`)
- **Floating windows: auto-center and default size on Super+V** — two options documented; Option A (windowrulev2) implemented.
- **Floating windows render behind Quickshell bars** — Wayland layer-shell constraint; `TopBar`/`LeftBar` at `WlrLayer.Top`.
- **Super+Z stateful float-zoom toggle** — attempted and reverted; documented with next investigation steps.

---

## Live changes implemented

### `nixos-config/modules/screenshot-tools.nix`
- Added `sleep 0.08` to `shot-full-save` and `shot-full-save-monitor` — same fuzzel-dismiss race fix already present in `shot-region-save`.

### `~/.config/hypr/conf.d/20-binds.conf`
- `Super+Z` = `fullscreen, 1` — maximize to work area (stays within bars; others don't reflow, tmux-style)
- `Super+V` — second dispatch `centerwindow` chained; auto-centers on float toggle
- `Super+C` = `centerwindow` — re-center a floating window after dragging

### `~/.config/hypr/conf.d/40-windowrules.conf`
- `windowrulev2 = size 1100 700, floating:1, pinned:0` — default float size, overrides 1800×980 tiling rules (file sourced last)
- `windowrulev2 = center, floating:1, pinned:0` — auto-center on float; pinned windows excluded

---

## Attempted and reverted

### Super+Z stateful float-zoom toggle
- Bash script using per-window state files in `/tmp/hypr-float-zoom/<addr>`
- Did not work reliably (unclear: `movewindowpixel exact` syntax, dispatch timing, or state issue)
- Reverted to `fullscreen, 1`; documented in `~/.config/hypr/ROADMAP.md`

---

## Bug diagnosed: domain dot click navigates to wrong slot

Two interacting root causes:

**1. LeftBar click doesn't save departing slot**
`onClicked` in `LeftBar.qml` reads `DomainMemory.lastSlot(target)` but never calls `setLastSlot(currentDom, currentSlot)` before dispatching. All keyboard scripts save before navigating; the click handler skips this.

Fix: add `S.DomainMemory.setLastSlot(root.domain, root.slot)` at the top of `onClicked` in `LeftBar.qml`.

**2. Atomic `mv` breaks `FileView` inotify watch**
`ws-domain`, `ws-rel`, `ws-slot` all write via `awk > tmp && mv tmp last.txt`. `mv` replaces the file with a new inode, silently detaching `FileView { watchChanges: true }` after the first keyboard navigation. Subsequent script writes go undetected; `lastSlot()` returns stale data (often 1).

Fixes:
- In scripts: replace `mv tmp last.txt` with `cat tmp > last.txt && rm tmp` (in-place write, same inode)
- In `DomainMemory.qml`: call `lastView.reload()` inside `lastSlot()` as defensive force-read

Relevant files:
- `rices/limerence/components/frame/LeftBar.qml` ~line 137
- `rices/limerence/components/state/DomainMemory.qml`
- `~/.config/hypr/scripts/ws-domain`, `ws-rel`, `ws-slot`

---

## Key decisions
- `windowrulev2` source order matters: `40-windowrules.conf` sourced after `20-binds.conf`; floating rules correctly override tiling rules
- Pinned windows excluded from float size/center rules
- `WlrLayer.Top` for bars is a Wayland protocol constraint; floating windows behind bars is expected

## Open questions / next steps
- Implement the two-part domain dot click fix (LeftBar + scripts)
- Verify `movewindowpixel exact X Y,address:ADDR` dispatch syntax for float-zoom revisit
- Float default size 1100×700 — confirm in practice or adjust
