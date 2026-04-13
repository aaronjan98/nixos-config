# Hyprlock and Qylock Research (2026-04-12)

## Status
- **Hyprlock:** Configured and enabled via `modules/hypr-idle-lock.nix`.
- **PAM:** Added `security.pam.services.hyprlock = {}` to allow password authentication.
- **Timers:** Implemented a 3-tier idle system:
    1. 5 mins: Screen blackout (screensaver).
    2. 10 mins: Hyprlock (security).
    3. 15 mins: DPMS off (power save).
- **Aesthetic:** Minimalist "Clockwork-inspired" theme with large JetBrains Mono clock and smooth bezier fade animations.

## Future Implementation: Qylock
- **Observation:** The "exact" animations from [Darkkal44/qylock](https://github.com/Darkkal44/qylock) require **Quickshell** (QML-based) rather than native `hyprlock.conf`.
- **Requirements:**
    1. Add `quickshell` to NixOS packages.
    2. Clone/fetch `qylock` repo.
    3. Update `hypr-idle-lock.nix` to call `quickshell` on lock/idle instead of `hyprlock`.
    4. Update Super+Alt+L binding in `~/.config/hypr/conf.d/20-binds.conf`.

## Troubleshooting: Hypridle Not Starting (2026-04-12)
- **Issue:** `systemctl --user status hypridle` reported "Unit not found" or "bad/ignored".
- **Cause:** A stale/broken symlink existed at `~/.config/systemd/user/hypridle.service` pointing to an old Nix store path. Systemd prioritized this broken local link over the valid service defined in the NixOS configuration.
- **Fix:** 
    1. Removed broken symlinks: `rm ~/.config/systemd/user/hypridle.service` and `rm ~/.config/systemd/user/default.target.wants/hypridle.service`.
    2. Reloaded daemon: `systemctl --user daemon-reload`.
    3. Restarted service: `systemctl --user enable --now hypridle.service`.
- **Result:** Hypridle is now correctly managed by the NixOS module and is active.
