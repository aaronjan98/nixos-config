# 2026-08-17 — Framework cursor oversized at boot (unresolved: upstream Hyprland)

## Symptom
On the Framework 13 (framework-13), the mouse cursor renders **oversized** at the
SDDM greeter and at early Hyprland desktop, then snaps to the correct size only
after a scale-change redraw is triggered. Does NOT happen on the ThinkPad.

## Conclusion
This is an upstream **Hyprland 0.52.1 HiDPI cursor-scaling bug**, not a config
error. Every config-level cause was falsified by real reboot tests:

| Tried | Result |
|---|---|
| Custom `Breeze_Hacked` theme → stock `breeze_cursors` | identical → not the theme |
| Every `XCURSOR_SIZE` / `XCURSOR_THEME` (session, greeter, hypr env=) | all correct, still big → not a setting |
| `cursor:enable_hyprcursor = false` | no change |
| `cursor:no_hardware_cursors` | no change + duplicate/ghost cursor on external monitor |
| `cursor:use_cpu_buffer = true` | no change |
| `hyprctl dispatch movecursor` nudge (in-place and at bar coords) | never did anything (not a real input event) |
| `systemd.services.display-manager.environment` XCURSOR_SIZE for greeter | greeter still oversized |
| **External monitor unplugged, reboot** | still big → NOT caused by the external monitor |

## Key diagnostic facts
- Wayland cursors are **per-surface**: clients set their own cursor from their own
  env on pointer-enter. Hyprland's own env is correct (`Breeze_Hacked`/size).
- The "hovering quickshell fixes it" behavior is **not** the client setting the
  cursor — it's a cursor **re-render triggered by a scale-change event**. With the
  mixed-scale external monitor (eDP-1=1.0, DP-1=1.6) present, moving the pointer
  triggers that redraw. With a single uniform-scale panel, nothing triggers it, so
  the oversized cursor never self-corrects (confirmed: laptop-only, hover did
  nothing; re-adding the external monitor made hover work again).
- ThinkPad escapes it purely because size 32 on a lower-DPI panel doesn't expose
  the bug.

## Genuine defects found and fixed along the way (kept)
1. **Phantom cursor theme name.** Shared dotfiles `~/.config/hypr/conf.d/00-env.conf`
   set `XCURSOR_THEME = Breeze_Hacked_Black`, a theme that never existed (the pkg
   only ever builds `Breeze_Hacked`). Introduced 2026-07-14 (dotfiles `e3819ff`).
   Fixed → `Breeze_Hacked`.
2. **Halo inflation.** `pkgs/breeze-hacked-cursor/default.nix` added a near-white
   "halo" (duplicate stroked copy of each accent shape) for dark-bg contrast that
   inflated every rasterized cursor ~25% beyond its declared nominal size (size-72
   image was 90×90px). Removed. Also produced the white outline the user disliked.

## Final state (cleanup)
- Framework cursor size set to **48** (down from 72) to reduce how jarring the
  startup cursor is; theme `Breeze_Hacked`; `env=` + `exec-once hyprctl setcursor`
  in `hosts/framework-13` `99-host.conf`.
- Removed all session debugging additions: `display-manager.environment`,
  `use_cpu_buffer`, `enable_hyprcursor`, `no_hardware_cursors`, the nudge script.

## If revisited
- Most likely real fix: **bump Hyprland past 0.52.1** (from nixpkgs; would need a
  nixpkgs bump or a `hyprland` flake input). Possible version regression.
- Root-cause-correct alternative: run eDP-1 at a proper **fractional scale**
  (1.5/2) with a normal cursor size instead of scale=1 + size-72 — but that
  re-tunes the whole UI (QS_UI_SCALE, fonts, window sizes).
- The only reliable in-session trigger for the corrective redraw is a genuine
  output/scale-change event (monitor hotplug/reconfigure); `hyprctl dispatch
  movecursor` does NOT count.
