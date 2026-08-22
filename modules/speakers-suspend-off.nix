{ config, lib, pkgs, ... }:

# Pre-suspend hook: turn the desk speakers off when the Framework heads for any
# sleep state, so the receiver/amp isn't left powered while the laptop (and I)
# are away.
#
# The speaker plug is a Kasa KP125M driven locally through Home Assistant's
# Matter integration; scripts/speakers.sh calls HA's REST API using
# HA_URL/HA_TOKEN read from the voice-orchestrator .env.
#
# `switch/turn_off` is idempotent — if the speakers are already off this is a
# harmless no-op — so we just call it unconditionally rather than reading the
# state first (one fewer round-trip before suspend).
#
# Runs as user aj (not root) so the script can read the aj-owned, gitignored
# orchestrator .env. As in sync-leave-preflight.nix, a root-pulled sleep.target
# unit is the only reliable hook into system suspend; setting User= gives us
# aj's home so $HOME/…/.env resolves.

let
  cfg = config.aj.speakersSuspendOff;
in
{
  options.aj.speakersSuspendOff = {
    enable = lib.mkEnableOption "Turn the desk speakers off before system suspend";

    user = lib.mkOption {
      type = lib.types.str;
      default = "aj";
      description = "User account to run the speaker-off command as.";
    };

    script = lib.mkOption {
      type = lib.types.str;
      default = "/home/aj/nixos-config/scripts/speakers.sh";
      description = ''
        Path to the speakers helper script. Lives in this repo's scripts/ dir
        and reads HA credentials from the orchestrator .env, so the path is
        hardcoded to the user's checkout rather than the nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.speakers-suspend-off = {
      description = "Turn desk speakers off before suspend";
      # Pull this in whenever the system heads for any sleep state, ordered
      # before the actual suspend so the plug is cut while HA is still up.
      wantedBy = [ "sleep.target" ];
      before   = [ "sleep.target" ];
      script = ''
        export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"
        export HOME="/home/${cfg.user}"
        exec ${pkgs.bash}/bin/bash ${cfg.script} off
      '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        # Cap the runtime so an unreachable Home Assistant can't delay suspend
        # indefinitely. If it can't turn the plug off in time, let suspend
        # proceed anyway (a failed oneshot doesn't block sleep.target).
        TimeoutStartSec = "15s";
      };
    };
  };
}
