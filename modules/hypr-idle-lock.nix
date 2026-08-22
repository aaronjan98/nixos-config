{ config, lib, pkgs, ... }:

let
  cfg = config.aj.hyprIdle;

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

  # The 5-min blackout command, plus any host-specific extras (e.g. cut the desk
  # speakers on the Framework). Empty extras => byte-identical to plain blackout,
  # so hosts that set nothing (ThinkPad) are unaffected.
  blackoutCmd = "/run/current-system/sw/bin/screen-blackout-on"
    + lib.optionalString (cfg.extraBlackoutCmd != "") " ; ${cfg.extraBlackoutCmd}";
  unblackoutCmd = "/run/current-system/sw/bin/screen-blackout-off"
    + lib.optionalString (cfg.extraResumeCmd != "") " ; ${cfg.extraResumeCmd}";
in
{
  options.aj.hyprIdle = {
    extraBlackoutCmd = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Extra shell command run (as the user, via hypridle) when the 5-minute
        idle blackout fires and no media is playing — e.g. turn the desk
        speakers off. Empty on hosts with nothing to add.
      '';
    };
    extraResumeCmd = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Extra shell command run when the blackout is lifted (screen un-blanks),
        e.g. turn the desk speakers back on. Empty leaves resume unchanged.
      '';
    };
  };

  config = {
  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    brightnessctl
    playerctl
    wayland-pipewire-idle-inhibit
    blackoutOn
    blackoutOff
  ];

  # System-wide hypridle config
  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
      lock_cmd = pidof hyprlock || /run/current-system/sw/bin/hyprlock
      # Lock BEFORE suspend, so the machine always wakes already locked — no
      # window where the desktop is visible/typeable before the lock appears.
      #
      # The "lockscreen app died" death screen was NOT caused by locking before
      # sleep; it was the `screenshot` background (see hyprlock.conf below) making
      # hyprlock wait ~10s on a wlr-screencopy before it could grab the session
      # lock, which lost the race with suspend ("yeeten"). With a static-image
      # background hyprlock acquires the lock in milliseconds. As belt-and-braces
      # we also hold suspend off until hyprlock is actually running (bounded by
      # InhibitDelayMaxSec below), so it can never suspend mid-lock.
      before_sleep_cmd = /run/current-system/sw/bin/screen-blackout-on; loginctl lock-session; for i in $(seq 1 50); do pidof hyprlock >/dev/null 2>&1 && break; sleep 0.1; done
      after_sleep_cmd = hyprctl dispatch dpms on; /run/current-system/sw/bin/screen-blackout-off
    }
  
    # Idle is inhibited at the compositor level while audio is actually playing
    # through PipeWire (see the wayland-pipewire-idle-inhibit user service below),
    # so these timers no longer need to poll `playerctl`. The old
    # `playerctl status | grep Playing ||` guard was evaluated only at the instant
    # each timeout crossed and never retried — so if music was playing then and
    # ended later with no further input, the stage stayed latched-off and the
    # machine never idled. The inhibitor releases the moment sound stops, letting
    # these fire normally on the next crossing.

    # 5 mins: Screensaver (Blackout)
    listener {
      timeout = 300
      on-timeout = ${blackoutCmd}
      on-resume = ${unblackoutCmd}
    }

    # 10 mins: Lock Screen
    listener {
      timeout = 600
      on-timeout = loginctl lock-session
    }

    # 15 mins: Turn off display (DPMS)
    listener {
      timeout = 900
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }
  '';

  # System-wide hyprlock config
  environment.etc."xdg/hypr/hyprlock.conf".text = ''
    animations {
      enabled = true
      bezier = linear, 1, 1, 0, 0
      animation = fadeIn, 1, 5, linear
      animation = fadeOut, 1, 5, linear
      animation = inputFieldFade, 1, 5, linear
    }

    background {
      monitor =
      # Static wallpaper, NOT `path = screenshot`. `screenshot` makes hyprlock
      # wait on a wlr-screencopy of every output (~10s with panel + external
      # monitor) before it can acquire the session lock. That race — whether
      # locking before suspend OR on wake — is what caused hyprlock to get
      # "yeeten" and Hyprland to show its "lockscreen app died" screen. A static
      # image loads instantly, so the lock is up before suspend proceeds. Blur
      # and effects below still apply to the image.
      path = /home/aj/Pictures/Wallpapers/current.png
      color = rgba(25, 20, 20, 0.45)

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

  # Headroom so logind waits for the before-sleep lock to fully engage before
  # suspending. Its default delay-inhibitor cap (~5s) could let the system
  # suspend while hyprlock was still acquiring the session lock, racing it into
  # the "lockscreen app died" state.
  services.logind.settings.Login.InhibitDelayMaxSec = "20s";

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

  # Hold a Wayland idle inhibitor while sound is actually playing through
  # PipeWire, so hypridle's timers above stay paused during playback and resume
  # the instant audio stops. Replaces the old per-listener `playerctl` guard,
  # which latched off when playback outlasted the idle thresholds. Only media
  # longer than 5s (the tool's default) inhibits, so notification dings don't
  # keep the screen awake. Mirrors the hypridle user service so it inherits the
  # same session Wayland env.
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    description = "Inhibit Wayland idle while audio plays through PipeWire";
    wantedBy = [ "default.target" ];
    after = [ "pipewire.service" ];
    serviceConfig = {
      Environment = [ "PATH=/run/current-system/sw/bin" ];
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit --wayland";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
  };
}

