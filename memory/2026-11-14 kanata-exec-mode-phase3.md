# 2026-11-14 — Kanata exec mode (Phase 3): deployment, daemon bugs, key map

nixos-config side of a feature that spans two repos: Quickshell/`~/.config` (dotfiles
bare repo, branch `kanata-lang-island`) owns the UI/daemon-relay/data-table pieces;
this repo owns the `.kbd` layer definitions, the TCP-bridge daemon script, and
`docs/ROADMAP.md`'s tracking entry. Full Quickshell-side session note:
`~/.config/quickshell/memory/2026-11-14 kanata-exec-mode-phase3.md`. Clean architecture
reference (both sides): `~/.config/quickshell/rices/limerence/docs/kanata-island.md`.

## What changed in this repo

- `scripts/kanata-ctl-daemon.py` — added a `MessagePush` branch to `handle_message()`,
  relaying `{"execMsg": <value>}` as a one-off event line (not folded into the periodic
  state snapshot, since it has none of that shape's fields).
- `hosts/thinkpad-t14/kanata/kanata-internal.kbd` and
  `hosts/framework-13/kanata/kanata-internal.kbd` (kept byte-identical outside the
  per-host `defcfg` device-matching block) — added the physical left Super key to
  `defsrc` (previously absent entirely, so it passed through kanata untouched), a
  `lmet_exec` tap-hold alias (tap → `layer-switch execlayer`, hold → passthrough `lmet`,
  bound only in `default`), 15 `ex*` push-msg aliases, a shared `exExit` fallback, and a
  new `(deflayer execlayer ...)` block covering all 43 `defsrc` positions.
- `docs/ROADMAP.md` — rewrote the "Kanata: TCP server, launcher layer, and multi-profile
  support" entry's Phase 2/3 section from open questions to resolved decisions + the final
  key map + deployment notes.
- `MEMORY.md` — added a durable-knowledge section pointing here and to the clean doc,
  capturing the two generalizable Quickshell-daemon gotchas (see below).

## Deployment

User ran `nixos-rebuild switch` + restarted `kanata-internal` themselves (per this repo's
own convention: agents prepare the fix, the user runs `nrs` so they see the live build
output). Verified deployed by querying kanata's TCP control socket directly
(`{"RequestLayerNames":{}}` → confirmed `execlayer` in the response) before asking the
user to test with real keypresses.

## Key lessons (generalizable beyond kanata)

### 1. A Quickshell `Process{running:true}` does not auto-respawn if killed externally
Killed the daemon's PID directly (to force it to pick up a script edit) expecting
Quickshell to relaunch it — it didn't. `ps`/`ss` confirmed nothing restarted the process;
had to fully restart the whole Quickshell process (`pkill` + relaunch) to get the daemon
running again. Quickshell's `CONTEXT.md` documents a lighter `qs -r` reload command that
wasn't tried first — worth checking project docs for an existing reload mechanism before
improvising a manual kill, even under time pressure mid-debug.

### 2. QML live-reload does not restart an already-running `Process` child, and Python doesn't hot-reload either
Edited `kanata-ctl-daemon.py` to add the `MessagePush` relay, but the already-running
daemon process (started before the edit) kept executing the OLD in-memory code for
several subsequent edits and reloads — confirmed by a raw TCP watch showing kanata
correctly sending `MessagePush`, with nothing downstream reacting, then adding a temp
debug trace directly in `KanataCtl.qml` to see exactly what it resolved. Editing the
owning `.qml` file visibly triggers Quickshell's "Reloading configuration..." cycle, but
that cycle does not tear down and respawn a `Process` element that's already running —
only a fresh process start (not just a fresh `.qml` parse) picks up a script-side change.

### 3. `kanata --check` and a direct TCP probe are cheap, fast ground-truth checks — use them before trusting the UI
Validated every `.kbd` edit with `kanata --check -c <file>` before considering it done
(catches syntax mistakes before a `nixos-rebuild switch` + keyboard-remapper restart,
which is a much more expensive place to find one), and connected directly to kanata's
TCP socket with a scratch Python script to watch raw `LayerChange`/`MessagePush` traffic
during real keypresses — this isolated "did kanata even send the right thing" from "did
the daemon/Quickshell chain handle it correctly," which was essential once both a
stale-daemon bug and a separate (likely pre-existing, Obsidian-side) REST API quirk were
both plausible explanations for the same symptom at the same time.

## Open items

- `t` (tiktok) and `l` (links.home) were added to the key map after the initial deploy
  and need one more `nixos-rebuild switch` + `kanata-internal` restart on each host before
  they're live — not yet done as of this note.
- Framework-13 has never actually been deployed/tested with ANY of this (`execlayer`
  didn't exist before today); only confirmed byte-identical to the ThinkPad's file and
  `kanata --check`-valid. Real-keypress confirmation on that host is still outstanding.
