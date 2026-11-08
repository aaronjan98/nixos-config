{ config, pkgs, lib, ... }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.websockets   # uvicorn's WebSocket server impl — for the browser-player control channel
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

  # Create the HA-to-orchestrator authentication token on the host, never in
  # the Nix store or Git. Preserve the existing token across rebuilds.
  # systemd LoadCredential copies it into each service's private credentials dir.
  system.activationScripts.voiceOrchestratorAuthCredential = ''
    credential_dir=/var/lib/voice-assistant
    credential_file="$credential_dir/ha-orchestrator-token"
    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$credential_dir"
    if [ ! -e "$credential_file" ]; then
      (umask 077; ${pkgs.openssl}/bin/openssl rand -hex 32 > "$credential_file")
    fi
    ${pkgs.coreutils}/bin/chown root:root "$credential_file"
    ${pkgs.coreutils}/bin/chmod 0400 "$credential_file"

    # Shared secret that lets Open WebUI prove the logged-in user to the
    # orchestrator (household-access-spec Phase 3). Provisioned here because
    # this module owns /var/lib/voice-assistant; consumed by modules/ollama.nix.
    # Two shapes of one secret: the raw value for the orchestrator's systemd
    # credential, and a KEY=value EnvironmentFile because Open WebUI reads
    # FORWARD_USER_INFO_HEADER_JWT_SECRET only from the environment. The env
    # file is rewritten from the raw secret every activation so they cannot drift.
    webui_secret="$credential_dir/openwebui-identity-secret"
    webui_env="$credential_dir/openwebui-identity.env"
    if [ ! -e "$webui_secret" ]; then
      (umask 077; ${pkgs.openssl}/bin/openssl rand -hex 32 > "$webui_secret")
    fi
    ${pkgs.coreutils}/bin/chown root:root "$webui_secret"
    ${pkgs.coreutils}/bin/chmod 0400 "$webui_secret"
    (umask 077; ${pkgs.coreutils}/bin/printf 'FORWARD_USER_INFO_HEADER_JWT_SECRET=%s\n' \
      "$(${pkgs.coreutils}/bin/cat "$webui_secret")" > "$webui_env")
    ${pkgs.coreutils}/bin/chown root:root "$webui_env"
    ${pkgs.coreutils}/bin/chmod 0400 "$webui_env"

    # Service credentials for the workflow shim's agents. Unlike the two above
    # these cannot be generated — each must match an external service — so this
    # only guarantees the file exists with the right ownership. Empty
    # placeholders are created deliberately: systemd LoadCredential fails the
    # whole unit when a source file is missing, so an absent secret would take
    # the shim down entirely, whereas an empty one fails just the workflow that
    # needs it, with a message naming the file.
    #
    # pass remains the source of truth; these are deployment copies, the same
    # relationship the HA token already has. Fill them with, e.g.:
    #   pass show homelab/vizio-kodi/kodi | sudo tee /var/lib/voice-assistant/vizio-kodi-password >/dev/null
    for secret in nextcloud-dj-app-password vizio-kodi-password jellyfin-credential; do
      path="$credential_dir/$secret"
      if [ ! -e "$path" ]; then
        (umask 077; : > "$path")
        echo "voice-assistant: $path is an empty placeholder; workflows needing it will fail until it is filled"
      fi
      ${pkgs.coreutils}/bin/chown root:root "$path"
      ${pkgs.coreutils}/bin/chmod 0400 "$path"
    done
  '';

  systemd.services.voice-orchestrator = {
    description = "Voice Assistant Orchestrator";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "home-assistant.service" ];

    serviceConfig = {
      ExecStart = "${python}/bin/uvicorn main:app --host 127.0.0.1 --port 8001";
      WorkingDirectory = repoDir;
      EnvironmentFile = "${repoDir}/.env";
      LoadCredential = [
        "ha-orchestrator-token:/var/lib/voice-assistant/ha-orchestrator-token"
        "openwebui-identity-secret:/var/lib/voice-assistant/openwebui-identity-secret"
      ];
      Environment = "PATH=/run/current-system/sw/bin";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "aj";
    };
  };
}
