{ config, ... }:

{
  services.kanata = {
    enable = true;

    keyboards.internal = {
      # NOTE: this `devices` list is INERT. The NixOS module only applies it
      # when it generates the config; because we supply a raw `configFile`
      # below, kanata never receives a device restriction from here. The real
      # restriction lives as `linux-dev` in each host's defcfg. Kept for
      # documentation of intent only.
      devices = [
        "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
      ];

      # The host points to the deployed file under /etc
      configFile = "/etc/kanata/kanata-internal.kbd";

      # TCP server for the Quickshell mode island: pushes LayerChange events
      # and accepts ChangeLayer commands. `tcp-port` is NOT a valid `defcfg`
      # directive on this kanata build (confirmed via --check) -- the module's
      # `port` option is the actual mechanism; it's independent of the raw
      # `configFile` above and also handles the systemd hardening (opens
      # IPAddressAllow localhost, disables PrivateNetwork) automatically.
      # See quickshell project-memory/kanata-island.md.
      port = 7979;

      # TEMP DIAGNOSTIC (2026-09-29): --debug logs every physical key
      # press/release kanata receives, with millisecond timestamps, so a
      # suspend/resume-time input lag can be pinned to "kanata received the
      # key late" vs. "kanata forwarded it fine but something downstream
      # (Hyprland/hyprlock) sat on it". See memory/2026-09-29 for the
      # investigation this supports. Revert once resolved — normal operation
      # doesn't need per-keystroke logging.
      extraArgs = [ "--debug" ];
    };
  };
}
