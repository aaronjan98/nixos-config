# 2026-11-26 — Dark screen after idle, oversized Quickshell, Framework's wallpaper

Three separate bugs behind one cluster of symptoms on the ThinkPad T14 (`nixos`).

## 1. Dark panel after idle, only a reboot or lid-cycle recovers (the main one)

`misc:key_press_enables_dpms` and `misc:mouse_move_enables_dpms` were **never set**
and both **default to 0** in Hyprland 0.52.x (`hyprctl getoption` -> `int: 0, set:
false`). The hypridle 600s listener (`modules/hypr-idle-lock.nix`) runs `loginctl
lock-session ; sleep 2 ; hyprctl dispatch dpms off` and deliberately has **no
on-resume** — its comment asserted those two options would handle waking. They
weren't on, so nothing could turn the panel back on:

- keys/mouse did nothing (options off)
- the session was locked, so plain `bind`s were suppressed — including
  `$mainMod ALT, O` -> `dpms on`, the one manual escape hatch, which was a plain
  `bind` instead of `bindl` and therefore dead in the exact state it exists for
- `screen-blackout-off` *did* run on input resume and restored the backlight,
  so the machine looked awake (brightness restored, typing worked) with a
  completely black panel — matching the reported symptom exactly

Only two recoveries existed: cycle the lid (suspend -> resume runs hypridle's
`after_sleep_cmd` -> `hyprctl dispatch dpms on`), or reboot.

Journal evidence (`journalctl --user -u hypridle`, `journalctl -t wake-diag`):

| dpms off fired | what followed |
|---|---|
| Nov 24 08:47:21 | 08:57:28 `screen-blackout-off` (input resumed, still black) -> **08:58:15 lid closed** -> 08:58:20 `after_sleep_cmd` -> picture back |
| Nov 26 08:16:09 | same shape: resume, then **08:16:58 lid closed** to get a picture |
| Nov 23 08:53:34 | **reboot at 09:36** |
| Nov 24 23:27:59 | **reboot at 09:15** next morning |

Only fires when idling out with the **lid open** — a lid close suspends and the
suspend/resume path self-heals, which is why it was intermittent.

Fixed: `key_press_enables_dpms` / `mouse_move_enables_dpms` set in
`~/.config/hypr/conf.d/30-look.conf` `misc{}`; `bind` -> `bindl` for
`$mainMod ALT, O` in `20-binds.conf`. Hyprland handles both options in the input
path ahead of the session lock, so they work while hyprlock is up.

## 2. Oversized Quickshell on a fresh session

Shared dotfiles `30-look.conf` hardcoded `monitor = eDP-1, 2256x1504@60, 0x0, 1`
— the **Framework's** panel. The ThinkPad's eDP-1 (AU Optronics 0x573D) tops out
at 1920x1080, so Hyprland had to reject that modeset and fall back on every
startup. Quickshell launches only 0.5s after Hyprland (`10-programs.conf`
`exec-once`), landing inside that window, and latches the wrong output scale for
the whole session — hence "quit it and open it up again" being the fix.
`monitor = , preferred, auto, 1.5` is the 1.5 available to be picked up.
`QS_UI_SCALE` is *not* involved: it's unset on the ThinkPad (-> 1.25) and read
once from env, so it can't drift.

Fixed: `monitor = eDP-1, preferred, 0x0, 1` — resolves to each panel's native
mode on both laptops with no failed modeset. Scale stays 1; `QS_UI_SCALE`
compensates per host. Verified live: 1920x1080, scale 1.00, `reserved` top = 38
= `topHFramework` at uiScale 1.25.

## 3. The Framework's wallpaper appearing on the ThinkPad

Not a coincidence and not a shared display — **Syncthing**.
`~/Pictures/Wallpapers/current.png` is the symlink that records which wallpaper
this machine is using, and `~/Pictures` is a synced folder. Syncthing *does*
track symlinks on Unix, so the pointer replicated between the laptops.

Proof from the ThinkPad's own index
(`/rest/db/file?folder=Pictures&file=Wallpapers/current.png`):
`"type": "FILE_INFO_TYPE_SYMLINK"`, `local.modifiedBy: "HREY2AY"` —
framework-13's device ID. Version vector had HREY2AY at the newest counter.

Picking a wallpaper on the Framework rewrote the ThinkPad's `current.png`;
`set-wallpapers` (session start + monitor hotplug) then applied it and fed it to
matugen, recolouring the whole Quickshell palette and the light/dark mode. Only
visible after a reboot/fresh session, which is why it rode along with #1 and #2.

Fixed: `/Wallpapers/current.png` in `~/Pictures/.stignore`, installed
declaratively via `systemd.tmpfiles.rules` in `modules/syncthing.nix` (ignore
files are never synced by Syncthing, so each host needs its own — hence Nix
rather than a one-off by hand). Wallpaper *images* still sync; only the
"which one is active here" pointer is host-local now.

