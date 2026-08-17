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
    };
  };
}
