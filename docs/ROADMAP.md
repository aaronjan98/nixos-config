# ROADMAP.md

This file tracks deferred fixes, design ideas, and future feature work for this NixOS configuration and its operational tooling.

---

## Ongoing issues

### Hypridle blackout → suspend may restore zero brightness
Status: suspected

Problem:
- if the machine suspends while the 5-minute blackout is already active, `before_sleep_cmd` may overwrite the saved brightness state with zero values
- that could restore to a black screen / zero keyboard brightness on wake

What was learned:
- this is an edge case noted during the hypridle brightness fix work
- it has not been confirmed as a real recurring bug yet
- the current implementation intentionally skipped extra idempotency guards

Current decision:
- leave the current logic in place unless the edge case is reproduced or becomes annoying enough to justify extra code

---

## Future features

### NixOS specialisations / alternative system profiles
Goal:
- figure out whether named NixOS specialisations fit the daily workflow and are worth maintaining

Why this is interesting:
- `nixos-rebuild list-generations` already exposes the `Specialisation` field, but the current setup does not use it
- specialisations could support alternative profiles such as battery-saving, work, AI-heavy, gaming, or minimal modes

Open questions:
- which profiles are actually worth the maintenance cost
- how much should differ between the base system and a specialisation
- whether switching should happen mainly at boot, at runtime, or both
- how service and dotfiles behavior should integrate with profile changes

### `scripts/backup-secrets.sh`
Goal:
- implement the inverse of `restore-secrets.sh` so SSH material can be backed up into `pass`

Current shape:
- the script should read files from `~/.ssh/`
- it should write them into `pass` under `laptop/<hostname>/ssh/<filename>`

Open questions:
- scope: back up all of `~/.ssh/`, or only the fixed list used by `restore-secrets.sh`
- overwrite behavior: overwrite, skip, or prompt
- hostname: derive from `$(hostname)` or accept an argument
- auto-push: run `pass git push` automatically or leave it manual

References:
- `CONTEXT.md`
- `docs/SCRIPTS.md`

### Live runtime theme switcher
Goal:
- add a live theme switcher that works without a NixOS rebuild

Current decision:
- do **not** use Stylix for this workflow, because rebuild-based theme switching is the wrong fit
- preferred direction is `matugen` + generated per-theme configs + symlink switching + targeted reloads

Why it belongs here:
- this is a cross-cutting desktop feature that affects Quickshell, terminals, and other app themes

### Qylock / Quickshell lockscreen path
Goal:
- revisit the lockscreen implementation if the higher-fidelity QML animation path becomes worth the complexity

Current state:
- `hyprlock` is working now and remains the active solution
- the exact visual direction researched earlier would require moving to a `quickshell` / `qylock`-based lockscreen

Why it is deferred:
- it would be a meaningful architectural shift rather than a small tweak

---

## Candidate improvements

### Automatic Nix garbage collection
- current decision is to keep garbage collection manual for now
- if manual cleanup becomes annoying, later revisit enabling scheduled GC in the NixOS config

---

## How to use this file

- add deferred issues that are known but intentionally not fixed yet
- add feature ideas that should survive beyond a single chat session
- move stable architectural decisions into `MEMORY.md`
- keep day-specific implementation details in `memory/YYYY-MM-DD.md`
- keep script-specific design constraints in `CONTEXT.md` or the most relevant focused doc when appropriate
