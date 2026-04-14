# 2026-04-14 Hypridle Keyboard & Brightness Fix

## What was worked on
Cleaned up and completed an agent's partial fix for keyboard backlight not turning off during hypridle screen blackout, then debugged sleep/resume brightness restore behavior.

## Problem
The keyboard backlight wouldn't shut off when hypridle's 5-minute screen blackout triggered. A previous agent had already committed keyboard backlight save/restore to `modules/hypr-idle-lock.nix` (commit `74bb07e`), but left dotfiles changes uncommitted and `maybeRestoreKbd()` only commented out rather than removed.

## Root cause
`BrightnessCtl.qml` had a poll timer running every 800ms that called `maybeRestoreKbd()`. When hypridle turned off the keyboard, quickshell would restore it within 800ms — fighting the blackout. The function's original purpose was "restore keyboard after suspend resume" but that role now belongs to the hypridle scripts.

## What was done

### Quickshell (`BrightnessCtl.qml`)
- Removed `maybeRestoreKbd()` function entirely
- Removed dead state: `desiredKbdStep`, `_restoreArmed`
- Removed dead init block in `kbdInfoProc` that set those properties
- Simplified poll timer comment and body

### Hyprland dotfiles
- `10-programs.conf`: wallpaper path already fixed to `current.png` symlink (prior agent)
- `30-look.conf`: `session_lock_xray = true` added (needed for hyprlock `path = screenshot` blur)
- `40-windowrules.conf`: LibreOffice opacity rule added

### NixOS (`modules/hypr-idle-lock.nix`)
- `before_sleep_cmd`: changed to call `screen-blackout-on` before locking — saves both screen and keyboard brightness before suspend
- `after_sleep_cmd`: restores DPMS and calls `screen-blackout-off` to restore brightness on resume
- Hardware does NOT preserve brightness across suspend on this machine — software save/restore required

## Key insights
- The idle blackout path (on-timeout / on-resume listeners) works correctly — confirmed by temporarily lowering timeout to 10s
- The sleep/resume path needs explicit save/restore because the hardware doesn't preserve brightness
- `screen-blackout-on` is idempotency-safe for the sleep path: if the screen was already blacked out before sleep, that state's already saved — but we did NOT add the idempotency guard in the end (decided against extra code)
- hypridle does not hot-reload — must `systemctl --user restart hypridle` after config changes

## Open questions
- If the machine sleeps during an active blackout (5-min idle triggered then lid close), `screen-blackout-on` in `before_sleep_cmd` will overwrite state with 0-brightness values. This could restore to 0 on wake. Not confirmed as a real problem yet.

## Files changed (uncommitted dotfiles)
- `~/.config/quickshell/rices/limerence/components/services/BrightnessCtl.qml`
- `~/.config/hypr/conf.d/10-programs.conf`
- `~/.config/hypr/conf.d/30-look.conf`
- `~/.config/hypr/conf.d/40-windowrules.conf`

## Files changed (nixos-config, uncommitted)
- `modules/hypr-idle-lock.nix`

## Next steps
- Commit dotfiles (`dot add` / `dot commit`)
- Commit nixos-config changes
