{ config, lib, pkgs, ... }:

{
  networking.hosts."127.0.0.1" = [
    "ai.local"
    "contextforge.local"
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

      # Friendly local alias for the Context Forge frontend (Vite dev server).
      # Vite's default server.host is "localhost", which resolves to ::1 here,
      # so the dev server listens on [::1]:5173 only — dial it over IPv6, not
      # 127.0.0.1 (that gives a 502). Vite's DNS-rebinding guard also rejects any
      # Host header that isn't loopback, so rewrite Host to a literal it trusts
      # (same reason as the syncthing vhost below). This keeps HMR working too.
      "contextforge.local:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy [::1]:5173 {
          header_up Host localhost:5173
        }
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

