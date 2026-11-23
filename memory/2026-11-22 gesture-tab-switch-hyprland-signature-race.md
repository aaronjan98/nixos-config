# 3-finger tab switch died on framework-13: missing HYPRLAND_INSTANCE_SIGNATURE

Date: 2026-11-22
Host: framework-13
Files: `modules/libinput-gestures.nix`, `~/.config/hypr/conf.d/10-programs.conf`

## Symptom

3-finger swipe tab switching stopped working. 4-finger workspace/domain gestures
kept working normally. This is the **third distinct** failure of this same gesture,
and it is NOT the ThinkPad semi-MT hardware issue (that's a different host and a
different cause — see `2026-10-29 thinkpad 3-finger gesture touchpad firmware.md`).

## Diagnosis

The unit was `active (running)`, the config at `/etc/libinput-gestures.conf` had the
correct 3-finger bindings, and the swipes *were* being detected. The only trace of
anything wrong was a stray line in the journal:

    libinput-gestures[1645942]: jq: parse error: Invalid numeric literal at line 1, column 28

`hyprctl activewindow -j` worked perfectly from an interactive shell. Comparing
`/proc/<mainpid>/environ` against the shell environment found the cause:

    # daemon environ -- no HYPRLAND_INSTANCE_SIGNATURE, no WAYLAND_DISPLAY
    # shell environ  -- HYPRLAND_INSTANCE_SIGNATURE=unknown_1795309200_305203127

Without the signature, `hyprctl` prints `HYPRLAND_INSTANCE_SIGNATURE not set! (is
hyprland running?)` on stdout and **exits 0**. jq can't parse that (column 28 lands
mid-message), `$class` comes out empty, and the script's `case` falls through to its
`*) exit 0` unknown-app no-op. So the gesture became a **silent** no-op.

### Why the environment was empty

`libinput-gestures.service` is `wantedBy = default.target`, so the systemd **user
manager starts it at login**, racing Hyprland's

    exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR

in `~/.config/hypr/conf.d/10-programs.conf`. When the unit wins that race it inherits
a signature-less environment and **freezes it for its whole lifetime** — a long-running
daemon never re-reads the manager environment. Service started 17:00:00 at the
2026-11-21 boot; Hyprland's import landed after. Previous boots happened to survive
because a rebuild's `restartTriggers` restarted the unit *after* Hyprland was up.

### Why 4-finger kept working

`~/.config/hypr/scripts/ws-rel` and `ws-domain` already contain an explicit
signature-recovery block that re-derives it from `$XDG_RUNTIME_DIR/hypr`.
`gesture-tab-switch` (defined inline in the Nix module) did not. That asymmetry is the
entire explanation for "3-finger broken, 4-finger fine" on this host.

## Fix

Two changes to the `tabSwitch` script in `modules/libinput-gestures.nix`:

1. **Re-derive the signature** when absent, mirroring the ws-* scripts:
   `sig="$(ls -1t "$XDG_RUNTIME_DIR/hypr" | head -n1)"` then export it.
2. **Validate the IPC reply** with `jq -e .` and `exit 1` with the raw hyprctl output
   on stderr. A broken IPC is now a loud journal error instead of being
   indistinguishable from "focused window isn't a tabbed app".

Verified by running the newly built script under `env -u HYPRLAND_INSTANCE_SIGNATURE
-u WAYLAND_DISPLAY`: the old script printed the jq error and rc=0; the new one printed
`ok` (hyprctl's dispatch ack, i.e. the tab actually switched). With
`XDG_RUNTIME_DIR=/nonexistent` it now fails rc=1 with a readable message.

Immediate restoration without a rebuild: `systemctl --user restart libinput-gestures`
(the manager environment *does* have the signature once Hyprland is up).

## Generalizable lesson

This is the same class of bug as the two failures already documented in the module
header (stale enable-symlink, frozen store paths across rebuilds): **a long-running
user unit must never depend on inherited session state.** Re-derive it at use time.
Any new Hyprland-touching script spawned from a systemd user unit needs the
signature-recovery block. And any script that branches on an IPC result should
distinguish "query failed" from "query returned nothing" — collapsing those two into
one silent no-op is what made this take so long to notice in all three instances.

## It was hitting the ThinkPad too — and it corrupted the 2026-10-29 diagnosis

Checked `thinkpad-t14` the same day: its daemon (started 2026-11-19 09:00:55, running since)
also had **no `HYPRLAND_INSTANCE_SIGNATURE`**, with the same `jq: parse error` signature
recurring across the Nov 13, Nov 19 and Nov 22 boots. Journal counts there:

```
successful dispatches ("ok"):      21
detected-but-dropped ("jq error"): 55
this boot alone:                    0 ok, 3 jq errors
```

So 3-finger tab switch had been **100% dead on the ThinkPad for ~3.5 days**, and the 55 jq
errors are each a swipe the "unreliable" ThinkPad touchpad detected *correctly* before
software discarded it. (The two counts aren't a clean ratio — "ok" only logs for tabbed
apps, the jq error logs for every invocation.)

This means `memory/2026-10-29 thinkpad 3-finger gesture touchpad firmware.md` attributed too
much to hardware: its session fixed the stale daemon with a `systemctl --user restart`,
which incidentally repaired the environment too, so the residual flakiness looked purely
hardware. The restart doesn't survive a reboot. An addendum correcting that note is written;
`MEMORY.md` carries a matching correction banner.

**Lesson about the diagnosis itself, not just the bug:** a silent `exit 0` failure path
doesn't merely hide a bug, it *actively misattributes* it — it made a software regression
read as flaky hardware for three weeks and sent the investigation into kernel params, module
load order, and a BIOS flash. Worth remembering that both hosts were ultimately the same
bug, twice root-caused to the wrong layer. The loud-failure change in this fix is the part
that matters most long-term.

Immediate restore applied on both hosts via `systemctl --user restart libinput-gestures`;
both still need `nrs` for the durable fix.
