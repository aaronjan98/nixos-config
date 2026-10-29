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
