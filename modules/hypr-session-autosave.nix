{ pkgs, ... }:

# Periodically snapshot the whole 2D Hyprland workspace with `hypr-session save
# --all`, the same way tmux-continuum autosaves. A reboot then only needs
# `hypr-session restore --all` to bring every domain's apps back.
#
# `save --all` is read-only against the live session (it only reads hyprctl
# clients + tmux sessions and rewrites the state file), so running it on a timer
# is safe. It overwrites last-write-wins, so the state file is a live snapshot,
# not a hand-curated document — run `hypr-session edit` only when the timer is
# paused if you want a curated restore.
#
# Env (WAYLAND_DISPLAY / HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR) reaches
# the systemd user manager via the `systemctl --user import-environment` +
# `dbus-update-activation-environment` exec-once lines in the Hyprland config,
# so a timer-fired service can talk to hyprctl.
{
  systemd.user.services.hypr-session-save = {
    description = "Autosave 2D Hyprland workspace session (all domains)";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      # login shell so PATH resolves hypr-session / hyprctl / tmux / obsidian-remote
      ExecStart = "${pkgs.bash}/bin/bash -lc 'hypr-session save --all'";
    };
  };

  systemd.user.timers.hypr-session-save = {
    description = "Periodically autosave the Hyprland workspace session";
    # Bound to graphical-session.target so it only counts down while Hyprland is
    # up (never fires on a TTY-only boot where hyprctl would just error).
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "5min"; # first save 5 min after the session starts
      OnUnitActiveSec = "15min"; # then every 15 min (matches @continuum-save-interval)
    };
  };
}
