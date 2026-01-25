{ config, pkgs, lib, ... }:

let
  # Map decrypted secret files -> final NM profile filenames in /etc
  nmProfiles = [
    { secret = "connect-here"; target = "Connect here.nmconnection"; }
    { secret = "hello-there";  target = "Hello There!.nmconnection"; }
    { secret = "eduroam";      target = "eduroam.nmconnection"; }
  ];

  # Generate sops secrets that land in /run/secrets/nm/<secret>
  mkSopsSecret = { secret, ... }: {
    name = "nm/${secret}";
    value = {
      sopsFile = ../secrets/networkmanager/${secret}.nmconnection;
      format = "binary";
      owner = "root";
      group = "root";
      mode = "0600";

      # IMPORTANT: decrypt to /run/secrets, NOT /etc
      path = "/run/secrets/nm/${secret}";
    };
  };

  copyScript = ''
    set -euo pipefail

    mkdir -p /etc/NetworkManager/system-connections
    chmod 700 /etc/NetworkManager/system-connections

    ${lib.concatStringsSep "\n" (map (p: ''
      if [ -e "/run/secrets/nm/${p.secret}" ]; then
        ${pkgs.coreutils}/bin/install -m 0600 -o root -g root \
          "/run/secrets/nm/${p.secret}" \
          "/etc/NetworkManager/system-connections/${p.target}"
      fi
    '') nmProfiles)}

    # Reload profiles if NM is already up (safe if it isn't)
    ${pkgs.networkmanager}/bin/nmcli connection reload 2>/dev/null || true
  '';
in
{
  # Declare the sops secrets
  sops.secrets = lib.listToAttrs (map mkSopsSecret nmProfiles);

  # Rebuild-time: ensure /etc gets real files (not symlinks) immediately on switch
  system.activationScripts.networkmanagerProfiles = copyScript;

  # Boot-time: copy secrets into /etc BEFORE NetworkManager starts
  systemd.services.nm-sops-profiles = {
    description = "Copy sops-decrypted NM profiles into /etc as real files";
    wantedBy = [ "multi-user.target" ];

    # Run after secrets are installed, before NetworkManager
    before = [ "NetworkManager.service" ];
    after  = [ "sops-install-secrets.service" ];

    # Only run if secrets dir exists
    unitConfig.ConditionPathExists = "/run/secrets/nm";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };

    # Using `script` avoids systemd unit parsing/quoting problems
    script = copyScript;
  };

  # Ensure NM doesn't start before our copy runs
  systemd.services.NetworkManager = {
    wants = [ "nm-sops-profiles.service" ];
    after = [ "nm-sops-profiles.service" ];
  };
}

