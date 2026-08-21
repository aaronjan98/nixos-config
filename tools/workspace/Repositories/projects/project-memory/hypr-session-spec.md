# hypr-session Spec

**Status:** planned — not yet implemented
**Target hosts:** thinkpad-t14, framework-13 (+ external monitors)
**Tool home:** `nixos-config` (Nix-packaged), state per-device

Decided 2026-08-20. A per-domain session save/restore tool for the 2D Hyprland
workspace model, so a reboot no longer means reopening every app and dragging
each back to its workspace.

---

## Problem

After a reboot every app has to be reopened by hand and dragged back to its
workspace. Even apps that restore their own windows don't land in the right
Hyprland workspace, so everything needs re-placing. We want to declare, in an
editable file, which apps belong in which workspace and bring them back on
demand — a whole domain (row) at a time, not all at once.

## Model recap

Workspaces are logical: `domain*10 + slot` (domain 1 is the special case, ws
`1..9`; the external monitor's range is domain 10 → `101..109`). Physical
monitors are bound to ID ranges by existing `workspace = …, monitor:…` rules,
so **targeting a logical workspace is machine-portable** — placement doesn't
care which monitor owns the range on a given host.

A "horizontal workspace" = **a whole domain** (the row of slots 1–9).

## Scope (phased)

- **Phase A — placement** (build first): the right apps launch onto the right
  slot within a domain. Covers ~90% of the pain.
- **Phase B — selective / editable menu** (build first): a file you edit to
  add, remove, or `skip` apps; entries can exist as launchable menu items
  without auto-starting.
- **Phase C — float geometry** (next): floating windows restored to exact size
  and position, stored as percentages so they port across resolutions.
- **Out of scope (for now)** — exact tiled arrangement. Dwindle has no
  serializable tree; we rely on spawn order only and accept "close enough."

## Current-domain detection

Both `save` and `restore` default to the domain you're currently in. It's read
from the focused monitor's active workspace:

```
cur_id = hyprctl activeworkspace -j | .id      # e.g. 21
domain = 1 if cur_id < 10 else cur_id // 10    # 21 -> 2 ; 3 -> 1 ; 104 -> 10
```

A domain's slots all live on one monitor (per the `ws-map` ranges), so "the
current domain" is unambiguous even multi-monitor: it's the domain of whatever
workspace is active on the monitor that has focus. `save` then gathers every
client whose workspace falls in that domain's slot range
(`1..9` for domain 1, else `domain*10+1 .. domain*10+9`) and groups by slot.

## State file

- Path: `~/.local/state/hypr-session/<hostname>.conf` — machine-local (not in
  the synced dotfiles), hostname-keyed so each device keeps a separate session.
- Hand-editable; bootstrapped by `save`, then fine-tuned in `$EDITOR`.

### Format (domain → slot → windows)

Indentation shows membership. Restore acts on a whole domain.

```
# domain 2
domain 2:
    slot 1:                                 # -> workspace 21
        kitty
        firefox            float 60%x70%@center
    slot 2:                                 # -> workspace 22
        obsidian
        slack              skip             # menu item; not auto-launched

# domain 3
domain 3:
    slot 1:                                 # -> workspace 31
        kitty -e btop
```

- A bare line under a slot = launch command (verbatim; `save` seeds it from
  `/proc/<pid>/cmdline`, you edit freely).
- `skip` = keep the entry but don't launch it on restore.
- `float WxH@pos` = launch floating and apply geometry (Phase C). `W`/`H` are
  monitor-relative percentages; `pos` is `center` or `x%,y%`.
- `app=<class>` = the window class, written by `save` only when it isn't obvious
  from the command (used by restore's "already open" check, below). Optional on
  hand-added lines — restore falls back to the command's basename.
- Slot → workspace id uses the standard formula (`domain 1` special-cased).

## Commands

All invocation is from the terminal — no keybind, no picker.

- `hypr-session save` — snapshot the **current domain** (all its slots) and
  **overwrite** that domain's section in the state file from the live state.
  Last write wins: the file and a `save` are both just writers, and the most
  recent one replaces the domain. Re-saving a domain discards prior hand edits
  to it (by design — see decision #2).
- `hypr-session save --all` — overwrite the **whole file** from the live 2D
  grid, still grouped by domain.
- `hypr-session edit` — open the state file in `$EDITOR`.
- `hypr-session restore [domain]` — spawn one domain (row); defaults to the
  current domain. This is the primary verb; restore is per-domain, never
  everything at once.
- `hypr-session restore --all` — spawn every domain (explicit opt-in).

## How save works

1. `hyprctl clients -j` → for each window: class, workspace id, floating flag,
   geometry (`at`, `size`), monitor, pid.
2. Launch command from `/proc/<pid>/cmdline` (a starting point; user edits).
3. Group by domain (`id // 10`, domain-1 special case) → slot (`id % 10`).
4. Float geometry recorded as percentages of that window's monitor.
5. Overwrite that domain's section (or the whole file for `--all`) — last write
   wins, no attempt to merge with prior hand edits (decision #2).

## How restore works

First, snapshot the app classes already open on each target workspace (once, up
front). Then, for the requested (or current) domain, per non-`skip` entry:

1. If that entry's app class was already present on its target workspace in the
   up-front snapshot, **skip** it — don't re-open what you already have
   (decision #1). The class comes from the entry's `app=` value, else the
   command's basename; live classes come from `hyprctl clients`.
2. Otherwise `hyprctl dispatch exec [workspace <id> silent] <cmd>` — places at
   spawn, no focus steal. Duplicates saved on a *fresh* workspace still all
   spawn, because the snapshot is taken before any launches.
3. Phase C only, for `float` entries: subscribe to the Hyprland `openwindow`
   IPC event (socket2), match the new window by class/initialTitle, then apply
   `movewindowpixel exact` / `resizewindowpixel exact` (percent → pixels for
   the actual monitor). Bounded timeout so a slow/never-appearing app can't
   wedge the restore.

## Cross-machine

- **Placement is shared** — logical workspace ids are the same everywhere.
- **Geometry is resolution-dependent** — stored as percentages to stay
  portable; if pixel-exact per-machine tweaks are ever needed, allow a
  per-profile override section keyed on the monitor setup (detected from
  `hyprctl monitors -j`). Not needed for Phase A/B.
- The *tool* ships to every device via Nix; the *state* stays per-device via
  the hostname-keyed path above.

## Packaging & integration

- Packaged with Nix (a small Python program — it juggles `hyprctl -j` JSON,
  `/proc`, and the socket2 event stream) and installed into
  `environment.systemPackages`.
- Self-contained: computes slot↔workspace ids itself, so it does not depend on
  the dotfiles `ws-*` scripts.
- Invoked from the terminal only (decision #3) — no Hyprland keybind, so no
  dotfiles coupling for the tool itself.

## Known sharp edges

- **Window↔entry matching** for geometry is racy (Electron launchers, browser
  session restore, slow starts). The `openwindow` event + class match + timeout
  handles most; imperfect by nature.
- **Reconstructed commands** from `/proc` can be noisy (wrappers, `.desktop`
  Exec) — which is exactly why the file is editable.
- **Domain 10 / external range** (`101–109`) mapping when no external monitor
  is attached is an open implementation detail.
- **Tiled arrangement** drifts with spawn-order timing; consciously not chased.

## Multi-window single-instance apps (Firefox, Obsidian)

hypr-session launches *commands* and places the *windows those commands spawn*.
It cannot open a "tab" — a tab is neither a window nor a process. And it can only
reliably place the **first** window of a single-instance app: the first launch
becomes the process (placeable), but a second launch hands off to the
already-running process, so `[workspace N silent] <relaunch>` doesn't attach and
that window opens on the current workspace. The app's own session-restore makes
it worse by spawning a burst of windows hypr-session never placed. This is the
"click Firefox and every window sprays out, none where I want them" problem.

Two shapes of fix, by app:

- **Firefox → separate profiles + `--no-remote`** (fits Phase A cleanly). A
  distinct profile with `--no-remote` starts a genuinely separate process, so
  `[workspace N silent]` places it, and each profile restores its own session.
  One entry per profile-window:

      slot 3:                     # -> ws 13
          firefox -P work --no-remote --new-window https://a.com https://b.com
      slot 4:                     # -> ws 14
          firefox -P reading --no-remote

  List explicit URLs for deterministic tabs, or let each profile's own restore
  handle it. No windowrules needed.

- **Obsidian → title-based windowrule** (no profile equivalent). Obsidian's
  extra windows are all one process, so relaunching can't place them; route each
  by title instead (Obsidian is `class:electron, title:.*Obsidian.*` here):

      windowrulev2 = workspace 13 silent, class:^(electron)$, title:.*<Vault>.*

  Works for restore-spawned and fuzzel-spawned windows alike, BUT needs stable,
  distinguishable titles. That holds for *different vaults*; it does **not** hold
  for multiple windows of the **same vault** (title varies only by active note).
  Same-vault multi-window is the genuinely hard case — needs the placement-entry
  idea below. (This user almost always works in one vault, so plain relaunch of
  Obsidian will only reliably place one window; the rest need placement-entries.)

Rule of thumb: keep each app's own tab/session memory — that's the feature.
hypr-session's job is placement, not content; disabling an app's restore rarely
helps and usually costs you the tabs.

## Deferred / future enhancements

- **Placement-only entries** — for single-instance multi-window apps that can't
  be split by profile (Obsidian, especially same-vault), let an entry register a
  title/class → workspace rule instead of a launch. On restore, subscribe to the
  `openwindow` IPC event and sweep matching windows to their slot as the app
  restores them (same socket2 machinery as Phase C geometry). This is the only
  robust way to place same-vault Obsidian windows.
- **tmux-session-aware terminal restore** (wanted, but parked). Instead of
  relaunching a bare `kitty`, detect which tmux session each terminal has
  attached and reattach it, e.g. `kitty -e tmux new -As <session>`. The window
  gets its actual working context back, not an empty shell. Capture is the hard
  part: map each terminal window → its pid → the tmux client attached on that
  terminal's tty (`tmux list-clients -F '#{client_tty} #{session_name}'` joined
  against the terminal's controlling tty), then emit the reattach command in
  place of the bare one. Non-trivial matching; deferred, not dropped.
- **cwd restore for plain terminals** — a shell with no tmux loses its working
  directory (`/proc` cmdline has no cwd). Could read `/proc/<pid>/cwd`, but this
  is subsumed by the tmux work above for the common case. Deferred.

## Decisions (2026-08-20)

1. **Duplicates:** open them. Restore launches every saved entry; no class-based
   dedup. `skip` self-restoring apps if they double up.
2. **`save` semantics:** overwrite, last write wins. The file and a `save` are
   equal writers; a re-save replaces the domain rather than merging.
3. **Trigger:** terminal/CLI only. No keybind, no picker.
4. **Terminal state:** bare command only for now; tmux/cwd restore deferred
   (above).

## Build order

1. Phase A + B: `save` / `save --all` / `edit` / `restore [domain]` with
   placement + `skip`, Nix-packaged, invoked from the terminal. Live with it.
2. Phase C: add float-geometry capture and event-driven apply only if the
   missing float positions actually bite.
