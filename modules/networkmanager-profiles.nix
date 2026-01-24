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
      ############################
      # Activation script (rebuild-time)
      ############################
      system.activationScripts.networkmanagerProfiles = ''
        if [ -d /etc/NetworkManager/system-connections ]; then
          # Ensure correct perms; NM will ignore profiles that aren't 0600 root:root
          chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
          chown root:root /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true

          # Reload profiles if NM is running
          ${pkgs.networkmanager}/bin/nmcli connection reload 2>/dev/null || true
        fi
      '';

      ############################
      # Boot-time helper service
      ############################
      systemd.services."nm-sops-profiles" = {
        description = "Install NetworkManager profiles from sops-nix secrets (/run/secrets/nm)";
        # make it start at boot
        wantedBy = [ "multi-user.target" ];

        # unit-level settings
        unitConfig = {
          # Ensure we run *before* NetworkManager so NM sees correct files
          Before = "NetworkManager.service";
          # If sops-nix exists, run after it; harmless if sops-nix is absent
          After = "sops-nix.service";
          # Only run when the secrets dir exists
          ConditionPathExists = "/run/secrets/nm";
        };

        # service-level settings
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "no";

          # Use bash -c to run a small robust script (uses install for atomic write + perms)
          ExecStart = "${pkgs.bash}/bin/bash -lc ''\
            set -euo pipefail; \
            if [ -d /run/secrets/nm ]; then \
              for src in /run/secrets/nm/*; do \
                [ -e \"$src\" ] || continue; \
                dst=\"/etc/NetworkManager/system-connections/$(basename \"$src\")\"; \
                ${pkgs.coreutils}/bin/install -m 0600 -o root -g root \"$src\" \"$dst\"; \
              done; \
              ${pkgs.networkmanager}/bin/nmcli connection reload 2>/dev/null || true; \
            fi \
          ''";
        };
      };

      ############################
      # NetworkManager unit tweaks
      ############################
      systemd.services.NetworkManager = {
        wants = [ "sops-nix.service" "nm-sops-profiles.service" ];
        after = [ "sops-nix.service" "nm-sops-profiles.service" ];
      };
    }
  ]
)

