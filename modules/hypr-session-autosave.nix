{ pkgs, ... }:

# Periodically snapshot the whole 2D Hyprland workspace with `hypr-session save
# --all`, the same way tmux-continuum autosaves. A reboot then only needs
# `hypr-session restore --all` to bring every domain's apps back.
#
# `save --all` only reads hyprctl clients + tmux sessions and rewrites the
# state file — it never spawns or moves windows itself, so running it on a
# timer can't directly break anything. But it overwrites last-write-wins, so
# if it fires while a `restore` is still placing windows (or just after one
# finished with failures), it happily bakes that half-finished layout in as
# if it were the user's intent. `--auto` below makes it skip itself in those
# windows instead — see the "autosave safety" comment in hypr-session.py. The
# state file is a live snapshot, not a hand-curated document — run
# `hypr-session edit` only when the timer is paused if you want a curated
# restore.
#
# Env (WAYLAND_DISPLAY / HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR) reaches
# the systemd user manager via the `systemctl --user import-environment` +
# `dbus-update-activation-environment` exec-once lines in the Hyprland config,
# so a timer-fired service can talk to hyprctl.
{
  systemd.user.services.hypr-session-save = {
    description = "Autosave 2D Hyprland workspace session (all domains)";
    serviceConfig = {
      Type = "oneshot";
      # Skip silently (not fail) when Hyprland isn't reachable — e.g. a TTY-only
      # login where the timer still ticks but there's no compositor to snapshot.
      ExecCondition = "${pkgs.bash}/bin/bash -lc 'hyprctl version >/dev/null 2>&1'";
      # login shell so PATH resolves hypr-session / hyprctl / tmux / obsidian-remote
      # --auto lets `save` skip itself while a restore is still in flight,
      # still settling, or reported failures that haven't been reviewed yet —
      # see the "autosave safety" comment in hypr-session.py.
      ExecStart = "${pkgs.bash}/bin/bash -lc 'hypr-session save --all --auto'";
    };
  };

  systemd.user.timers.hypr-session-save = {
    description = "Periodically autosave the Hyprland workspace session";
    # timers.target is always active in the user session (graphical-session.target
    # is never started on this Hyprland setup, so binding to it left the timer
    # dead). The ExecCondition above keeps it a no-op outside a live session.
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "5min"; # first save 5 min after login
      OnUnitActiveSec = "15min"; # then every 15 min (matches @continuum-save-interval)
    };
  };
}
