{ config, lib, pkgs, ... }:

{
  # These are all loopback-only aliases, and none of them use ".local" any
  # more. RFC 6762 reserves ".local" for multicast DNS, and this machine's
  # nsswitch consults mdns4_minimal BEFORE files:
  #
  #   hosts: mymachines mdns4_minimal [NOTFOUND=return] resolve \
  #          [!UNAVAIL=return] files myhostname dns mdns4
  #
  # so every ".local" lookup waited for an mDNS timeout before /etc/hosts was
  # ever consulted. Measured on 2026-11-07: ai.local took 5.00s per lookup,
  # ai.home 0.00s. mDNS itself stays enabled — ESPHome discovery
  # (atom-echo-s3r.local) depends on it; the mistake was putting static host
  # entries in mDNS's namespace, not having mDNS.
  #
  # ".home" belongs to sweetpea's dnsmasq wildcard, so an entry here shadows
  # that wildcard for this host only. That is deliberate for services which
  # live on this laptop: this machine reaches them directly, and other devices
  # either get sweetpea's nginx (ai.home, which it proxies back here) or a 404
  # for the dev-only ones, which is the honest answer.
  #
  # movies and photos are gone entirely rather than renamed: movies.home and
  # photos.home already exist as vhosts on sweetpea, serving the same Jellyfin
  # and Immich on qwerty. Keeping local duplicates would mean one name with two
  # behaviours depending on which machine you typed it from.
  networking.hosts."127.0.0.1" = [
    "ai.home"
    "contextforge.home"
    "syncthing.home"
  ];

  services.caddy = {
    enable = true;

    globalConfig = ''
      auto_https off
    '';

    virtualHosts = {
      # Household front door for Open WebUI. Deliberately NOT bound to
      # 127.0.0.1 like the aliases around it: family and remote access are the
      # entire point. Exposure is constrained at the firewall instead, which
      # opens port 80 only on tailscale0 (see hosts/common/default.nix), so
      # reaching this means being on the tailnet and the plaintext hop stays
      # inside WireGuard — which matters because auto_https is off globally.
      #
      # DNS caveat: sweetpea's dnsmasq wildcards *.home to itself, so without
      # an explicit override record for ai.home pointing at this host's tailnet
      # address, other devices land on sweetpea's nginx and get a 404.
      "ai.home:80".extraConfig = ''
        reverse_proxy 127.0.0.1:5050
      '';

      # Friendly local alias for the Context Forge frontend (Vite dev server).
      # Loopback-bound, so other devices hitting contextforge.home reach
      # sweetpea's nginx and get a 404 — correct, nobody else should be able to
      # reach a dev server.
      # Vite's default server.host is "localhost", which resolves to ::1 here,
      # so the dev server listens on [::1]:5173 only — dial it over IPv6, not
      # 127.0.0.1 (that gives a 502). Vite's DNS-rebinding guard also rejects any
      # Host header that isn't loopback, so rewrite Host to a literal it trusts
      # (same reason as the syncthing vhost below). This keeps HMR working too.
      "contextforge.home:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy [::1]:5173 {
          header_up Host localhost:5173
        }
      '';

      # Friendly local alias for this machine's own Syncthing GUI.
      # Syncthing's CSRF check rejects requests whose Host header doesn't match
      # its bind address, so rewrite Host to 127.0.0.1:8384 before forwarding.
      "syncthing.home:80".extraConfig = ''
        bind 127.0.0.1
        reverse_proxy 127.0.0.1:8384 {
          header_up Host {upstream_hostport}
        }
      '';
    };
  };
}

