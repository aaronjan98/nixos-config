# OBS quickshell control popup — session notes (2026-11-13)

## What was worked on
Built a full OBS Studio control widget for the quickshell top bar (icon +
popup, same scrim/PanelWindow pattern as Wifi/Bluetooth/Clipboard), then
debugged it through several rounds based on live testing and user feedback.

1. **Initial build**: `ObsIcon.qml`, `ObsPopup.qml`, `ObsCtl.qml` singleton
   (dot repo), backed by a new `nixos-config/scripts/obs-ctl-daemon.py`.
   Rejected both nixpkgs CLI options first: `obs-cli` is built on goobs
   v0.8.0, which only speaks the old v4 wire protocol (confirmed from its
   actual generated source — OBS 28+'s bundled obs-websocket is v5-only,
   so it can't even complete the handshake). `obs-cmd` (Rust/obws v0.14)
   speaks v5 correctly but has no scene-listing command and prints Rust
   Debug-formatted text. Daemon instead speaks the raw v5 JSON protocol
   directly over a websocket — full auth handshake (salted SHA256 challenge,
   confirmed working against real OBS), live event-driven state push
   (RecordStateChanged, InputMuteStateChanged, etc.), not polling-based.
   Verified live against real OBS: auth, recording start/pause/resume/stop,
   mic mute toggle, scene detection all confirmed working.
2. **A later continuation of this session (before this context) simplified
   the popup** from what was first built — dropped streaming/vcam/replay/
   volume-slider controls in favor of a tighter "Recording + Preset scenes
   (Screen / Screen+Camera / Camera Only) + Mic/Desktop mute" panel, and
   added a Hyprland special-workspace ("special:obs") mechanism
   (`~/.config/hypr/scripts/obs-toggle`) so the real OBS window can be
   opened/hidden like a scratchpad app, driven from the popup's
   Launch/Open/Hide OBS buttons.
3. **Bug: icon click did the wrong thing.** `TopBar.qml` had the icon's
   plain click wired to `toggleWindow()` (minimize/maximize the real app)
   and right-click wired to `toggle()` (the popup) — backwards from every
   other bar icon. Swapped them.
4. **Bug: hiding OBS made it sticky on every workspace.** Hyprland
   auto-reveals a special workspace as a side effect of *any* `focuswindow`
   dispatch targeting a window living inside it — confirmed directly (a
   bare `focuswindow` on a hidden OBS popped the whole overlay back up).
   This includes Hyprland's own implicit focus-restore when the quickshell
   popup's `WlrKeyboardFocus.OnDemand` layer closes: if OBS was the
   last-focused real window, closing the popup handed focus back to it and
   silently re-revealed the special workspace everywhere. Fixed by
   redirecting focus away from OBS at the end of `hide_obs()`, plus an
   explicit "force-close if still shown" check.
5. **Bug: that fix jumped the user's workspace to 1 on every hide.** The
   redirect target was picked by sorting *all* windows globally by
   `focusHistoryID`, and `focuswindow` always switches the active workspace
   to match its target — so it kept landing on whatever window had been
   interacted with most recently system-wide (this Claude/terminal session,
   workspace 1), yanking the user there regardless of where they actually
   were. Fixed by scoping the redirect search to windows already on the
   *current* workspace only, and gating the whole redirect on OBS actually
   being the focused window to begin with (otherwise skip it entirely —
   no reason to steal focus from something unrelated).
6. **Also simplified** OBS window detection: dropped a fragile
   title-substring fallback (`"OBS Studio"` anywhere in a window's title —
   a browser tab titled "How to Use OBS Studio — Tutorial" would misfire)
   in favor of matching on wm class (`com.obsproject.Studio`) alone.
7. **Bug: recording timecode frozen at 0 in the popup.** OBS doesn't push a
   per-second "timecode advanced" event over obs-websocket —
   `RecordStateChanged` only fires on start/stop/pause/resume, so the
   popup displayed whatever `outputTimecode` was at connect time forever.
   Added a 1s poller in the daemon that re-fetches `GetRecordStatus`, but
   only while a recording is active or paused (silent otherwise). Verified
   live: ticked `00:00:01` → `00:00:23`, matching OBS's own counter.

## Key insights
- **Hyprland special workspaces auto-reveal on any `focuswindow` targeting
  a window inside them** — this isn't limited to explicit
  `togglespecialworkspace` calls. Any focus-restore path (including
  Hyprland's own internal one when another surface releases keyboard
  focus) can trigger it. If you ever hide something into a special
  workspace, you must defensively redirect focus away from it at the same
  time, not just trust that nothing will refocus it later.
- **`hyprctl dispatch focuswindow` always switches the active workspace to
  match its target.** Any "pick a window to refocus" logic needs to search
  within the current workspace only, never globally, or it becomes an
  unwanted workspace-switch side effect.
- `hyprctl monitors -j`'s `.specialWorkspace` field is a reliable *live*
  "is this special workspace currently shown" indicator (confirmed via
  direct before/after testing) — not a sticky "last assigned" field as
  first suspected.
- obs-websocket v5's event stream doesn't cover everything a UI might want
  live (no timecode-tick event) — some polling is unavoidable even in an
  otherwise event-driven design; the trick is scoping the poll to only
  run while it actually matters (recording in progress).
- Verified every fix by reproducing the *exact* reported sequence live
  (real OBS process, real quickshell popup via IPC, screenshots) rather
  than reasoning about Hyprland's behavior from memory — each of the three
  bugs above was confirmed by a failing repro before being fixed, and
  reproduced again after the fix to confirm it actually held.
- One unrelated mistake this session: while dismissing an OBS
  crash-recovery dialog via `wtype`, a keystroke leaked into the browser
  and appears to have advanced the user's in-progress Qualtrics survey to
  the next page. Flagged to the user immediately; no attempt made to
  "fix" it blindly.

## Decisions
- Scope for the popup: Recording (start/stop/pause + live timecode),
  Preset scene buttons (Screen / Screen+Camera / Camera Only), Mic/Desktop
  mute toggles, Launch/Open/Hide the real OBS window. Streaming/vcam/
  replay-buffer/volume-sliders from the first draft were intentionally cut
  in favor of this tighter set (decided in the continuation before this
  context — not revisited).
- OBS websocket server enabled permanently (`server_enabled: true` in
  `~/.config/obs-studio/plugin_config/obs-websocket/config.json`) since
  the whole feature requires it; password left as whatever OBS already
  had configured, never touched or exposed.

## Open questions / residual
- None outstanding on the OBS feature itself — all three reported bugs
  (click/right-click swap, sticky-reveal, workspace-jump, frozen timecode)
  were fixed and verified live this session.
- Two pre-existing, unrelated uncommitted changes from before this
  session's work (Raymer homelab `CONTEXT.md` correction + a superseded
  dated memory note) were committed and pushed in this same round at the
  user's explicit "commit everything" — not something this session
  investigated or authored.

## Next steps
None outstanding. User said "save the session, commit everything, and
pushall" — both `dot` (TopBar.qml + new obs-toggle script) and
`nixos-config` (obs-ctl-daemon.py + the two unrelated homelab doc commits)
committed and pushed to all remotes (home/hub/local) this round.
