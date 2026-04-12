{ pkgs, ... }:

let
  wol-sauron = pkgs.writeShellScriptBin "wol-sauron" ''
    #!/usr/bin/env sh
    set -eu
    exec ${pkgs.wakeonlan}/bin/wakeonlan -i 192.168.1.255 -p 9 3C:52:82:74:03:F5
  '';
in
{
  environment.systemPackages = [ wol-sauron ];
}
