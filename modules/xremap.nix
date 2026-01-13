{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.xremap;

  xremapConfig = pkgs.writeText "xremap-config.yml" ''
    keymap:
      - name: Firefox tab navigation
        application:
          only: [firefox]
        device:
          only: ["kanata"]
        remap:
          M-j: C-PageDown
          M-k: C-PageUp
  '';
in {
  options.programs.xremap = {
    enable = mkEnableOption "xremap key remapping";
    userName = mkOption {
      type = types.str;
      default = "aj";
      description = "User to run xremap for";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.xremap ];

    users.groups.input.members  = [ cfg.userName ];
    users.groups.uinput.members = [ cfg.userName ];

    boot.kernelModules = [ "uinput" ];
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    systemd.user.services.xremap = {
      description = "xremap key remapping daemon";
      # wantedBy = [ "graphical-session.target" ];
      # partOf   = [ "graphical-session.target" ];
      after    = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.xremap}/bin/xremap --watch --device kanata ${xremapConfig}";
        Restart = "on-failure";
        RestartSec = "3";
      };
    };
  };
}

