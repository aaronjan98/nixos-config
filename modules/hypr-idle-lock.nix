{ config, lib, pkgs, ... }:

let
  blackoutOn = pkgs.writeShellScriptBin "screen-blackout-on" ''
    #!/usr/bin/env bash
    set -eu

    uid="$(id -u)"
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
    state_dir="$runtime/screen-blackout"
    mkdir -p "$state_dir"

    if command -v brightnessctl >/dev/null 2>&1; then
      # brightnessctl -m output is usually:
      # device,subsystem,driver,current,max,percent
      line="$(brightnessctl -m | head -n1 || true)"
      dev="$(printf '%s' "$line" | cut -d, -f1)"
      cur="$(printf '%s' "$line" | cut -d, -f4)"

      printf '%s\n' "$dev" > "$state_dir/device" || true
      printf '%s\n' "$cur" > "$state_dir/current" || true

      # Go as dark as possible (some panels still glow slightly)
      brightnessctl -d "$dev" set 0% >/dev/null 2>&1 || true
    fi
  '';

  blackoutOff = pkgs.writeShellScriptBin "screen-blackout-off" ''
    #!/usr/bin/env bash
    set -eu

    uid="$(id -u)"
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
    state_dir="$runtime/screen-blackout"

    if command -v brightnessctl >/dev/null 2>&1; then
      dev=""
      cur=""

      if [ -f "$state_dir/device" ]; then dev="$(cat "$state_dir/device" || true)"; fi
      if [ -f "$state_dir/current" ]; then cur="$(cat "$state_dir/current" || true)"; fi

      if [ -n "$dev" ] && [ -n "$cur" ]; then
        # Restore absolute brightness value (not percent)
        brightnessctl -d "$dev" set "$cur" >/dev/null 2>&1 || true
      else
        # Fallback
        brightnessctl set 40% >/dev/null 2>&1 || true
      fi

      rm -f "$state_dir/device" "$state_dir/current" >/dev/null 2>&1 || true
    fi
  '';
in
{
  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    brightnessctl
    blackoutOn
    blackoutOff
  ];

  # System-wide hypridle config (no home-manager)
  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
      lock_cmd = hyprlock

      # KEY FIX: restore brightness when you unlock (reliable),
      # because on-resume may not fire while hyprlock is active.
      unlock_cmd = /run/current-system/sw/bin/screen-blackout-off

      # Also restore after sleep
      after_sleep_cmd = /run/current-system/sw/bin/screen-blackout-off
    }

    # Lock after 5 minutes idle
    listener {
      timeout = 300
      on-timeout = hyprlock
    }

    # Blackout shortly after locking (looks "off" but still wakes)
    listener {
      timeout = 310
      on-timeout = /run/current-system/sw/bin/screen-blackout-on
      on-resume = /run/current-system/sw/bin/screen-blackout-off
    }
  '';

  # Start hypridle on login
  # NOTE: In Hyprland sessions, systemd user targets can be flaky.
  # We'll keep this, but also recommend exec-once in hyprland.conf below.
  systemd.user.services.hypridle = {
    description = "Hypridle idle daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}

