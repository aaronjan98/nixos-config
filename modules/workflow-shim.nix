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
      #
      # LoadCredential is per-service, so this list is what the *shim* holds,
      # not what any workflow sees. main.py re-stages a per-run subset into
      # RuntimeDirectory from each WORKFLOW.md's `credentials:` field, so a
      # workflow gets only what it declared — and for a per-caller name like
      # nextcloud-{nextcloud}-app-password, only the requester's own. Adding a
      # credential here therefore widens what the shim can delegate, never what
      # an existing workflow can read.
      LoadCredential = [
        "openwebui-identity-secret:/var/lib/voice-assistant/openwebui-identity-secret"
        # Per-account Nextcloud app passwords. scripts/nextcloud-upload.sh picks
        # between them from NC_USER, which is how the `downloads` workflow files
        # a download into the requester's own cloud rather than one fixed one.
        "nextcloud-dj-app-password:/var/lib/voice-assistant/nextcloud-dj-app-password"
        "nextcloud-aj-app-password:/var/lib/voice-assistant/nextcloud-aj-app-password"
        "nextcloud-mj-app-password:/var/lib/voice-assistant/nextcloud-mj-app-password"
        # Seerr owns movies and shows (and with them the Radarr/Sonarr routing,
        # quality profiles and the per-requester "now available" email); Lidarr
        # owns music. Both for the `downloads` workflow.
        "seerr-api-key:/var/lib/voice-assistant/seerr-api-key"
        "lidarr-api-key:/var/lib/voice-assistant/lidarr-api-key"
        # Bindery — books and audiobooks. Its grabs are delivered by
        # qBittorrent's finish-hook, so a request only has to reach Bindery.
        "bindery-api-key:/var/lib/voice-assistant/bindery-api-key"
        "vizio-kodi-password:/var/lib/voice-assistant/vizio-kodi-password"
        "firestick-kodi-password:/var/lib/voice-assistant/firestick-kodi-password"
        "jellyfin-credential:/var/lib/voice-assistant/jellyfin-credential"
      ];

      # tmpfs under /run, owned by the service user and wiped when it stops.
      # main.py stages each run's declared credentials into a 0700 subdirectory
      # here and points that run's $CREDENTIALS_DIRECTORY at it, so a workflow
      # sees only the credentials its WORKFLOW.md asked for — and, where the
      # name is per-caller, only the requester's own. Secrets must not land on
      # disk for that, hence a RuntimeDirectory rather than the state dir.
      RuntimeDirectory = "workflow-shim";
      RuntimeDirectoryMode = "0700";

      # `claude` lives on the system path, and the agent's own tool calls
      # inherit this PATH.
      Environment = "PATH=/run/current-system/sw/bin";

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
