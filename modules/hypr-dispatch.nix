{ pkgs, ... }:

let
  hypr-dispatch = pkgs.writeShellScriptBin "hypr-dispatch" ''
    #!/usr/bin/env sh
    set -eu

    HYPRCTL="${pkgs.hyprland}/bin/hyprctl"

    # Find the Hyprland instance signature if not present
    if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
      sig_dir="/run/user/$(id -u)/hypr"
      if [ -d "$sig_dir" ]; then
        sig="$(ls -1 "$sig_dir" 2>/dev/null | head -n1 || true)"
        if [ -n "$sig" ]; then
          export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        fi
      fi
    fi

    exec "$HYPRCTL" dispatch "$@"
  '';
in
{
  environment.systemPackages = [ hypr-dispatch ];
}

