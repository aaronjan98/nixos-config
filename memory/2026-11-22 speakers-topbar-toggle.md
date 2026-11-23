# 2026-11-22 — QS_SPEAKERS capability flag for the topbar speaker toggle

Short nixos-config-side note; the full story lives in the quickshell dotfiles
memory note of the same name (`~/.config/quickshell/memory/`), since nearly all
the work was QML.

## What was worked on

`hosts/framework-13/configuration.nix` — added `QS_SPEAKERS = "1"` to
`environment.sessionVariables`, next to `QS_UI_SCALE`. Quickshell reads it via
`Quickshell.env()` and renders a speaker on/off icon in the topbar that drives
`scripts/speakers.sh` (the existing HA-REST wrapper for the Kasa KP125M), so the
amp no longer needs `speakers toggle` typed in a terminal.

## Key decision

It's a **capability flag, not a hostname check**. The speakers hang off whichever
machine sits at the desk; if they move, set the var on that host and the icon
follows. Same per-host env-var pattern `QS_UI_SCALE` already established — that
pattern is now carrying two kinds of information (DPI tuning and hardware
presence), which seems fine but is worth watching if a third joins.

The QML side polls `speakers.sh status` rather than tracking its own clicks,
precisely because this repo cuts the speakers behind the UI's back in three
places: `modules/speakers-suspend-off.nix` (pre-suspend) and
`aj.hyprIdle.extraBlackoutCmd` / `inputCutoffCmd` on this host.

## Verified

`nix-instantiate --parse` and `nixos-rebuild dry-build --flake .#framework-13`
both clean. Toggled the speakers off and back on through the new IPC handler
(`qs ipc call speakers toggle`) and confirmed against `speakers.sh status`.

## Next steps

- Not yet activated: needs `sudo nixos-rebuild switch --flake .#framework-13`
  and a relogin. `environment.sessionVariables` applies at login only, and
  Hyprland launches qs through `sh -lc`, so it inherits from there. Until then
  the icon only exists in the hand-launched qs process from this session.
- `docs/SCRIPTS.md` still has no `speakers.sh` entry (pre-existing gap).
