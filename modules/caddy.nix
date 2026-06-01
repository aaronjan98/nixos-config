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

      # Friendly local alias for this machine's own Syncthing GUI.
      # Syncthing's CSRF check rejects requests whose Host header doesn't match
      # its bind address, so rewrite Host to 127.0.0.1:8384 before forwarding.
      "syncthing.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy 127.0.0.1:8384 {
          header_up Host {upstream_hostport}
        }
      '';
    };
  };
}

