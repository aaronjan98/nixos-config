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

## 4. Gesture directions finalized + both-axis 3-finger tab switch
- Final state (committed `3bf244f`, `modules/libinput-gestures.nix`):
  - **3-finger ANY direction = switch tab**: up/left = next, down/right = prev.
    Both axes bound so it works regardless of tab orientation (Firefox vertical
    tabs, Obsidian horizontal). The old 3-finger notification-center bind removed.
  - **4-finger = "content-drag"** feel: swipe left = next workspace (ws-rel +1),
    swipe up = next domain (ws-domain down). (Flip-flopped: `d24055c` was the
    opposite "toward-target"; user wanted it reversed — content-drag is final.)
- `gesture-tab-switch` wrapper sends **app-specific** keys (not shared):
  Firefox/librewolf/zen → Ctrl+PageDown/PageUp; **Obsidian → Alt+L / Alt+H**
  (its next/prev-tab are remapped to those in the vault's vim-style
  `.obsidian/hotkeys.json`; Ctrl+Page* does nothing there); other apps = no-op.
  Delivered via `hyprctl dispatch sendshortcut` → injects into the focused window,
  **bypassing kanata/home-row-mods** (why synthetic Alt+L works even though
  physical Alt lives on a home-row key).
- Tuned live via a throwaway harness (NOT nix): a systemd user drop-in
  `~/.config/systemd/user/libinput-gestures.service.d/90-tuning.conf` overriding
  ExecStart to `-c ~/.config/libinput-gestures.test.conf`, plus writable
  `~/.config/libinput-gestures-tabswitch.test.sh` — flip + restart the USER
  service without nrs. **GOTCHA: libinput-gestures `-d` is DRY-RUN** (logs, never
  executes — it killed all gestures); use `-v` for verbose. Teardown pending.

## 5. Obsidian shortcuts dead on framework — REAL cause was MISSING PLUGINS
- Symptom: Alt+D (daily note), LaTeX, Alt+H/L all dead in Obsidian on framework,
  fine on thinkpad.
- RED HERRING chased + ruled out: framework kanata also remaps the EXTERNAL SONiX
  keyboard (commit `945473c`, Aug 16) with the full home-row-mod layout (Alt on
  hold-`s`/hold-`l`). Tested removing SONiX from `linux-dev-names-include` → HRM
  went off the external board but Obsidian shortcuts STILL dead → kanata NOT the
  cause. Reverted (SONiX restored). NOTE: kanata is a SYSTEM service
  (`services.kanata`, configFile `/etc/kanata/kanata-internal.kbd`) with NO
  restartTriggers → nrs does NOT restart it; needs `sudo systemctl restart
  kanata-internal`.
- REAL cause: the vault (`~/Repositories/self-hosted/zettelkasten`) is a git repo
  whose `.gitignore` excludes `.obsidian/plugins/` (line 50). Plugin BINARIES
  never git-pulled to the framework — `community-plugins.json` listed 11 enabled
  (Templater=Alt+D, obsidian-latex-suite, vimrc-support, notebook-navigator, …)
  but their code was absent → commands didn't exist → no shortcut fired.
- Fix: rsync'd plugins from thinkpad over Tailscale; for persistence added a
  Syncthing folder for `.obsidian/plugins/` (`modules/syncthing.nix`, `f0ceb96`;
  laptops only, no versioning). Can't git-track them: LaTeX Math's main.js alone
  is 103MB (bundles Sympy/Pyodide WASM) and GitHub rejects >100MB files.

## 6. SSH over Tailscale between the laptops (declarative)
- User had opened thinkpad sshd by hand. Made declarative (`20e4694`): thinkpad
  now mirrors the framework — sshd binds all interfaces, port 22 opened ONLY on
  `tailscale0` (key-only, no root). Both laptops ssh/rsync between each other by
  their `100.x` tailnet IPs. Documented in CONTEXT.md ("Remote access between
  hosts"). Find IPs via `tailscale status`.

## State / open items (as of 2026-10-03 end)
- Commits on `main`, NOT pushed, and NEITHER host rebuilt for the final state yet:
  `eafa03b` hyprlock screenshot lock · `ec6497f`/`399bd8e`/`d24055c`/`3bf244f`
  libinput-gestures (final = 3bf244f) · `f0ceb96` syncthing obsidian-plugins ·
  `20e4694` thinkpad SSH-over-tailscale + CONTEXT.md (+ `bb1a445` + this note).
- **DEPLOY (user):** framework `nrs` + `sudo systemctl restart kanata-internal`;
  thinkpad `nrs`. Then **tear down the gesture harness** on the framework:
  `rm -f ~/.config/systemd/user/libinput-gestures.service.d/90-tuning.conf;
  rmdir ~/.config/systemd/user/libinput-gestures.service.d 2>/dev/null;
  rm -f ~/.config/libinput-gestures.test.conf ~/.config/libinput-gestures-tabswitch.test.sh;
  systemctl --user daemon-reload && systemctl --user restart libinput-gestures`
  (until torn down, the drop-in masks the baked /etc config — identical once
  nrs'd, but future libinput-gestures.nix changes won't apply).
- Obsidian plugins already rsync'd to framework → shortcuts work now.
- `git push home main` when ready.

## Reminders
- hyprlock/hypridle config is SHARED, system-wide at `/etc/xdg/hypr/*.conf`
  (`modules/hypr-idle-lock.nix`). Desktop wallpaper is swww, separate.
- kanata = SYSTEM service, no restartTriggers → restart manually after nrs.
- libinput-gestures = USER service → nrs won't restart it (`systemctl --user
  daemon-reload && systemctl --user restart libinput-gestures`). `-d` = dry-run!
- Related prior session: [[2026-09-30 wifi-roaming quickshell-bump input-idle-cutoff]].
