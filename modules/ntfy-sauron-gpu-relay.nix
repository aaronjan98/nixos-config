{ pkgs, ... }:

# Desktop relay for the Sauron GPU health-check ntfy topic (see
# ocr-api-health-check.service on sauron itself, which publishes to this
# topic exactly once per boot if the GPU doesn't come up in CUDA mode).
# ntfy's own mobile app already delivers the phone-side push; this just
# subscribes from the laptop too and re-emits each message via notify-send,
# so it also shows up in the normal desktop notification panel (Quickshell).

let
  sauronGpuAlertTopic = "sauron-ocr-gpu-da0d70ecace8";

  ntfy-sauron-gpu-relay = pkgs.writeShellApplication {
    name = "ntfy-sauron-gpu-relay";
    runtimeInputs = [ pkgs.ntfy-sh pkgs.libnotify ];
    excludeShellChecks = [ "SC2016" ];
    text = ''
      exec ntfy subscribe ${sauronGpuAlertTopic} \
        'notify-send -u critical "$title" "$message"'
    '';
  };
in
{
  environment.systemPackages = [ pkgs.ntfy-sh ];

  systemd.user.services.ntfy-sauron-gpu-relay = {
    description = "Desktop relay for the Sauron GPU health-check ntfy topic";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${ntfy-sauron-gpu-relay}/bin/ntfy-sauron-gpu-relay";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
