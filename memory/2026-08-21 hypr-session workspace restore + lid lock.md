# 2026-08-21 — hypr-session (2D workspace restore) + lid lock-before-suspend

Two features landed this session, on branch `hypr-session` (merged to main).

## 1. hypr(thinkpad): lock before suspend on lid, not on wake
Closing the lid let logind suspend while hyprlock was still coming up, so it
stalled during the panel-off transition, lost the session lock, and dropped to
the "lockscreen app died" screen. hyprlock only locks reliably while the
compositor is fully awake.

Fix: `hosts/thinkpad-t14/configuration.nix` sets `HandleLidSwitch/ExternalPower/
Docked = ignore` so logind no longer suspends on lid, plus a `lock-and-suspend`
script that locks while awake, waits for hyprlock, then `systemctl suspend`. The
Hyprland lid bind (`bindl = , switch:on:Lid Switch, exec, lock-and-suspend`) is
in the dotfiles (`.config/hypr/conf.d/20-binds.conf`, tracked via the `dot`
bare-repo alias — NOT nixos-config). `modules/hypr-idle-lock.nix` uses a static
lock background + `InhibitDelayMaxSec=20s`. Commit `a3fff94` (nixos) / `281fd22`
(dotfiles). Verified at reboot.

## 2. hypr-session — per-domain 2D workspace save/restore
`tools/scripts/hypr-session.py`, packaged `tools/pkgs/hypr-session.nix`, wired
into `hosts/common/default.nix` via `nix-tools.packages.<system>.hypr-session`.
State: `~/.local/state/hypr-session/<hostname>.conf` (machine-local, editable).
User docs: `docs/SCRIPTS.md`. Design spec: `projects/project-memory/
hypr-session-spec.md`.

Commands: `save` / `save --all` / `edit` / `restore [domain]` / `restore --all`
/ `restore --dry-run`. Workflow: `save --all` right before reboot, `restore
--all` after.

### Key design facts (hard-won)
- **Workspace model**: domain = `id//10` (domain 1 = ws 1–9), slot = `id%10`.
  These are the REAL hyprctl ids; the tool matches them.
- **Single-instance apps can't be placed by relaunching** — `[workspace N
  silent] cmd` only places the *first* window. So:
  - **Firefox / Obsidian** → `restore=` identity-match: the app restores its own
    tabs (Firefox "open previous windows", Obsidian workspace.json), and the tool
    matches each window to a workspace by its **active tab/note** (from the
    window title) and `movetoworkspacesilent`s it. Not order-based.
  - **Terminals (ghostty, also single-instance)** → `move=` spawn-and-move: tmux
    `set-titles-string '#S'` (`modules/tmux.nix`) makes the window title = tmux
    session name, so save writes `ghostty -e tmux new -As <session> move=…`;
    restore spawns it (reattaches; continuum restored the content) and moves it.
  - **Native single-window apps** → direct `[workspace N silent] cmd`.
- **Dedup**: restore snapshots what's already open per workspace up front and
  skips those, so re-running is safe and fresh-workspace duplicates still spawn.
- Obsidian: no Advanced URI plugin, but the **Local REST API** wrapper
  (`modules/obsidian-ipc.nix` → `obsidian-remote new-window`) creates placeable
  windows; that's what `move=obsidian` (blank alternative) uses.

### Caveats / gotchas
- Firefox/Obsidian match on **active tab/note** → save right before reboot,
  don't change the active tab afterward or the window won't match.
- Terminal cold-start: first `tmux new -As` starts the server and triggers
  continuum restore; there's a race where it could attach an empty session.
  Workaround: let tmux/continuum restore first (open one terminal) before
  `restore --all`. A "start server + wait for continuum" pre-step is a possible
  follow-up if the reboot test shows it.
- ghostty won't close via `hyprctl closewindow`/`killactive` (confirm-close
  prompt); must click the button.
- `/proc` cmdline for wrapped Electron apps is the raw `.../electron .../app.asar`
  (not runnable) — `launch_command` prefers a clean PATH binary named after the
  class.

### Not done (future)
- Phase C: float-window geometry restore (percent → pixels via `openwindow`).
- Reattaching an *existing* terminal on the wrong session (needs keystroke
  injection) — restore just spawns the right ones + dedups.

### Infra note
The design spec is authored in the CANONICAL `~/Repositories/projects/
project-memory/hypr-session-spec.md`; the `export-workspace-state.timer` mirrors
it into `tools/workspace/Repositories/...` in nixos-config. Writing only to the
mirror gets clobbered by the hourly export. The dotfiles live in the `~/.dotfiles`
bare repo (`dot` alias); run `dot` from `$HOME`, not a subdir, or pathspecs
silently match nothing.
