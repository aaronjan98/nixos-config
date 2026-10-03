{ config, lib, pkgs, ... }:

let
  cfg = config.aj.hyprIdle;

  # TEMP DIAGNOSTIC (2026-09-29): `logger -t wake-diag` calls below, and the
  # early-exit guard in blackoutOn, target a reported bug where the screen
  # doesn't return to its pre-suspend brightness. Root cause: blackout-on
  # was NOT idempotent — every call re-read "current" brightness and saved
  # it as the restore target, then zeroed it. Two independent triggers call
  # blackout-on (the 5-min idle listener below, and lid-close via
  # lock-and-suspend/before_sleep_cmd) and share the same state_dir, so idle
  # dimming the screen and *then* closing the lid made the lid-close call
  # capture 0% (already dimmed by the idle call) and clobber the real value.
  # The guard below makes repeat calls a no-op instead of re-capturing.
  # Revert the logging once confirmed; keep the idempotency guard.
  blackoutOn = pkgs.writeShellScriptBin "screen-blackout-on" ''
    #!/usr/bin/env bash
    set -eu

    uid="$(id -u)"
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
    state_dir="$runtime/screen-blackout"
    mkdir -p "$state_dir"

    if [ -f "$state_dir/current" ]; then
      logger -t wake-diag "screen-blackout-on: already blacked out, skipping re-capture (would have clobbered saved brightness) @ $(date +%s.%3N)"
      exit 0
    fi

    if command -v brightnessctl >/dev/null 2>&1; then
      # Screen brightness
      line="$(brightnessctl -m | head -n1 || true)"
      dev="$(printf '%s' "$line" | cut -d, -f1)"
      cur="$(printf '%s' "$line" | cut -d, -f4)"

      printf '%s\n' "$dev" > "$state_dir/device" || true
      printf '%s\n' "$cur" > "$state_dir/current" || true
      logger -t wake-diag "screen-blackout-on: captured dev=$dev current=$cur @ $(date +%s.%3N)"
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
        logger -t wake-diag "screen-blackout-off: restoring dev=$dev to current=$cur @ $(date +%s.%3N)"
        brightnessctl -d "$dev" set "$cur" >/dev/null 2>&1
      else
        logger -t wake-diag "screen-blackout-off: no saved state, falling back to 40% @ $(date +%s.%3N)"
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

  # Hard input-idle backstop, independent of the PipeWire idle inhibitor.
  #
  # The 5-min hypridle blackout above is audio-aware on purpose: the
  # wayland-pipewire-idle-inhibit service holds a Wayland idle inhibitor while
  # sound plays, which freezes *every* hypridle timer so music/video isn't cut
  # mid-playback. The downside is that anything holding an audio stream open —
  # a Discord (Vesktop) voice channel, an autoplaying tab — pins idle forever
  # and the desk speakers never get turned off. This watchdog closes that hole:
  # it watches raw HID input via libinput (which the inhibitor cannot suppress)
  # and runs a command after inputCutoffSecs of genuinely no keyboard/mouse/touch
  # activity, regardless of audio. aj is in the `input` group, so it runs as the
  # user (no root) and its command inherits the user's HOME/env (speakers.sh
  # reads the HA token from ~/.../orchestrator/.env).
  enableInputCutoff = cfg.inputCutoffSecs > 0 && cfg.inputCutoffCmd != "";

  inputIdleCutoff = pkgs.writeShellScriptBin "input-idle-cutoff" ''
    #!/usr/bin/env bash
    set -u

    cutoff="''${INPUT_CUTOFF_SECS:?input-idle-cutoff: INPUT_CUTOFF_SECS unset}"
    cmd="''${INPUT_CUTOFF_CMD:?input-idle-cutoff: INPUT_CUTOFF_CMD unset}"

    last=$(date +%s)
    fired=0

    # Line-buffer libinput so each event is seen promptly; process substitution
    # keeps the loop in this shell so `last`/`fired` persist. `read -t` returns
    # >128 on timeout (no input this window) and 1 on EOF (libinput died -> exit
    # non-zero so systemd restarts us).
    exec 3< <(stdbuf -oL libinput debug-events 2>/dev/null)
    while :; do
      IFS= read -r -t 15 -u 3 _line; rc=$?
      if [ "$rc" -eq 0 ]; then
        last=$(date +%s); fired=0
      elif [ "$rc" -gt 128 ]; then
        now=$(date +%s)
        if [ "$fired" -eq 0 ] && [ $(( now - last )) -ge "$cutoff" ]; then
          eval "$cmd" || true
          fired=1
        fi
      else
        exit 1
      fi
    done
  '';
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
    inputCutoffSecs = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = ''
        Hard backstop: if > 0, run inputCutoffCmd after this many seconds with no
        keyboard/mouse/touch input — regardless of whether audio is playing. The
        audio-aware 5-min blackout can't cover this case because the PipeWire idle
        inhibitor freezes hypridle during playback, so a Discord voice call or an
        autoplaying tab would otherwise keep the desk speakers on all day. Watches
        libinput directly (immune to the inhibitor). 0 disables it (default), so
        hosts that leave it unset (ThinkPad) get no watchdog and no libinput dep.
      '';
    };
    inputCutoffCmd = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Command run (as the user) once inputCutoffSecs elapses with no input —
        typically the desk-speakers-off command. Ignored unless inputCutoffSecs > 0.
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
  ] ++ lib.optionals enableInputCutoff [ inputIdleCutoff pkgs.libinput ];

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
      # lock, which lost the race with suspend ("yeeten"). We've since gone back
      # to the see-through `screenshot` background; the race is held off instead
      # by (a) framework-13 never suspending, and (b) the ThinkPad's
      # lock-and-suspend locking while awake + settling before suspend. As a
      # further belt-and-braces we hold suspend off here until hyprlock is
      # actually running (bounded by InhibitDelayMaxSec below).
      #
      # On the thinkpad, `lock-and-suspend` (lid-close bind) already blackouts
      # and locks before calling `systemctl suspend` — which itself triggers
      # this same before_sleep_cmd via logind's PrepareForSleep signal. Without
      # the `pidof hyprlock ||` guard, that path always ran screen-blackout-on
      # and loginctl lock-session a second time for no reason. The guard keeps
      # this as the general safety net for every OTHER suspend path (manual
      # `systemctl suspend`, low battery, etc.) while skipping the redundant
      # work when hyprlock is already up. The wait loop still always runs so
      # suspend stays held off until hyprlock is confirmed running.
      # TEMP DIAGNOSTIC (2026-09-29): `logger -t wake-diag` markers bracket
      # before/after-sleep timing so a slow/missed-keypress wake can be
      # correlated against lock-and-suspend's own markers and kanata's
      # --debug key-event log (modules/kanata.nix). Revert once resolved.
      before_sleep_cmd = logger -t wake-diag "hypridle before_sleep_cmd start @ $(date +%s.%3N)"; pidof hyprlock >/dev/null 2>&1 || { /run/current-system/sw/bin/screen-blackout-on; loginctl lock-session; }; for i in $(seq 1 50); do pidof hyprlock >/dev/null 2>&1 && break; sleep 0.1; done; logger -t wake-diag "hypridle before_sleep_cmd done @ $(date +%s.%3N)"
      after_sleep_cmd = logger -t wake-diag "hypridle after_sleep_cmd start @ $(date +%s.%3N)"; hyprctl dispatch dpms on; /run/current-system/sw/bin/screen-blackout-off; logger -t wake-diag "hypridle after_sleep_cmd done @ $(date +%s.%3N)"
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
      # See-through lock: `screenshot` grabs the live desktop and the blur +
      # overlay below dim it, so you see what's behind the lock rather than a
      # static wallpaper. (It was briefly a static image because `screenshot`
      # makes hyprlock wait on a wlr-screencopy of every output — ~10s with the
      # Framework's external monitor — before it can acquire the session lock,
      # and a suspend landing in that window got hyprlock "yeeten" and showed
      # Hyprland's "lockscreen app died" screen.) Why it's safe to use again:
      #   - framework-13 never suspends (logind ignores idle/lid/suspend), so its
      #     lock only ever fires from idle timers — nothing races the copy.
      #   - thinkpad-t14 suspends on lid, but lock-and-suspend now LOCKS while the
      #     compositor is fully awake and settles before calling suspend
      #     (hosts/thinkpad-t14/configuration.nix), so the copy finishes first.
      # If "lockscreen app died" ever returns on the ThinkPad, lengthen that
      # settle, or pre-capture with grim to a file and point `path` at it (static
      # load, screencopy moved out of the lock critical path).
      path = screenshot
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

  # Input-idle backstop (see inputIdleCutoff above). Runs as the user so it can
  # read /dev/input via the `input` group and so its command inherits the user's
  # HOME/env. Only created when a host opts in with inputCutoffSecs/Cmd.
  systemd.user.services.input-idle-cutoff = lib.mkIf enableInputCutoff {
    description = "Fire a command after prolonged input-idle, regardless of audio";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Environment = [
        "PATH=/run/current-system/sw/bin"
        "INPUT_CUTOFF_SECS=${toString cfg.inputCutoffSecs}"
        "INPUT_CUTOFF_CMD=${cfg.inputCutoffCmd}"
      ];
      ExecStart = "${inputIdleCutoff}/bin/input-idle-cutoff";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
  };
}

