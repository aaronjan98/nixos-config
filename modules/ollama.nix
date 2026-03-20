{ config, pkgs, lib, pkgsUnstable, ... }:

{
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    package = pkgsUnstable.ollama-vulkan;
    loadModels = [ "qwen3:4b" "deepseek-r1:1.5b" ];
  };

  systemd.services.ollama.serviceConfig.Environment = [
    "OLLAMA_KEEP_ALIVE=30s"
  ];

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 5050;
    environment.OLLAMA_BASE_URL = "http://127.0.0.1:11434";
  };
}
