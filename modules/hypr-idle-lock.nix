{ config, lib, pkgs, ... }:

{
  # packages (you can remove from host config after this)
  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
  ];

  # System-wide hypridle config (no home-manager)
  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
      lock_cmd = hyprlock
      unlock_cmd = pkill -USR1 hyprlock
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on
    }

    # lock after 5 minutes
    listener {
      timeout = 300
      on-timeout = hyprlock
    }

    # screen off after 10 minutes
    listener {
      timeout = 600
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }
  '';

  # Run hypridle as a *user* service in graphical sessions
  systemd.user.services.hypridle = {
    description = "Hypridle idle daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}

