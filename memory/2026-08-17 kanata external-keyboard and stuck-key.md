# 2026-08-17 — kanata: stuck-key CPU spin + Framework external keyboard

Session spanned ThinkPad (where work was done) and Framework (verified/deployed over
Tailscale SSH as `framework-13`, 100.82.211.39).

## What was worked on
1. Diagnosed why kanata "didn't start right" on the ThinkPad after a reboot.
2. Added `linux-dev` device restriction to both hosts' `defcfg`.
3. Extended the Framework to remap its external SONiX USB keyboard too.
4. Reconciled a GitHub (`hub`) push divergence.
5. Documented deploy/ops caveats in `docs/KANATA.md`.

## Key insights / findings
- **The 100% CPU spin was a stuck key, not config.** kanata busy-polls `EVIOCGKEY`
  waiting for the release of a phantom-held key (`KEY_4`) latched in the *kernel* at
  boot. IRQs were flat (no real events); main thread `State: R`, never sleeping. Full
  reference: `2026-08-16 kanata 100pct cpu stuck-key.md`. Cleared by stopping the
  service and physically tapping `4`. (Rag-cleaning the keyboard likely re-latched a
  key on a later boot — pressing keys with a rag generates presses.)
- **Ruled out (don't rechase):** the "ThinkPad Extra Buttons" device grab, the AltGr
  keymap change (73f1a22), and a kanata version bump (same 1.9.0 store hash across
  gens 318–322). The device-grab defect predates everything (initial commit).
- **`services.kanata...devices` is inert** when a host supplies a raw `configFile` —
  the module only applies `devices` when it generates the config. Restriction must
  live in `defcfg`.
- **`nrs` does NOT restart kanata** when only the `.kbd` contents change (no
  `restartTrigger` on the etc file). First Framework `nrs` deployed the file but the
  live process kept the old grab-all config until a reboot. Confirm with
  `journalctl -u kanata-internal -b | grep registering`.
- **Framework external keyboard works** via `linux-dev-names-include` matching
  `"AT Translated Set 2 keyboard"` + `"SONiX USB DEVICE"` (exact match; only honored
  when `linux-dev` omitted). The SONiX is a composite device; live keystrokes come
  through its boot-keyboard interface (event node named exactly `SONiX USB DEVICE`,
  the one with the `leds` handler). The separate `SONiX USB DEVICE Keyboard` interface
  is NOT grabbed and turned out not to be the live one — user confirmed remaps work
  with no doubling.

## Decisions
- Keep the `linux-dev` pins (good hygiene) even though they didn't cause/fix the spin;
  corrected the misleading comments that had blamed the device grab.
- Framework uses name-based matching (robust across USB ports); ThinkPad stays by-path.
- Chose NOT to add a `restartTrigger` — a manual restart avoids kanata dropping the
  keyboard grab mid-rebuild. Documented the manual step instead.
- Merged `hub/main` (had out-of-band commit `c3ae134 sync-arrive`) rather than rebase,
  since `home`/`local` already had our commits; pushed merge to all three → `a1a7690`.

## State at session end
- ThinkPad: kanata healthy after clearing the stuck `4`.
- Framework: rebooted, kanata CPU 0%, both keyboards grabbed + remapping confirmed.
- Commits: `00de95e` (pins + stuck-key memory), `945473c` (Framework external kbd),
  `a1a7690` (merge), `c60b1f3` (docs). First three pushed to home/hub/local.

## Open / next steps
- **`c60b1f3` (docs/KANATA.md ops section) is committed but NOT pushed** — user will
  push it themselves (`g pushall`). Fetch `hub` first in case of another out-of-band
  commit.
- If the stuck-`4` recurs on clean cold boots → suspect a mechanically sticky `4`
  keycap / debris, fix physically (not in Nix).

## Related
- [[2026-08-16 kanata 100pct cpu stuck-key]] — full technical diagnosis + recipe.
- [[2026-08-01 keyboard accents emoji and host-scaled dotfiles]] — the AltGr setup.
