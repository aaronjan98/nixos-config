# 2026-10-29 — ThinkPad T14: 3-finger tab-switch gesture unreliable, root-caused to touchpad firmware

## What was worked on
Investigated a report that the 3-finger tab-switch gesture (Firefox/Obsidian), fixed on
the Framework 13 the day before (commit `1587d31`, see
[[2026-10-28 gesture-tab-switch-restart-trigger]]), didn't work on the ThinkPad T14 after
`nrs`.

## Diagnosis path
1. First suspected the same stale-daemon issue as the Framework fix (user-service never
   restarted across a rebuild). Confirmed and fixed that too (`systemctl --user restart
   libinput-gestures`) — but 3-finger swipe was still unreliable afterward, so there were
   two independent problems.
2. Proved the software pipeline was correct: manually invoking `gesture-tab-switch next`
   with Obsidian focused worked every time (tab title changed). `hyprctl dispatch
   sendshortcut` into `activewindow` succeeded ("ok" in the journal) on physical swipes
   too — detection and dispatch were both fine *when the gesture was recognized at all*.
   **Note**: the user initially observed "works in Firefox, not in Obsidian" and later
   "worked in Obsidian, then stopped working back in Firefox" — this pattern is
   coincidental, not app-specific. The misdetection in step 3 below happens entirely in
   the touchpad hardware/driver *before* the app-aware script or window class is ever
   consulted, so which app is focused can't affect it. Each swipe is close to a coin
   flip; the observed per-app pattern was just which way enough individual flips landed
   during each testing round.
3. Captured raw libinput events with `libinput debug-events --device /dev/input/event14`
   (the `SynPS/2 Synaptics TouchPad`) during a live physical 3-finger swipe. Result: the
   touchpad reported it as a **2-finger `POINTER_SCROLL_FINGER`**, never a
   `GESTURE_SWIPE` — the hardware/driver was misreading finger count, not our config.
4. `journalctl -k -b | grep -i synaptics` showed the kernel's own hint:
   > Your touchpad (PNP: LEN2073 PNP0f13) says it can support a different bus ... you
   > might want to try setting psmouse.synaptics_intertouch to 1
   i.e. this touchpad is running in legacy PS/2 "semi-MT" mode (finger count
   approximated from contact area/shape) instead of true per-finger SMBus/RMI4
   multitouch. Semi-MT's hardest boundary to call is 2-vs-3 fingers; 4-finger gestures
   stayed rock solid the entire session because that threshold is cruder.

## Root cause
**Hardware/firmware limitation, not a NixOS config bug.** The touchpad (Synaptics, fw
10.32, board id 3471) advertises SMBus/RMI4 support but the kernel's `psmouse` driver
cannot complete the intertouch handshake on this exact unit:
```
psmouse serio1: synaptics: Trying to set up SMBus access
psmouse serio1: synaptics: SMbus companion is not ready yet
```

Tried three escalating fixes, in order, each verified with a fresh boot + `journalctl -k
-b | grep -i -E "synaptics|rmi"`:
1. `boot.kernelParams = [ "psmouse.synaptics_intertouch=1" ]` — kernel attempted the
   handshake for the first time, but failed identically.
2. Also force-loading `boot.kernelModules = [ "rmi_core" "rmi_smbus" ]` so the companion
   driver is resident before `psmouse` probes (ruling out a module-load-order race) —
   `lsmod` confirmed both loaded, handshake still failed identically.
3. Lenovo system firmware update via `fwupdmgr` (`0.1.30` → `0.1.35`, required disabling
   the ThinkPad BIOS **Boot Order Lock** setting first — fwupd refused with `BootOrder is
   locked in firmware setup` until that was off) — update applied successfully
   (confirmed via `fwupdmgr get-devices`), but the touchpad's own embedded firmware
   (`fw: 10.32`, same board/fw id) is a separate component the system BIOS update doesn't
   touch, and the handshake failed identically afterward.

All three attempts produced the *exact same* `SMbus companion is not ready yet` failure
— strong evidence this specific touchpad unit cannot complete the handshake at all
(not a timing race, not a stale firmware version), likely requiring either a kernel
source patch or genuinely being unfixable on this hardware revision.

## Decision
Stopped chasing the hardware fix. Reverted all three changes back to baseline
(`boot.kernelParams = [ "pcie_aspm=off" ]`, no `rmi_core`/`rmi_smbus` force-load) — kept
the BIOS update (`0.1.35`) since it's a legitimate, unrelated improvement (security
fixes, Boot Order Lock re-enabled afterward). Living with the touchpad in plain PS/2
mode; 3-finger gesture detection stays occasionally flaky on this host specifically.

## Open question / possible next steps (not pursued)
- Kernel dynamic-debug tracing of `psmouse`/`rmi_smbus` to see exactly where the SMBus
  probe sequence stalls — could reveal whether it's fixable with a kernel patch, but
  effort/uncertainty ratio didn't justify it this session.
- Could swap gesture assignment (4-finger for tab-switch, since that threshold is
  reliable; something else for workspace-switch) as a software-side workaround instead
  of accepting flaky 3-finger — user chose to just live with it for now instead.

