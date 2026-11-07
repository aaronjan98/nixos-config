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
    };
  };
}
