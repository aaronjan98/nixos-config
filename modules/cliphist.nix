{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.cliphist
    pkgs.wl-clipboard
  ];

  # Not wantedBy graphical-session.target: that target is never started on this
  # Hyprland setup (see modules/xremap.nix), so nothing would ever pull these in.
  # Instead they're started explicitly by exec-once in Hyprland's config, after
  # the WAYLAND_DISPLAY import-environment lines, so wl-paste always has a socket.
  systemd.user.services.cliphist-text = {
    description = "Cliphist (text)";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  systemd.user.services.cliphist-image = {
    description = "Cliphist (image)";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}

