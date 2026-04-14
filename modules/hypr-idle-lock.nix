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
      # Screen brightness
      line="$(brightnessctl -m | head -n1 || true)"
      dev="$(printf '%s' "$line" | cut -d, -f1)"
      cur="$(printf '%s' "$line" | cut -d, -f4)"

      printf '%s\n' "$dev" > "$state_dir/device" || true
      printf '%s\n' "$cur" > "$state_dir/current" || true
      brightnessctl -d "$dev" set 0% >/dev/null 2>&1 || true

      # Keyboard backlight
      if brightnessctl -d "tpacpi::kbd_backlight" g >/dev/null 2>&1; then
        kbd_cur="$(brightnessctl -d "tpacpi::kbd_backlight" g)"
        printf '%s\n' "$kbd_cur" > "$state_dir/kbd_current"
        brightnessctl -d "tpacpi::kbd_backlight" s 0 >/dev/null 2>&1
      fi
    fi
  '';

  blackoutOff = pkgs.writeShellScriptBin "screen-blackout-off" ''
    #!/usr/bin/env bash
    set -eu

    uid="$(id -u)"
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
    state_dir="$runtime/screen-blackout"

    if command -v brightnessctl >/dev/null 2>&1; then
      # Restore screen
      if [ -f "$state_dir/device" ] && [ -f "$state_dir/current" ]; then
        dev="$(cat "$state_dir/device")"
        cur="$(cat "$state_dir/current")"
        brightnessctl -d "$dev" set "$cur" >/dev/null 2>&1
      else
        brightnessctl set 40% >/dev/null 2>&1
      fi

      # Restore keyboard
      if [ -f "$state_dir/kbd_current" ]; then
        kbd_cur="$(cat "$state_dir/kbd_current")"
        brightnessctl -d "tpacpi::kbd_backlight" s "$kbd_cur" >/dev/null 2>&1
      fi

      rm -rf "$state_dir" >/dev/null 2>&1
    fi
  '';
in
{
  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    brightnessctl
    playerctl
    blackoutOn
    blackoutOff
  ];

  # System-wide hypridle config
  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
      lock_cmd = pidof hyprlock || /run/current-system/sw/bin/hyprlock
      before_sleep_cmd = /run/current-system/sw/bin/screen-blackout-on; loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on && /run/current-system/sw/bin/screen-blackout-off
    }
  
    # 5 mins: Screensaver (Blackout) - only if no player is playing
    listener {
      timeout = 300
      on-timeout = playerctl status 2>/dev/null | grep -q "Playing" || /run/current-system/sw/bin/screen-blackout-on
      on-resume = /run/current-system/sw/bin/screen-blackout-off
    }

    # 10 mins: Lock Screen - only if no player is playing
    listener {
      timeout = 600
      on-timeout = playerctl status 2>/dev/null | grep -q "Playing" || loginctl lock-session
    }
  
    # 15 mins: Turn off display (DPMS)
    listener {
      timeout = 900
      on-timeout = playerctl status 2>/dev/null | grep -q "Playing" || hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }
  '';

  # System-wide hyprlock config
  environment.etc."xdg/hypr/hyprlock.conf".text = ''
    general {
      no_fade_in = false
      grace = 0
      disable_loading = true
    }

    animations {
      enabled = true
      bezier = linear, 1, 1, 0, 0
      animation = fadeIn, 1, 5, linear
      animation = fadeOut, 1, 5, linear
      animation = inputFieldFade, 1, 5, linear
    }

    background {
      monitor =
      path = screenshot
      color = rgba(25, 20, 20, 0.45)
      
      # Now that path is 'screenshot', blur will work
      blur_passes = 1
      blur_size = 4
      
      # Extra visual effects
      noise = 0.0117
      contrast = 0.8916
      brightness = 0.8172
      vibrancy = 0.1696
      vibrancy_darkness = 0.0
    }

    # Time (Large)
    label {
      monitor =
      text = $TIME
      color = rgba(242, 243, 244, 0.75)
      font_size = 95
      font_family = JetBrains Mono Nerd Font ExtraBold
      position = 0, 200
      halign = center
      valign = center
    }

    # Date
    label {
      monitor =
      text = cmd[update:1000] echo "$(date +"%A, %d %B")"
      color = rgba(242, 243, 244, 0.75)
      font_size = 22
      font_family = JetBrains Mono Nerd Font
      position = 0, 120
      halign = center
      valign = center
    }

    # User Label
    label {
      monitor =
      text = Hello, $USER
      color = rgba(242, 243, 244, 0.75)
      font_size = 18
      font_family = JetBrains Mono Nerd Font
      position = 0, -50
      halign = center
      valign = center
    }

    input-field {
      monitor =
      size = 280, 60
      outline_thickness = 2
      dots_size = 0.2
      dots_spacing = 0.2
      dots_center = true
      outer_color = rgba(0, 0, 0, 0)
      inner_color = rgba(242, 243, 244, 0.1)
      font_color = rgb(242, 243, 244)
      fade_on_empty = false
      placeholder_text = <i><span foreground="##f2f3f4e6">Unlock Session</span></i>
      hide_input = false
      check_color = rgba(204, 136, 34, 0)
      fail_color = rgba(204, 34, 34, 0.1)
      position = 0, -120
      halign = center
      valign = center
    }
  '';

  # Required for hyprlock to work on NixOS
  security.pam.services.hyprlock = {};

  # Start hypridle on login
  systemd.user.services.hypridle = {
    description = "Hypridle idle daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Environment = [ "PATH=/run/current-system/sw/bin" ];
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}

