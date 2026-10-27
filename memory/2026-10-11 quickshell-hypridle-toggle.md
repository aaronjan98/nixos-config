# 2026-10-11 Quickshell Hypridle Toggle (Keep-Awake Switch)

## Context & Motivation
AJ wanted a quick toggle in the Quickshell bar to prevent the screen from dimming/blacking out and locking when wanting the display to stay awake indefinitely, rather than manually running `systemctl --user stop hypridle` and `systemctl --user start hypridle` from a terminal.

## Architecture & Implementation
The standalone application icons row in `TopBar.qml` (outside and to the left of the top-right island) already hosted `ObsIcon`, `ClipboardIcon`, and `NotetakeIcon`. We followed this exact pattern to add a fourth toggle icon for `hypridle`.

### Files Modified & Created
1. `~/.config/quickshell/rices/limerence/components/services/HypridleCtl.qml` (new):
   - Singleton service backed by `Quickshell.Io.Process`.
   - Polling timer (2.5s) queries `systemctl --user is-active hypridle` to stay synchronized if hypridle is started/stopped outside Quickshell.
   - Methods: `start()`, `stop()`, `toggle()`, `refreshStatus()`.
   - Properties: `idleEnabled` (bool, true when hypridle is active) and `keepAwake` (bool, true when hypridle is stopped).
   - IPC Handler: `target: "hypridle"`, enabling control via `qs -p ~/.config/quickshell/rices/current/shell.qml ipc call hypridle toggle`.

2. `~/.config/quickshell/rices/limerence/components/services/qmldir`:
   - Registered `singleton HypridleCtl 1.0 HypridleCtl.qml`.

3. `~/.config/quickshell/rices/limerence/components/widgets/HypridleIcon.qml` (new):
   - Standalone bar icon widget.
   - Normal mode (hypridle active): Displays `󰛊` (coffee-off, nf-md-coffee_off) in standard bar white/grey (`Qt.rgba(1, 1, 1, 0.65)`).
   - Keep-awake mode (hypridle stopped): Displays `󰅶` (coffee cup, nf-md-coffee) in warm caffeine amber (`Qt.rgba(0.95, 0.72, 0.38, 0.95)`).
   - Mouse hover highlights the icon. Click triggers `Sv.HypridleCtl.toggle()`.

4. `~/.config/quickshell/rices/limerence/components/frame/TopBar.qml`:
   - Added `W.HypridleIcon { }` to the standalone application icons `Row` left of `rightIsland`.

5. `~/.config/quickshell/rices/limerence/docs/widgets-and-services.md`:
   - Documented `HypridleCtl.qml` in the Services section and `HypridleIcon.qml` in the Top bar widgets section.

## Verification
- Reloaded Quickshell via `qs kill ... && qs -d -p ...`. Quickshell loaded cleanly with zero errors.
- Verified toggle functionality via IPC (`qs ipc call hypridle toggle`).
- Verified `systemctl --user is-active hypridle` successfully stops (`inactive`) and resumes (`active`), and icon reflects state transitions in real time.
