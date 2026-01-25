{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.cliphist
    pkgs.wl-clipboard
  ];

  systemd.user.services.cliphist-text = {
    description = "Cliphist (text)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
    };
  };

  systemd.user.services.cliphist-image = {
    description = "Cliphist (image)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
    };
  };
}