## Key diagnostic commands (reusable for future touchpad gesture debugging)
```bash
# Raw gesture frames independent of libinput-gestures' own instance lock:
libinput debug-events --device /dev/input/eventN

# Whether SMBus intertouch negotiated successfully on this boot:
journalctl -k -b | grep -i -E "synaptics|rmi"

# Check/install Lenovo firmware updates:
fwupdmgr get-updates
fwupdmgr update --assume-yes   # requires AC power; may need "Boot Order Lock" disabled in BIOS setup first
```

---

## ADDENDUM 2026-11-22 — the "coin flip" was mostly a SOFTWARE bug, not the touchpad

**Read this before acting on anything above.** The hardware misdetection described in step 3
is real and was directly observed, but this note **overstated how much of the failure it
explains**, because a second, invisible bug was layered on top of it across every reboot.

See `memory/2026-11-22 gesture-tab-switch-hyprland-signature-race.md`. Short version: the
`libinput-gestures` daemon is started by the systemd user manager at login, racing
Hyprland's `systemctl --user import-environment`. When the unit wins, it permanently
inherits an environment with **no `HYPRLAND_INSTANCE_SIGNATURE`**, so `hyprctl` inside
`gesture-tab-switch` printed an error *to stdout and exited 0*, jq choked, the window class
came out empty, and the script hit its unknown-app `exit 0`. A **silent** no-op.

### The evidence that reframes this note

Journal counts on the ThinkPad across all retained boots:

```
successful dispatches ("ok"):      21
detected-but-dropped ("jq error"): 55
```

Every one of those **55 `jq: parse error` lines is a 3-finger swipe the ThinkPad hardware
detected CORRECTLY** — it reached `GESTURE_SWIPE`, libinput-gestures matched the binding,
and the script was invoked. The hardware did its job; the env race then threw the result
away. (Caveat: the two counts aren't a clean ratio — "ok" only appears for swipes in a
tabbed app, while the jq error fires for *every* invocation regardless of focused app. So
treat 55 as "confirmed hardware detections", not as "55 lost tab switches".)

Crucially, **this boot alone: 0 ok, 3 jq errors.** The daemon had been running since
2026-11-19 09:00:55 with no signature, meaning 3-finger tab switch on this host was
**100% dead for ~3.5 days** — not flaky, dead.

### Why this note reached the wrong proportion

The 2026-10-29 session fixed the stale daemon with `systemctl --user restart
libinput-gestures` (step 1), which *also* incidentally repaired the environment — so
3-finger partly worked during that session and the residual flakiness looked like pure
hardware. But the restart doesn't survive a reboot, and the race recurs on every boot, so
afterward the gesture went fully dead again. The reported "worked in Firefox, not Obsidian,
then stopped working back in Firefox" pattern is explained **better by reboots crossing the
race** than by per-swipe hardware chance.

### Corrected conclusion

- Hardware coarse finger-counting on this touchpad **is real** (step 3's `debug-events`
  capture stands: a 3-finger swipe arriving as a 2-finger `POINTER_SCROLL_FINGER`).
- But it is **not** the dominant failure mode, and "close to a coin flip" is not supported.
  The true hardware-only hit rate is **unmeasured** — every prior measurement was taken
  with the env bug also active.
- **Next step is to re-measure, not to re-attempt any hardware fix.** `nrs` on this host to
  pick up the signature-recovery fix, then count `ok` vs failures over normal use.

### Also corrected: the "semi-MT" label

`/sys/class/input/input7/properties` reads `5` = POINTER + BUTTONPAD. The
`INPUT_PROP_SEMI_MT` bit is **not** set, and the device advertises `BTN_TOOL_TRIPLETAP`,
`QUADTAP`, `QUINTTAP` plus real MT slots (`ABS_MT_SLOT`, `MT_POSITION_X/Y`,
`MT_TRACKING_ID`, `MT_PRESSURE`). So the kernel does not classify this as semi-MT. The
mechanism is Synaptics PS/2 advanced-gesture mode tracking only two contact *positions* and
deriving 3+ finger counts from a coarse width field — not a kernel semi-MT mode.

### Better explanation for the identical `SMbus companion is not ready yet` failures

The SMBus adapter here is `i2c_piix4` (`i2c-2: SMBus PIIX4 adapter port 0 at 0b00`).
`psmouse-smbus` only creates the RMI4 companion on an adapter advertising
`I2C_FUNC_SMBUS_HOST_NOTIFY`; Intel's `i2c-i801` has it, AMD's `i2c-piix4` does not. That
would make the failure a **structural platform gap, not a defective touchpad unit** — which
fits "three unrelated fixes, byte-identical failure" far better. Supporting detail: bus 2
carries clients `2-0036`, `2-0037`, `2-0050` and nothing at `0x2c`, the usual RMI4 touchpad
address. NOT verified on-machine (`i2c_dev` isn't loaded). Decisive test, needs root:

```bash
sudo modprobe i2c-dev
nix run nixpkgs#i2c-tools -- i2cdetect -F 2 | grep -i "Host Notify"
```

If that reports no Host Notify, the RMI4/intertouch path is closed permanently and the
"kernel dynamic-debug tracing" open question below can be closed for good.
