{ config, lib, pkgs, ... }:

{
  networking.hosts."127.0.0.1" = [
    "ai.local"
  ];

  services.caddy = {
    enable = true;

    globalConfig = ''
      auto_https off
    '';

    virtualHosts = {
      "ai.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy 127.0.0.1:5050
      '';
    };
  };
}

