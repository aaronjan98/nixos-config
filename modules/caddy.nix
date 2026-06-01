{ config, lib, pkgs, ... }:

{
  networking.hosts."127.0.0.1" = [
    "ai.local"
    "movies.local"
    "photos.local"
    "syncthing.local"
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

      # Syncthing GUI on qwerty is bound to 127.0.0.1:8384 (admin-only).
      # Reach it by first opening an SSH tunnel:
      #   ssh -L 8384:127.0.0.1:8384 aj@qwerty.home
      # Then http://syncthing.local routes here, into the tunnel, into qwerty.
      "syncthing.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy 127.0.0.1:8384
      '';
    };
  };
}

