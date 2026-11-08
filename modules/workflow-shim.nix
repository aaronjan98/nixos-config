{ config, pkgs, lib, ... }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.pyyaml       # WORKFLOW.md frontmatter
  ]);
  repoDir = "/home/aj/Repositories/projects/voice-assistant/workflow-shim";
in {
  # OpenAI-compatible front end for Claude Code workflows, so Open WebUI's
  # model picker becomes a workflow picker. See workflow-shim/main.py for the
  # design and workflows/<name>/WORKFLOW.md for each workflow's scope.
  systemd.services.workflow-shim = {
    description = "Claude Workflow Shim (OpenAI-compatible)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${python}/bin/uvicorn main:app --host 127.0.0.1 --port 8130";
      WorkingDirectory = repoDir;

      # Shares the orchestrator's .env because both resolve the same identities
      # with the same allowlists — TRUSTED_WEBUI_USER_IDS and the HA device ids.
      # Keeping two copies would let them disagree about who is personal tier,
      # which is the kind of divergence nobody notices until it matters.
      EnvironmentFile = "/home/aj/Repositories/projects/voice-assistant/orchestrator/.env";

      # Runs as aj deliberately: it shells out to `claude`, which authenticates
      # with AJ's Claude Code credentials under ~/.claude. A system user would
      # have no subscription to spend and no session history to resume.
      User = "aj";

      # Same secret Open WebUI signs its forwarded user JWT with, so the shim
      # can verify who is asking and scope sessions per person. Provisioned by
      # modules/orchestrator.nix, which owns /var/lib/voice-assistant.
      # The identity secret lets the shim verify who is asking. The three below
      # are what workflows actually need in order to act, and they are here
      # rather than read from pass because pass cannot work in this context:
      # there is no pinentry to answer a passphrase prompt, so `pass show`
      # blocks forever, and a household caller could not unlock AJ's gpg-agent
      # even if there were. Observed as a request that hung until it was killed.
      LoadCredential = [
        "openwebui-identity-secret:/var/lib/voice-assistant/openwebui-identity-secret"
        "nextcloud-dj-app-password:/var/lib/voice-assistant/nextcloud-dj-app-password"
        "vizio-kodi-password:/var/lib/voice-assistant/vizio-kodi-password"
        "firestick-kodi-password:/var/lib/voice-assistant/firestick-kodi-password"
        "jellyfin-credential:/var/lib/voice-assistant/jellyfin-credential"
      ];

      # `claude` lives on the system path, and the agent's own tool calls
      # inherit this PATH.
      Environment = "PATH=/run/current-system/sw/bin";

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
