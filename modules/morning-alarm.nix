{ config, lib, pkgs, ... }:

# Morning alarm: at a set time, turn the desk speakers on and stream the chosen
# Navidrome album/playlist to them (scripts/play-album.sh -> Subsonic -> mpv).
# Which album/playlist plays is set by MORNING_ALBUM_ID in the orchestrator
# .env (not a Nix option), so it can be changed on the fly without a rebuild.
#
# It is a *system* timer (not a user timer) so it can carry WakeSystem=true:
# that programs an RTC wake, so the alarm fires even if the machine is ever
# suspended. On this always-on server host it's normally just awake, so the
# timer simply fires on schedule — WakeSystem is harmless insurance.
#
# The service body runs as user aj with the session's XDG_RUNTIME_DIR exported,
# so mpv reaches the running PipeWire and plays on the desk speakers — the same
# user-context trick as speakers-suspend-off.nix / sync-leave-preflight.nix.
# Because playback is local to whoever runs it, this module belongs on the
# Framework host only (its audio-out drives the speakers); music.home is just
# the remote library.
#
# mpv runs in the foreground as the unit's main process, so the alarm is a live
# handle: `systemctl stop morning-alarm` cuts the music mid-album.

let
  cfg = config.aj.morningAlarm;
in
{
  options.aj.morningAlarm = {
    enable = lib.mkEnableOption "Morning wake-up alarm (speakers on + Navidrome album)";

    time = lib.mkOption {
      type = lib.types.str;
      default = "07:30";
      example = "06:45";
      description = ''
        Time of day to fire, as the clock part of a systemd OnCalendar
        expression. A bare "HH:MM" means every day at that time.
      '';
    };

    days = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Mon..Fri";
      description = ''
        Optional day-of-week restriction prepended to the time (e.g.
        "Mon..Fri" for weekdays only). Empty = every day.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "aj";
      description = "User whose audio session (PipeWire) the album plays through.";
    };

    wakeScreen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Also wake the display when the alarm fires — undo hypridle's blackout
        and DPMS-off so the screen comes up, not just the audio.
      '';
    };

    speakersScript = lib.mkOption {
      type = lib.types.str;
      default = "/home/aj/nixos-config/scripts/speakers.sh";
      description = "Path to the speakers on/off helper.";
    };

    playScript = lib.mkOption {
      type = lib.types.str;
      default = "/home/aj/nixos-config/scripts/play-album.sh";
      description = "Path to the Navidrome album player.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.morning-alarm = {
      description = "Morning alarm — speakers on + Navidrome album";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = if cfg.days == "" then cfg.time else "${cfg.days} ${cfg.time}";
        WakeSystem = true;
        # Don't fire a missed alarm late (e.g. at boot after the time passed) —
        # an alarm is only useful at its actual moment, not retroactively.
        Persistent = false;
      };
    };

    systemd.services.morning-alarm = {
      description = "Morning alarm — speakers on + Navidrome album";
      # Only the timer (or a manual `systemctl start`) should run this; nothing
      # else should pull it in.
      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = "users";
        # Cap only the pre-step + startup, not playback: mpv (the main process)
        # legitimately runs for the whole album.
        TimeoutStartSec = "30s";
      };
      # Turn the amp on, give it a couple seconds to wake, then exec into mpv so
      # mpv becomes the unit's main PID (clean `systemctl stop` = stop music).
      # XDG_RUNTIME_DIR is resolved from the user's uid at runtime so mpv finds
      # the running PipeWire — mirrors sync-leave-preflight.nix.
      script = ''
        export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"
        export HOME="/home/${cfg.user}"
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        ${lib.optionalString cfg.wakeScreen ''
          # Wake the panel: undo hypridle's blackout + DPMS-off. At alarm time
          # there's no real input to fire hypridle's on-resume, so do it here.
          # Point hyprctl at the running Hyprland instance (single session).
          sig="$(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1 || true)"
          [ -n "$sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          hyprctl dispatch dpms on 2>/dev/null || true
          /run/current-system/sw/bin/screen-blackout-off 2>/dev/null || true
        ''}
        ${cfg.speakersScript} on
        sleep 3
        # No album argument: play-album.sh reads MORNING_ALBUM_ID from the
        # orchestrator .env, so the morning pick can be changed on the fly by
        # editing that one line — no rebuild needed.
        exec ${pkgs.bash}/bin/bash ${cfg.playScript}
      '';
    };
  };
}
