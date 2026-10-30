{ pkgs, ... }:

let
  wol-sauron = pkgs.writeShellScriptBin "wol-sauron" ''
    #!/usr/bin/env sh
    set -eu
    # Broadcast works when we're actually on the 10.0.50.0/24 LAN. When this
    # runs over Tailscale (e.g. from campus wifi), the packet is routed
    # unicast to sweetpea's subnet-router and sweetpea's kernel will not
    # forward a directed broadcast onto its own LAN (bc_forwarding is off by
    # default), so the magic packet never reaches Sauron's NIC. Sending a
    # second copy as unicast straight to Sauron's LAN IP sidesteps that:
    # normal unicast IP forwarding applies, no special sysctl needed.
    ${pkgs.wakeonlan}/bin/wakeonlan -i 10.0.50.255 -p 9 3C:52:82:74:03:F5
    ${pkgs.wakeonlan}/bin/wakeonlan -i 10.0.50.213 -p 9 3C:52:82:74:03:F5
  '';
in
{
  environment.systemPackages = [ wol-sauron ];
}
