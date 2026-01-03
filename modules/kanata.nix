{ config, ... }:

{
  services.kanata = {
    enable = true;

    keyboards.internal = {
      devices = [
        "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
      ];

      # The host points to the deployed file under /etc
      configFile = "/etc/kanata/kanata-internal.kbd";
    };
  };
}
