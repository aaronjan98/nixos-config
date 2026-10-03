{ config, lib, pkgs, ... }:

# Declarative Syncthing peer for ~/Documents and ~/Pictures.
#
# Per-host config supplies the device IDs of the *other* peers under
# `aj.syncthing.devices`. Each host's own device ID is generated on first
# rebuild (look at ~/.config/syncthing/cert.pem or run `syncthing cli show
# system` to retrieve it), then wired into the other hosts.
#
# overrideDevices/overrideFolders=true means this NixOS config is the source
# of truth — manual changes in the Syncthing web UI will be reverted on
# rebuild. That is intentional: keep the topology in git, not in the UI.

let
  cfg = config.aj.syncthing;
in
{
  options.aj.syncthing = {
    enable = lib.mkEnableOption "Syncthing peer for Documents and Pictures";

    devices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.id = lib.mkOption {
          type = lib.types.str;
          description = "Syncthing device ID of the peer.";
        };
      });
      default = { };
      description = ''
        Trusted Syncthing peers, keyed by short name (exclude self).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "aj";
      group = "users";
      dataDir = "/home/aj";
      configDir = "/home/aj/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.mapAttrs (_: d: { inherit (d) id; }) cfg.devices;

        folders = {
          "Documents" = {
            path = "/home/aj/Documents";
            devices = lib.attrNames cfg.devices;
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";   # prune every hour
                maxAge = "2592000";       # keep 30 days of history
              };
            };
          };

          "Pictures" = {
            path = "/home/aj/Pictures";
            devices = lib.attrNames cfg.devices;
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000";
              };
            };
          };

          # Obsidian community-plugin binaries for the zettelkasten vault. The
          # vault's NOTES stay in git exactly as before; `.obsidian/plugins/` is
          # gitignored (plugin binaries don't belong in git — LaTeX Math alone is
          # a 103MB Sympy/WASM bundle that exceeds GitHub's 100MB file limit), so
          # Syncthing carries just this subdir instead. Install a plugin once on
          # either laptop and it propagates. Scoped to the laptops only (exclude
          # qwerty — it's a headless media server with no Obsidian). No versioning:
          # these are regenerable binaries, not documents worth 30 days of history.
          "obsidian-plugins" = {
            path = "/home/aj/Repositories/self-hosted/zettelkasten/.obsidian/plugins";
            devices = lib.filter (d: d != "qwerty") (lib.attrNames cfg.devices);
          };
        };

        options = {
          urAccepted = -1;       # opt out of anonymous usage reporting
          relaysEnabled = true;
        };
      };
    };

    environment.systemPackages = [ pkgs.syncthing ];
  };
}
