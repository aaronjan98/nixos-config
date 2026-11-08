{ config, pkgs, lib, pkgsUnstable, ... }:

{
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    package = pkgsUnstable.ollama-vulkan;
    loadModels = [ "qwen3:4b" "deepseek-r1:1.5b" ];
  };

  # mkIf at the top of the attrset, not at the leaf — `a.b.c = mkIf false x`
  # still instantiates the parent submodule with an empty config, which makes
  # systemd see a unit file with no [Service] section ("bad unit file
  # setting"). Wrapping `systemd.services` itself means the whole
  # contribution drops when ollama is disabled (e.g. pentest specialisation).
  systemd.services = lib.mkMerge [
    (lib.mkIf config.services.ollama.enable {
      ollama.serviceConfig.Environment = [ "OLLAMA_KEEP_ALIVE=30s" ];
    })
    # Same mkIf-at-the-top reasoning as above: open-webui is force-disabled in
    # the pentest specialisation, and a leaf mkIf would still instantiate a
    # [Service]-less unit. The JWT signing secret is readable only from the
    # environment, so it arrives as a root-owned EnvironmentFile rather than a
    # systemd credential; both files come from modules/orchestrator.nix.
    (lib.mkIf config.services.open-webui.enable {
      open-webui.serviceConfig.EnvironmentFile =
        [ "/var/lib/voice-assistant/openwebui-identity.env" ];
    })
  ];

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 5050;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      # Forward the logged-in user to the orchestrator Connection as a signed
      # HS256 JWT: header X-OpenWebUI-User-Jwt, iss=open-webui, sub=user id,
      # 300s TTL — the shape orchestrator/identity.py verifies. If the secret
      # is missing Open WebUI silently falls back to plain, unsigned
      # X-OpenWebUI-User-* headers, which the orchestrator ignores, so a
      # misconfiguration fails closed to the restricted tier rather than
      # trusting an unauthenticated identity claim.
      ENABLE_FORWARD_USER_INFO_HEADERS = "true";

      # Show every connection's models to every account, and let the workflow
      # shim decide who may actually *use* one.
      #
      # Open WebUI only applies access grants to rows in its own models table,
      # which base models discovered from a Connection do not have — so the
      # shim's workflows are invisible to non-admins until someone hand-creates
      # a "Workspace model" per workflow in the UI. That would put
      # authorization for these workflows in mutable SQLite state while the
      # workflows themselves live in git: two sources of truth, the weaker one
      # unversionable, and a manual click needed for every workflow added.
      #
      # The shim already enforces authorization on the verified Open WebUI JWT
      # via each WORKFLOW.md's `access:` field, and returns 403 independently of
      # what this UI chooses to display. Visibility is not the boundary, so it
      # is safe to stop pretending it is one.
      #
      # Consequence to keep in mind: this exposes models from *every*
      # connection to everyone. Adding a metered connection later means its
      # models appear in the household's picker too, and the gating for that
      # would have to live somewhere else.
      BYPASS_MODEL_ACCESS_CONTROL = "true";
    };
  };
}
