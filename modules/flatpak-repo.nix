{ pkgs, ... }:

let
  flathubUrl = "https://dl.flathub.org/repo/flathub.flatpakrepo";
in
{
  systemd.services.flatpak-repo = {
    description = "Ensure Flathub remote exists (flatpak)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [ pkgs.flatpak ];

    serviceConfig = {
      Type = "oneshot";

      # IMPORTANT:
      # - --system ensures it's added system-wide
      # - "bash -lc ... || true" ensures a transient network hiccup doesn't fail nixos-rebuild
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub ${flathubUrl} || true'";

      Restart = "no";
      RemainAfterExit = "no";
    };
  };
}

