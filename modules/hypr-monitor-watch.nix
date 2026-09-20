{ pkgs, ... }:

# Supervise the Hyprland monitor-hotplug handler
# (`~/.config/hypr/scripts/watch-monitors`), which reapplies wallpapers and
# repairs stranded floating-window geometry when a monitor is plugged or
# unplugged.
#
# It used to be an `exec-once` line in the Hyprland config, which had two silent
# failure modes: the script exited immediately if it started before Hyprland had
# created its event socket (exec-once gives no ordering guarantee), and it exited
# for good the first time its `socat` pipe ended. Either way hotplug handling was
# dead for the rest of the session with no log and no way to notice — observed on
# framework-13 on 2026-09-20, where a replugged monitor got no wallpaper back.
#
# As a service it gets restarted on exit and its output lands in the journal:
#   systemctl --user status hypr-monitor-watch
#   journalctl --user -u hypr-monitor-watch -f
#
# The script stays in the dotfiles repo rather than being packaged here so the
# hotplug reaction can be edited and reloaded (`systemctl --user restart
# hypr-monitor-watch`) without a system rebuild.
{
  systemd.user.services.hypr-monitor-watch = {
    description = "Reapply wallpapers and repair floating geometry on monitor hotplug";
    # default.target, not graphical-session.target — the latter is never started
    # on this Hyprland setup (see modules/hypr-session-autosave.nix).
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      # Login shell so socat / hyprctl / hypr-session / swww resolve from PATH.
      ExecStart = "${pkgs.bash}/bin/bash -lc '~/.config/hypr/scripts/watch-monitors'";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
