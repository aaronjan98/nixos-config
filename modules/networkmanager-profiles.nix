{ config, pkgs, lib, ... }:

let
  # Helper to define one nmconnection secret
  mkNmProfile = { secretName, file, targetName ? file }: {
    sops.secrets.${secretName} = {
      # This file is encrypted in git (sops format)
      sopsFile = ../secrets/networkmanager/${file};

      # nmconnection is INI-ish but treat it as binary so sops doesn't try to parse
      format = "binary";

      owner = "root";
      group = "root";
      mode = "0600";

      # Where NetworkManager reads system-wide profiles
      path = "/etc/NetworkManager/system-connections/${targetName}";
    };
  };

  profiles = [
    (mkNmProfile {
      secretName = "nm/connect-here";
      file = "connect-here.nmconnection";
      targetName = "Connect here.nmconnection";
    })
    (mkNmProfile {
      secretName = "nm/hello-there";
      file = "hello-there.nmconnection";
      targetName = "Hello There!.nmconnection";
    })
    (mkNmProfile {
      secretName = "nm/eduroam";
      file = "eduroam.nmconnection";
      targetName = "eduroam.nmconnection";
    })
  ];
in
lib.mkMerge (
  profiles ++ [
    {
      # Make sure NM sees new/updated profiles after sops-nix writes them
      system.activationScripts.networkmanagerProfiles = ''
        if [ -d /etc/NetworkManager/system-connections ]; then
          # Ensure correct perms; NM will ignore profiles that aren't 0600 root:root
          chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
          chown root:root /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true

          # Reload profiles if NM is running
          ${pkgs.networkmanager}/bin/nmcli connection reload 2>/dev/null || true
        fi
      '';

      # Ensure NetworkManager doesn't come up before secrets exist (helps on boot)
      systemd.services.NetworkManager = {
        wants = [ "sops-nix.service" ];
        after  = [ "sops-nix.service" ];
      };
    }
  ]
)

