{ pkgs, ... }:

let
  wol-sauron = pkgs.writeShellScriptBin "wol-sauron" ''
    #!/usr/bin/env sh
    set -eu
    exec ${pkgs.wakeonlan}/bin/wakeonlan -i 10.0.50.255 -p 9 3C:52:82:74:03:F5
  '';
in
{
  environment.systemPackages = [ wol-sauron ];
}
