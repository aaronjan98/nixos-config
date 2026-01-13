{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xremap;
in {
  options.services.xremap = {
    enable = mkEnableOption "xremap key remapping";
  };

  config = mkIf cfg.enable {
    services.xremap = {
      withHyprland = true;
      config = {
        modmap = [];
        keymap = [
          {
            name = "Firefox tab navigation";
            application = {
              only = ["firefox"];
            };
            remap = {
              "Alt-j" = "C-Page_Down";
              "Alt-k" = "C-Page_Up";
            };
          }
        ];
      };
    };
  };
}
