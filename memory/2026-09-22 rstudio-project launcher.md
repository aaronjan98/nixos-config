# RStudio "New Session" Fix + Project Picker Launcher

Date: 2026-09-22

## Problem
RStudio's `File → Open Project In New Session` opened a blank generic Electron
window (atom logo, Chromium/Node/V8 version page) on the workspace grid instead of
a new RStudio session. User wanted two isolated RStudio sessions side by side (one
per project), mirroring the Obsidian multi-window setup.

## Root cause
RStudio 2026.04.0 on NixOS runs as single-instance Electron:
`electron <rstudio-app-resources-path>` (main pid launched with the app path).
Its built-in new-session relaunch invokes the **bare `electron` binary WITHOUT the
RStudio app-resources path** (`--user-data-dir=/home/aj/.config/Electron`, no app
arg), so Electron comes up with nothing loaded — its default welcome window. This
is a nixpkgs `rstudioWrapper` packaging limitation: on a normal install the RStudio
binary *is* the self-contained electron app and re-execing itself works; on Nix the
relaunch doesn't reconstruct the app-path argument.

The `Invalid json-rpc request` spam in `rsession-aj.log` (GwtLogHandler.cpp) is
unrelated benign log noise, not the cause.

## Fix / mechanism (verified live)
The reliable way to get an isolated second session is to invoke the `rstudio`
wrapper directly with a project file:

    rstudio /path/to/project.Rproj

Verified: this launches `electron <app> <project.Rproj>` which spawns its **own**
`rsession` on its **own** port (main on 20946, second on 14318, distinct launcher
tokens) — two genuine isolated sessions. Confirmed via hyprctl: `hw1 - RStudio` and
`case-study-a - RStudio` windows both open at once. hyprctl attributes windows to
renderer/helper subprocess pids, not the main electron pid — don't be fooled by the
pid "shifting" between snapshots; the main electron process stays alive (checked ps).

## What was built
- `modules/rstudio-project.nix` (NEW) — `writeShellScriptBin "rstudio-project"`: a
  fuzzel `--dmenu` picker of `*.Rproj` files found under `~/Documents` and
  `~/Repositories` (prunes `.git`/`node_modules`/`.direnv`), launching the chosen
  one detached via `setsid rstudio "$target"`. Ships a `makeDesktopItem`
  "RStudio (Project Picker)" so fuzzel's app launcher lists it — mirrors
  `obsidian-ipc.nix`'s "Obsidian (Spawn Window)" pattern.
- `hosts/common/default.nix` — imported the module right after `obsidian-ipc.nix`.

## Key decision — font scaling via `fz`
First version called raw `fuzzel --dmenu`, which rendered **oversized**: this host
is `nixos` (the ThinkPad, `*)` fallback in `~/.config/hypr/scripts/fz` → font=11),
but `~/.config/fuzzel/fuzzel.ini` is tuned for the Framework 13's HiDPI panel
(size=20). Same trap already hit + documented for cliphist (2026-09-19 note).
Fix: route the picker through `~/.config/hypr/scripts/fz` (the host-scaled wrapper
used by `$menu`, the emoji picker, accent-pick, cliphist), with a raw-`fuzzel`
fallback if `fz` is ever missing. `fz` is the single source of truth for per-host
fuzzel sizing — always route new fuzzel callers through it, never call `fuzzel` raw.

## Project discovery behaviour (answered for user)
The `.Rproj` file is the filter — only actual RStudio Projects appear, so plain
class folders with only `.R`/notes don't clutter the list. Any future `.Rproj`
anywhere under `~/Documents` or `~/Repositories` shows up automatically, labelled
by its project-folder name (parent-dir appended on name collisions). Roots left
broad intentionally: extra roots cost scan time, not list noise, thanks to the
`.Rproj` gate. Narrowing to `~/Documents/School` + repos is a one-line `roots=(...)`
change if wanted.

## Next steps / open
- User needs to `sudo nixos-rebuild switch` to activate the launcher + font fix
  (he runs builds himself). Until then, `rstudio <proj>.Rproj &` works directly.
- Stray bare `electron`/"Electron" windows from earlier broken "New Session" clicks
  are harmless — safe to close.
- Stop using `File → Open Project In New Session` (broken path).
- Two `.Rproj` files exist so far: MATH-444 `hw1` and `case-study-a`.
- Optional upstream: report the rstudioWrapper multi-session relaunch to nixpkgs.
