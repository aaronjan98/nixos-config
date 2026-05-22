{ config, lib, pkgs, ... }:

# Pre-suspend hook: run sync-machine.sh --leave (via the sync-toast wrapper)
# when the system is about to suspend, so a notification surfaces any
# uncommitted/dirty repos before the lid actually closes.
#
# The toast itself probably won't be visible right at suspend time — the
# screen is going dark — but it persists in the notification daemon (Quickshell)
# and is shown on next wake. It's a memory aid for "did I forget to push?".
#
# Why a system service (and not a user unit): user-level systemd does not see
# system suspend events. The only reliable hook into system suspend is from a
# root-owned unit pulled in by sleep.target. We run as user aj with the right
# DBUS env so notify-send can reach Quickshell on the user's session bus.

let
  cfg = config.aj.syncLeavePreflight;
in
{
  options.aj.syncLeavePreflight = {
    enable = lib.mkEnableOption "Run sync-leave check before system suspend";

    user = lib.mkOption {
      type = lib.types.str;
      default = "aj";
      description = "User account to run the check as.";
    };

    wrapper = lib.mkOption {
      type = lib.types.str;
      default = "/home/aj/.config/hypr/scripts/sync-toast";
      description = ''
        Path to the sync-toast wrapper. Lives in the dotfiles bare repo, so
        the path is hardcoded to the user's home rather than discovered.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sync-leave-preflight = {
      description = "Sync-leave dirty-repo check before suspend";
      # Pull this in whenever the system heads for any sleep state.
      wantedBy = [ "sleep.target" ];
      before   = [ "sleep.target" ];
      # Resolve XDG_RUNTIME_DIR / DBUS_SESSION_BUS_ADDRESS at runtime via
      # `id -u`. Avoids depending on systemd specifier expansion (%U) inside
      # Environment= values, which NixOS rendered as a literal "%U" and broke
      # notify-send's ability to reach the user's session bus.
      script = ''
        export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
        exec ${cfg.wrapper} leave
      '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        # Cap the runtime so a hung git status can't delay suspend indefinitely.
        TimeoutStartSec = "20s";
        # Exit 2 from the wrapper (dirty repos found) is informational, not
        # a failure. Don't poison the suspend cycle if the toast itself reports
        # warnings.
        SuccessExitStatus = "0 2";
      };
    };
  };
}
