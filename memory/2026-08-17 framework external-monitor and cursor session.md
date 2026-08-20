# 2026-08-17 — Framework external-monitor + cursor session

Session on framework-13 covering two Framework display bugs. Both shipped;
repos committed and pushed to all remotes.

---

## 1. External monitor: first window opens on an unaddressable workspace

### Symptom
When first opening a window on the external monitor (Samsung ultrawide, DP-1),
it wasn't focused into a single workspace — no horizontal dot appeared on the
quickshell top-bar island. Switching workspaces on the external monitor then
worked for *new* windows, but the earlier window had been stranded and no longer
showed up.

### Root cause
The quickshell top-bar dot island (`~/.config/quickshell/rices/limerence/
components/frame/TopBar.qml`) addresses external-monitor workspaces only in the
range **101–109** (`slot = wsId % 10`, occupancy filtered by
`workspaceBelongsToScreen` = `id >= 101 && id <= 109`). DP-1 had **no declared
default workspace**, so Hyprland handed it an off-scheme id on connect —
**observed live: workspace 100**. `100 % 10 = 0` → `activeIndex = -1` → no dot
ever renders active, and a window on 100 is invisible to the occupancy scan.
Caught it live: a Firefox window was stranded on ws 100 on DP-1.

### Fix
Added to dotfiles `~/.config/hypr/conf.d/30-look.conf`:
```
workspace = 101, monitor:DP-1, default:true, persistent:true
```
Native Hyprland — DP-1 now always gets in-range workspace 101 on connect;
`persistent:true` keeps it alive so no stray workspace can form in the race
window. Committed to dotfiles (later part of merge commit `f2d2191`). Also moved
the live stranded window off ws 100 with `hyprctl dispatch movetoworkspace`.

### Note for future
The external-monitor addressing scheme (101–109) lives in both TopBar.qml and
`~/.config/hypr/scripts/ws-current-monitor.sh` (jq filter). Any off-scheme id
breaks the island silently.

---

## 2. Cursor oversized at boot on the Framework (the long one)

Full technical writeup: **`2026-08-17 framework cursor oversized at boot.md`**.

### Outcome
- **Resolved** for practical purposes by setting the Framework cursor size to
  **48** (was 72). The oversized-at-startup behavior is a **Hyprland 0.52.1
  HiDPI cursor-scaling bug** (theme-, setting-, and monitor-independent;
  self-corrects only on a scale-change redraw), NOT a config error. Size 48
  simply doesn't exercise it. Size lives in `hosts/framework-13/
  configuration.nix` (sessionVariables + 99-host.conf env= + exec-once).
- **Two genuine defects found and fixed en route** (neither was the size cause,
  both worth keeping):
  1. Phantom cursor theme name — dotfiles `00-env.conf` set
     `XCURSOR_THEME=Breeze_Hacked_Black`, a theme that was never built (pkg only
     produces `Breeze_Hacked`). Fixed to the real name. Shared → also fixes the
     ThinkPad.
  2. Halo inflation — `pkgs/breeze-hacked-cursor/default.nix` baked a near-white
     halo that inflated every rasterized cursor ~25% beyond nominal size (72→90px)
     and drew the unwanted white outline. Removed. Shared → ThinkPad cursor also
     loses the halo and renders at accurate size.

### Dead ends (all falsified by reboot tests — don't retry)
exec-once setcursor present/absent · `no_hardware_cursors` (caused external-mon
ghosting) · `hyprctl dispatch movecursor` (not a real input event) ·
`enable_hyprcursor=false` · `use_cpu_buffer=true` · stock `breeze_cursors` theme
· greeter `display-manager.environment` · unplugging the external monitor.

### If revisited
Real fixes would be a Hyprland bump past 0.52.1 (from nixpkgs), or switching the
panel to proper fractional scaling + normal cursor size (re-tunes the whole UI).

---

## Commits / sync
- nixos-config `950c80a` (cursor size 48 + halo removal + memory) → pushed home/hub/local.
- dotfiles `f2d2191` (phantom theme fix + DP-1 workspace; **merge** that also
  integrated 10 stranded commits from the ThinkPad — accent picker, emoji picker,
  altgr-intl, timezone clock, notif-center sizing, domain-dot fix) → pushed all.
- The dotfiles `home`/`hub` push was initially blocked by a pre-existing
  divergence; `sync-toast arrive` uses `pull --ff-only` which can't fast-forward
  when local is ahead, so it needed a manual `dot pull --no-rebase home main`.

## Open follow-ups
- Next time at the **ThinkPad**, run Super+A (arrive sync) so it picks up merge
  `f2d2191`, else it re-diverges. ThinkPad rebuild will also pick up the shared
  halo removal + phantom-theme fix (cursor appearance changes slightly there).
- Cursor size 48 on Framework is a workaround; the upstream Hyprland HiDPI bug
  remains. Revisit on a Hyprland version bump.
