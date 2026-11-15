# 2026-11-15 — Kanata exec mode: q/k remap, and how we proved it wasn't broken

## What was worked on

Continuation of [[2026-11-14 kanata-exec-mode-phase3]]. User asked to change the
exec-layer (one-shot Super-tap launcher) mapping:

- `q`: was `exKitty` → now `exTorrent` (push-msg "torrent")
- `k`: was unmapped (`@exExit`) → now `exKitty` (push-msg "kitty")

Changes made in both `hosts/thinkpad-t14/kanata/kanata-internal.kbd` and
`hosts/framework-13/kanata/kanata-internal.kbd`:
- added `exTorrent (multi (push-msg "torrent") (layer-switch default))` alongside
  the existing `exKitty` alias
- row3 (q...p) slot 1: `@exKitty` → `@exTorrent`
- row4 (a...apos) slot 8: `@exExit` → `@exKitty`
- `~/.config/quickshell/exec.json` (dotfiles repo) got a new `"torrent": ["firefox", "http://torrent.home"]` entry

Validated both `.kbd` files with `kanata --check -c <file>` before deploying.
Deployed on thinkpad-t14 via `nixos-rebuild switch` (user ran the sudo command
manually since this session's shell has no sudo password prompt) — this
auto-restarted `kanata-internal.service` as part of activation; no manual
`systemctl restart` was needed.

## Key insight: debugging a "broken" key that wasn't actually broken

User reported `q` "wasn't working" (no torrent launch), and recalled `q` never
really worked even when it was bound to kitty. Two wrong hypotheses explored
and discarded, in order:

1. **Hyprland native-bind collision theory**: `~/.config/hypr/conf.d/20-binds.conf`
   has `bind = $mainMod, Q, exec, $terminal` (classic Super+Q → terminal) and
   `bind = $mainMod SHIFT, Q, exit` (quits Hyprland!). Reasoned that `tap-hold-press`
   on `lmet_exec` resolves early to HOLD the instant another key is *pressed*
   while Super is still down, so a reflexive "hold Super, hit Q" gesture (from
   long-standing Super+Q-for-terminal muscle memory) would leak a real Super+Q
   to Hyprland instead of entering the kanata layer. **Discarded** when the user
   said they triggered Exec mode via the Quickshell UI's mouse click (which calls
   `KanataCtl.setLayer()` → a real TCP `ChangeLayer` command, no physical-key
   gesture involved at all) and `q` still did nothing.

2. **nc TCP tap**: opened a raw `nc 127.0.0.1 7979` tap to watch kanata's broadcast
   protocol live. Got misled — the single `{"LayerChange":{"new":"default"}}` event
   each tap produced was just kanata's **connection handshake** message ("new client
   connection, sending initial LayerChange event to inform them of current layer"),
   not a live user keypress. Looked like "q produces nothing but an exit" when it
   was actually just an artifact of when the nc client happened to connect.

**What actually worked**: `kanata-internal.service`'s systemd unit already runs
with `--debug`, so `journalctl -u kanata-internal -f` (or `--since`) gives full
ground truth — every physical key event, every `Action push-msg` with its exact
message payload, and every `[INFO] Entered layer:` block. This is a far more
reliable diagnostic than a hand-rolled TCP tap, since it doesn't have a
connect-time handshake message to misinterpret, and it is RUST's own account of
what the key event state machine actually did (not Quickshell's or Hyprland's).

Grepping the journal proved: the real physical Super tap *did* correctly enter
`execlayer`, and `q` *did* correctly fire `Action push-msg message: ["torrent"]`
and return to `default` — every single time it was tested with a genuine
physical Super-key tap. (Some of the user's earlier failed attempts, found in
the same journal grep, turned out to be holding the **`d`** key instead — `d`'s
home-row-mod hold-action also outputs a literal `lmet` keycode (see `dmet` alias),
which produces a real Super modifier to the OS but does **not** call
`layer-switch execlayer` — only the dedicated physical left-Super key
(`@lmet_exec`) does that. Holding `d` + pressing `q` is indistinguishable from a
genuine Super+Q hold from the user's seat, but kanata correctly treats it as a
different gesture — this is a real way to "miss" entering the exec layer, just
not the one in play for the UI-mouse-click test.)

Added a temporary debug trace to `KanataCtl.qml`'s `runExec()` (same technique as
the earlier Obsidian bug) to confirm the chain beyond kanata itself. It logged
`name=torrent argv=["firefox","http://torrent.home"]` — confirming the daemon
relay, the `exec.json` lookup, and the `Quickshell.execDetached()` call were all
correct. (Trace was removed after confirming — no net diff left in `KanataCtl.qml`.)

**The actual "bug"**: none, in kanata/Quickshell. `firefox http://torrent.home`
really did launch — just as a **background tab** (not focused, easy to miss) —
and the page itself came back **404 Not Found**. `torrent.home` isn't serving
anything at its root path; whatever torrent client is behind it (via Caddy) needs
the correct sub-path/port in the exec.json URL. This is a service-config issue,
not a kanata-island issue.

## Decisions

- Kept the native Hyprland `Super+Q`→terminal and `Super+Shift+Q`→exit binds
  untouched; the exec-layer `q` now correctly coexists with them (confirmed via
  journal, not just believed).

## Open questions / next steps

- `~/.config/quickshell/rices/limerence/docs/kanata-island.md`'s key-map table is
  now stale (still shows `q`→kitty, no `k` entry) — wasn't updated this session
  since it wasn't explicitly asked for. Update it next time docs are touched.
- Need the real path/port for whatever's behind `torrent.home` (torrent client
  WebUI) to fix the `exec.json` URL itself — e.g. likely needs a sub-path like
  `/transmission/web/` depending on what's reverse-proxied there. Not yet
  investigated this session.
- `~/nixos-config` has unrelated pre-existing staged changes to
  `tools/workspace/Repositories/projects/CONTEXT.md` and `repos.tsv` from a
  different, earlier task — intentionally left out of this session's commit.
