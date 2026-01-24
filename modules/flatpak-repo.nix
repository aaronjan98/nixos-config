{ config, pkgs, lib, ... }:

let
  flathubUrl = "https://flathub.org/repo/flathub.flatpakrepo";
in
{
  options = { };

  config = {
    # Do NOT modify environment.systemPackages here to avoid recursion.
    # The unit will get flatpak via path below; if you want flatpak available
    # in the system profile, add it in configuration.nix explicitly.

    systemd.services.flatpak-repo = {
      description = "Ensure Flathub remote exists (flatpak)";

      wantedBy = [ "multi-user.target" ];

      # Make the flatpak binary available when the unit runs.
      path = [ pkgs.flatpak ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub ${flathubUrl}";
        Restart = "no";
        RemainAfterExit = "no";
      };

      unitConfig = {
        After = "network-online.target";
        Wants = [ "network-online.target" ];
      };
    };
  };
}

