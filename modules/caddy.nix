{ config, lib, pkgs, ... }:

{
  networking.hosts."127.0.0.1" = [
    "ai.local"
    "movies.local"
    "photos.local"
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

      "movies.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy http://qwerty:8096
      '';

      "photos.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy http://qwerty:2283
      '';
    };
  };
}

