{ pkgs, ... }:

let
  wol-sauron = pkgs.writeShellScriptBin "wol-sauron" ''
    #!/usr/bin/env sh
    set -u
    mac=3C:52:82:74:03:F5
    # Works when actually on the 10.0.50.0/24 LAN.
    ${pkgs.wakeonlan}/bin/wakeonlan -i 10.0.50.255 -p 9 "$mac" || true
    # From off-site (e.g. over Tailscale), neither broadcast nor unicast WoL
    # reaches Sauron directly: a broadcast to 10.0.50.255 gets routed to
    # sweetpea's subnet-router, which won't forward a directed broadcast onto
    # its own LAN (bc_forwarding is off by default); a unicast packet to
    # Sauron's LAN IP needs an ARP entry for its MAC, which won't exist while
    # it's powered off. The reliable path is to run the wake command on a box
    # that's actually on Sauron's LAN segment -- sweetpea is always-on and
    # reachable over SSH from anywhere, and broadcasts fine from its own NIC.
    #
    # Go straight over Tailscale to sweetpea's tailnet IP rather than through
    # the "sweetpea" ssh-config alias, which bounces through the public
    # ssh.aaronjanovitch.com dynamic-DNS/port-forward -- that path has proven
    # flaky (refused connections) independent of whether Sauron itself is up,
    # while the direct tailnet hop has been reliable every time it's tested.
    ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 aj@100.97.56.82 \
      "wakeonlan -i 10.0.50.255 -p 9 $mac" || true
  '';
in
{
  environment.systemPackages = [ wol-sauron ];
}
