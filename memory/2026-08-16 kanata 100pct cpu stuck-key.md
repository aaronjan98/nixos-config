# 2026-08-16 — kanata 100% CPU spin = a stuck key, not a config bug

## Symptom
After a cold boot on the ThinkPad, `kanata-internal.service` was "running" but pegged
one CPU core at ~97–100%, and **home-row mods / remaps didn't work** (keyboard typed
normally, raw, with no kanata layers). Persisted across `systemctl restart` and even a
full power cycle; would only clear once the underlying key state was reset.

## Root cause (the real one)
A **phantom-held key** latched in the *kernel's* key-state bitmap for the internal
keyboard. On startup kanata logs `Init: catching only releases and sending immediately`
and reads the device's currently-held keys via `EVIOCGKEY`. Because a key (here `KEY_4`)
was stuck "down" in the kernel — a make/press scancode arrived at boot but the matching
break/release was dropped (classic i8042/atkbd glitch; in this case the rag used to
"clean" the keys likely held one down during boot) — kanata **busy-polls `EVIOCGKEY`
forever** waiting for a release that never comes. Hence 100% CPU and no remaps.

The state lives in the kernel, not kanata, so restarting kanata re-reads the same stuck
key and spins again.

## The diagnostic signature (how to nail it fast next time)
1. Confirm it's an internal spin, not real key events: keyboard IRQs are **flat**
   while CPU is pegged — `grep i8042 /proc/interrupts` twice, counts don't move.
2. Confirm the thread is busy, not sleeping: `/proc/<pid>/status` shows `State: R`,
   `wchan: 0`, ~0 voluntary context switches. A *healthy* kanata loop sleeps ~86% of
   the time (jtroo/kanata discussion #541).
3. Find the stuck key directly from kanata:
   ```
   PID=$(pgrep -x kanata)
   sudo timeout 1 strace -p "$PID" 2>&1 | grep -o 'EVIOCGKEY([0-9]*), \[[^]]*\]' | sort | uniq -c
   ```
   Output like `EVIOCGKEY(96), [KEY_4]` names the latched key.

## The fix
Deliver the missing release so the kernel clears the latch, then restart:
```
sudo systemctl stop kanata-internal     # release the grab so the press reaches the kernel
# firmly PRESS AND RELEASE the named key (e.g. 4) a few times
sudo systemctl start kanata-internal
ps -o pcpu,cmd -C kanata                 # want ~0%
```
NOTE: you must actually tap the key *while the service is stopped*. A quick stop→start
with no keypress in between does nothing — the latch is still there.

## Red herrings ruled out (don't rechase these)
- **NOT the device grab.** kanata was also grabbing "ThinkPad Extra Buttons" (event13)
  because a raw `configFile` makes the NixOS module's `devices=` option inert. We pinned
  `linux-dev /dev/input/by-path/platform-i8042-serio-0-event-kbd` in each host's defcfg
  (commit this session) — good hygiene, kanata now owns only event0 — but it did **not**
  fix the spin. The spin reproduced with only event0 grabbed.
- **NOT the AltGr / foreign-language work** (73f1a22). That only changed keymap aliases
  (`l` home-row mod ralt→lalt); the defcfg/device handling predates it, unchanged since
  the initial commit.
- **NOT a kanata version bump.** Same `kanata-1.9.0` store path across gens 318–322.

## If it recurs
Repeated stuck-`4` across clean cold boots ⇒ suspect a mechanically sticky `4` keycap or
debris, and fix it physically (reseat/clean under the keycap) — not in the Nix config.

## Related
- Framework `kanata-internal.kbd` got the same `linux-dev` pin, but its device path is
  UNVERIFIED — run `ls -l /dev/input/by-path/ | grep -i kbd` on the Framework before
  trusting it, or kanata will find no device there.
- See [[2026-08-01 keyboard accents emoji and host-scaled dotfiles]] for the AltGr setup.