## Notes for next time
- `hyprctl getoption <opt>` reports the **effective** value; `set: false` means
  "not in the config", and the `int:` beside it is the real default. Don't trust
  the wiki's stated defaults over this.
- Hyprland's own logs were useless here: `debug:disable_logs` defaults to true,
  so `/run/user/1000/hypr/*/hyprland.log` stops after the config banner. Enable
  `debug:disable_logs = false` before chasing a monitor/modeset issue.
- Suspend/resume on this ThinkPad does **not** destroy and recreate eDP-1 — no
  `monitoradded` in `journalctl --user -u hypr-monitor-watch` across any resume.
  So wallpaper/scale regressions come from **session start**, not from wake.
- The `wake-diag` logger markers (added 2026-09-29, still in place) are what
  made #1 provable. Worth keeping until this has gone a few weeks without
  recurrence.

---

## Session record — 2026-11-26, ~08:30–09:00 PST

### Verification after `nrs` + `hyprctl reload`
All on the ThinkPad (`nixos`):

- `~/Pictures/.stignore` → store symlink, root-owned, installed by
  `systemd.tmpfiles.rules`. Syncthing index for `Wallpapers/current.png`:
  `local.ignored: true`.
- `/etc/xdg/hypr/hypridle.conf` regenerated with the new dependency comment.
- `hyprctl configerrors` empty after reload → the dotfiles config parses.
- `misc:key_press_enables_dpms` / `mouse_move_enables_dpms` both `int: 1,
  set: true` **after** the reload wiped the runtime `hyprctl keyword`s, which
  confirms they're coming from the committed config and not from my live pokes.
- `Super+Alt+O` now reports `locked=true` in `hyprctl binds -j` — fires while
  the session is locked, which is the only state it matters in.
- eDP-1: 1920x1080, scale 1.00, `reserved` top = 38 (= `topHFramework` at
  uiScale 1.25). Quickshell correctly sized.
- AJ changed the wallpaper to `nature-landscape-horizon/group-of-dark-leaves.jpg`;
  swww is displaying it and the pointer stayed host-local.

### Decisions
- **`preferred` over per-host monitor rules.** Considered moving the eDP-1 rule
  into each host's `99-host.conf`, but that meant duplicating the shared
  windowrules into the ThinkPad's override (common declares 99-host.conf with
  `lib.mkDefault`, so a host override replaces the whole file). `preferred` in
  the shared dotfiles is one line, correct on both panels, and removes the
  failed modeset entirely instead of papering over it.
- **Left `monitor = , preferred, auto, 1.5` alone.** It's the source of the 1.5
  that Quickshell was latching, but it only applies to *unmatched* outputs, and
  with eDP-1 no longer failing there's no window for it to be picked up. Changing
  it would alter real external-monitor behaviour on the Framework for no gain.
- **Fixed the DPMS wake at the Hyprland level, not with a hypridle `on-resume`.**
  The existing comment's reasoning against an `on-resume` is sound — hypridle
  force-"Resumed"s every rule the instant the session locks and would consume a
  `dpms on` there, before the real wake. `key_press_enables_dpms` is the upstream
  mechanism and is immune to that.
- **`.stignore` rather than relocating the pointer.** Moving `current.png` out of
  `~/Pictures` to somewhere unsynced (e.g. `~/.local/state/`) is arguably
  cleaner, but `set-wallpapers`, `Wallpapers/CONTEXT.md` and the agent notes all
  assume the current location. One ignore line, declared in Nix so both hosts
  get it, was the smaller change.

### Open questions
- **The Framework is unverified.** Its eDP-1 rule went from a hardcoded
  `2256x1504@60` to `preferred`. That should resolve to the same mode (it's the
  panel's only native one) but has not been checked on that host — look at
  `hyprctl monitors` after rebuilding there.
- Does the oversized-Quickshell race actually disappear? The failed-modeset
  window was *inferred* from the invalid mode plus Quickshell's 0.5s
  `exec-once` delay, not observed directly — Hyprland's log is empty by default
  (`debug:disable_logs`). If it recurs, set `debug:disable_logs = false` and
  catch the startup sequence before theorising further. A readiness loop instead
  of `sleep 0.5` in `10-programs.conf` is the fallback fix.
- `global_modifiedBy` for `Wallpapers/current.png` still reads `HREY2AY`. Harmless
  (locally ignored = never pulled), and it'll stop mattering once the Framework
  has the ignore too, but the stale global record will persist in the index.

### Next steps
1. On the Framework: `dot pull`, then rebuild, then check `hyprctl monitors`.
2. Behavioural test of the main fix: idle 10+ min with the lid **open**, press a
   key — expect an immediate picture, not a dark panel.
3. Keep the `wake-diag` logger markers (added 2026-09-29) until this has gone a
   few weeks clean; they're what made the diagnosis provable.
