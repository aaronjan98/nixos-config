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
  systemd.services = lib.mkIf config.services.ollama.enable {
    ollama.serviceConfig.Environment = [ "OLLAMA_KEEP_ALIVE=30s" ];
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 5050;
    environment.OLLAMA_BASE_URL = "http://127.0.0.1:11434";
  };
}
