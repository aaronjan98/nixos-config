{ config, pkgs, lib, ... }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.httpx
    ps.python-dotenv
    ps.python-kasa
  ]);
  repoDir = "/home/aj/Repositories/projects/voice-assistant/orchestrator";
in {
  # adb for the media actuator (bin/kodi-play.sh) — wakes the Fire TV Stick and
  # launches Kodi before issuing JSON-RPC. Installed system-wide so it lands on
  # /run/current-system/sw/bin, which is the orchestrator service's pinned PATH
  # (and thus inherited by the claude -p subprocess that runs the actuator).
  environment.systemPackages = [ pkgs.android-tools ];

  systemd.services.voice-orchestrator = {
    description = "Voice Assistant Orchestrator";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "home-assistant.service" ];

    serviceConfig = {
      ExecStart = "${python}/bin/uvicorn main:app --host 127.0.0.1 --port 8001";
      WorkingDirectory = repoDir;
      EnvironmentFile = "${repoDir}/.env";
      Environment = "PATH=/run/current-system/sw/bin";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "aj";
    };
  };
}
