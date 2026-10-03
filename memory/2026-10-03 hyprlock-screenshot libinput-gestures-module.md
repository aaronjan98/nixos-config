# 2026-10-03 — framework/thinkpad: see-through lock screen + gesture fixes

Short session, all in `nixos-config`. Two unrelated UX fixes on host
`framework-13` (one shared with `thinkpad-t14`). Commits: `eafa03b`, `ec6497f`
on `main`. NOT yet pushed to `home` at session end (user didn't ask).

## 1. Lock screen showed a stale static wallpaper — restored see-through screenshot
- Symptom: when the screen blanked/locked, an OLD wallpaper appeared (a specific
  art-classic painting), and BOTH laptops showed the *same* image on their lock
  screens even though they're separate machines.
- Root cause: `modules/hypr-idle-lock.nix` set hyprlock's background to a static
  image `path = /home/aj/Pictures/Wallpapers/current.png` — a symlink to
  `art-classic/painting-...jpg`. It's in the SHARED module, so both hosts
  generated an identical `/etc/xdg/hypr/hyprlock.conf` pointing at the same path
  → same stale painting on both. The desktop wallpaper (swww, via
  `hypr-monitor-watch`) is a SEPARATE system and was never involved; `current.png`
  is referenced ONLY by hyprlock.
- What the user wanted: the pre-2026-04-12 behavior — no static wallpaper, see the
  live desktop behind the lock, blurred/dimmed.
- Fix (`eafa03b`): `path = screenshot` in the shared module (both hosts). hyprlock
  captures a FRESH screenshot of the real desktop at each lock, then applies the
  existing blur+overlay (`rgba(25,20,20,0.45)`, blur_passes=1, blur_size=4 —
  unchanged, so the look matches the original). Each host now shows its own
  desktop.
- **Why it's safe again (this is the key insight):** `screenshot` had been
  swapped out because its wlr-screencopy (~10s with the Framework's external
  monitor) could lose a race with suspend → hyprlock "yeeten" → Hyprland's
  "lockscreen app died" screen. But the REAL cure for that was the later
  lid-ordering fix, not the static image:
    - framework-13 NEVER suspends (logind ignores idle/lid/suspend) → its lock
      only fires from idle timers → nothing races the copy. Unconditionally safe.
    - thinkpad-t14 suspends on lid, but `lock-and-suspend`
      (`hosts/thinkpad-t14/configuration.nix`) now LOCKS while the compositor is
      awake and settles before `systemctl suspend`. Bumped that settle
      `sleep 0.4` → `sleep 1.5` so the screencopy finishes before suspend.
  Updated the rationale comments in both `hyprlock.conf` background block and the
  `hypridle.conf` before_sleep_cmd block to reflect the revert.
- Clarified for the user: a *continuously* live desktop behind the lock is NOT
  possible with a real Wayland session lock (`ext-session-lock` hides the real
  surfaces by design; that's the security guarantee). `screenshot` = live capture
  at lock time, then frozen. Faking it with a non-locking overlay would be
  insecure. Current setup is the sweet spot. Lever available if wanted: overlay
  opacity / blur values. User chose to leave as-is.
- If "lockscreen app died" ever returns on the ThinkPad specifically: lengthen
  the settle, or pre-capture with `grim` to a file and point `path` at it (static
  load, screencopy moved out of the lock critical path).

## 2. Touch gestures dead on framework, then dead on the external trackpad
Gestures = `libinput-gestures` user service (`modules/libinput-gestures.nix`, in
`common` → both hosts). 3-finger = Quickshell notification center; 4-finger =
workspace / workspace-domain switch (`~/.config/hypr/scripts/ws-rel`,`ws-domain`).

- **2a: all gestures dead on framework.** Service was `enabled` but
  `inactive (dead)`, zero journal entries — never started this session. Root
  cause: the framework's `systemd --user` manager has run continuously since the
  last boot (Sep 5, 2026; 4-week uptime). The `libinput-gestures.nix` module that
  declares/enables the service was added AFTER that boot. `nixos-rebuild switch`
  writes the enable-symlink but does NOT start user services, and this always-on
  box never logged out/rebooted → enabled-but-never-started. The ThinkPad relogs
  often so it started normally there. Fixed live: `systemctl --user start`.
  **General gotcha (worth remembering): on this always-on framework, user
  services don't come up on `nrs` — need `systemctl --user daemon-reload &&
  systemctl --user restart <svc>` or a reboot.**
- **2b: works on internal trackpad, not the Apple Magic Trackpad.**
  `libinput-gestures` auto-binds to a SINGLE touchpad (ran
  `libinput-debug-events --device .../platform-AMDI0010:03...` = internal
  PIXA3854) and ignores all others. Fix: `device all` directive → it runs
  `libinput-debug-events` with no `--device`, watching every device.
- **Made it declarative (`ec6497f`, user's explicit request "move it into a
  module"):** the config had been a loose, unversioned `~/.config/
  libinput-gestures.conf` kept in sync only by Syncthing. Moved the bindings into
  `modules/libinput-gestures.nix` as `environment.etc."libinput-gestures.conf"`,
  added `device all`, and changed the service ExecStart to `libinput-gestures -c
  /etc/libinput-gestures.conf` so the per-user copy is ignored and both hosts are
  byte-identical. User then `rm ~/.config/libinput-gestures.conf`, nrs,
  daemon-reload + restart. Verified end state: service active with `-c /etc/...`,
  no `--device`, old file gone, `/etc/libinput-gestures.conf` symlink present.

## 3. (added after save) 3-finger up/down = switch tabs, app-aware
- User asked for 3-finger vertical swipe → Firefox tab switch. Firefox here uses
  VERTICAL tabs (Obsidian etc. use horizontal), so user wanted it app-specific.
- Implemented (`399bd8e`) in `modules/libinput-gestures.nix`: a
  `pkgs.writeShellScriptBin "gesture-tab-switch"` wrapper reads the active window
  class via `hyprctl activewindow -j | jq` and only sends Ctrl+PageUp (prev) /
  Ctrl+PageDown (next) via `hyprctl dispatch sendshortcut "CTRL, Prior/Next,
  activewindow"` when the class matches a known tabbed app (*firefox*, *librewolf*,
  *zen*, *obsidian*); no-op otherwise so it never fires stray shortcuts into a
  terminal/spreadsheet. No ydotool needed. up = prev tab, down = next tab.
- Smoke-tested: ghostty focused → clean no-op (exit 0); bad arg → usage (exit 2);
  jq parses class fine. Live Firefox/Obsidian behavior not yet confirmed by feel.
- Extend: add a `case` for other tabbed apps, or swap the two gesture lines if the
  up/down direction feels reversed. Keysyms Prior/Next = PageUp/PageDown; if those
  ever misfire, fall back to Tab / SHIFT Tab.

## State / open items
- Both fixes deployed by aj on the framework (rm + nrs + user-service restart
  done). Gestures confirmed working on internal trackpad; Magic Trackpad expected
  to work now (watching all devices) — user to confirm by feel.
- `main` is ahead of `home/main` by these commits (+ the earlier merge work from
  the prior session); NOT pushed. Offer `git push home main` when ready.
- ThinkPad still needs `nrs` + user-service restart to pick up both changes
  (screenshot lock + gesture module) if not already done.

## Reminders
- hyprlock/hypridle config is SHARED and system-wide at `/etc/xdg/hypr/*.conf`
  (from `modules/hypr-idle-lock.nix`). Desktop wallpaper is swww, separate.
- Related prior session: [[2026-09-30 wifi-roaming quickshell-bump input-idle-cutoff]].
