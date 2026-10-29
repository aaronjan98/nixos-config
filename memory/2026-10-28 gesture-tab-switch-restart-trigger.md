# 2026-10-28 — 3-finger tab-switch "stopped working after a rebuild": nrs removes a capability from a never-restarted user daemon

Follow-up to [[2026-10-03 hyprlock-screenshot libinput-gestures-module]]. The 3-finger
tab-switch gesture (Firefox/Obsidian) silently died. Symptom looked like a dead gesture;
cause was a desync between the running user daemon and the installed system.

## Diagnosis path (what it was NOT)
- Config was correct: `/etc/libinput-gestures.conf` maps all four 3-finger directions to
  `gesture-tab-switch`. The downstream chain was fully healthy — verified the script detects
  Firefox (`hyprctl activewindow -j | jq .class`) and that `hyprctl dispatch sendshortcut
  "CTRL, Next/Prior, activewindow"` actually flips tabs (window title changed between
  next/prev). So script + Hyprland dispatch were fine.
- The `jq: parse error: Invalid numeric literal at line 1, column 28` lines in the journal are
  RED HERRINGS: they only fire when you swipe over a non-tabbed surface (empty workspace, a
  layer like fuzzel/notif-center) where `hyprctl activewindow -j` returns non-JSON; the script
  then exits 0 harmlessly.

## Root cause (nrs removed a working capability — NOT a missed new feature)
`libinput-gestures` is a **user** service that reads its config ONCE at startup and freezes the
store paths it references (the config + the `gesture-tab-switch` store path embedded in it).
The running daemon (pid 2654) had been up since **Oct 18** and was never restarted across the
Oct 24/27 rebuilds. `switch-to-configuration` only restarts a user unit when the **unit file**
or a **restartTrigger** changes — and the unit file only moves when the `libinput-gestures`
PACKAGE bumps, while the gesture config lived in a SEPARATE `environment.etc` file the unit had
no link to. So every `nrs` churned the store paths underneath a frozen daemon (two
`gesture-tab-switch` paths existed: old `7jlg00…` pre-`3bf244f` vs current `3179…`), GC
reclaimed the stale ones, and the capability that had worked since Oct 3 silently vanished.
This is the same dangling-store-path class as the old enable-symlink rot the module header
already documents. The config was NOT new; the rebuild took something away.

## Immediate fix (live, no rebuild)
`systemctl --user daemon-reload && systemctl --user restart libinput-gestures` — fresh daemon
reloads the current `/etc` config and the current `gesture-tab-switch`. (nrs/`nrs` does NOT do
this on its own for the reason above.)

## Durable fix (committed in modules/libinput-gestures.nix)
Added `restartTriggers = [ config.environment.etc."libinput-gestures.conf".source ];` to
`systemd.user.services.libinput-gestures` (and `config` to the module's arg set). The trigger
embeds the config hash into the unit as `X-Restart-Triggers`, so the unit file now changes
whenever the gesture config OR the embedded `gesture-tab-switch` hash changes → the switcher
sees a changed unit → restarts the daemon onto the new paths before the old ones are GC'd.
Covers both a semantic gesture edit and an unrelated dep bump that only moves the hash.

## How nrs actually applies it (25.11 switch-to-configuration-ng)
Confirmed in the ng source (`pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs`): after
reconciling system units it calls logind `ListUsers` ("Reload user units", ~L1737) and, for
each logged-in user, re-execs itself as that user (uid/gid + `XDG_RUNTIME_DIR`) to run the same
diff/restart logic against their systemd instance. So nrs DOES reconcile user services — it
just needs an **active login session** (logind must list the user). Normal case: you rebuild
from a terminal inside Hyprland → daemon restarts. No session at nrs time → no stale daemon
either; next login starts a fresh daemon from the new config. Both hosts share the flake.lock
(same ng switcher), so framework-13 and thinkpad-t14 behave identically. The option
`systemd.user.startServices` was removed in 25.11 because this per-user reconciliation is now
the default.
- The FIRST nrs carrying this change restarts the daemon too, because adding `X-Restart-Triggers`
  is itself a unit-file change.
- `~/nixos-config` writes are still classifier-blocked for the agent → staged in scratchpad,
  AJ `cp`'d it in, then `nrs`.

Supersedes the "nrs won't restart it" warning in [[2026-10-03 hyprlock-screenshot libinput-gestures-module]]:
that was true only because nothing linked the unit to its config; the per-user pass always ran,
it just found the unit unchanged and skipped it.
