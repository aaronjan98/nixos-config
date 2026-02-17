{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;

    # Leave on default port 11434
    host = "127.0.0.1";
    port = 11434;

    #package = pkgs.ollama-cpu;
    package = pkgs.ollama-vulkan;

    loadModels = [
      "qwen3:4b"
      "deepseek-r1:1.5b"
    ];
  };

  services.open-webui = {
    enable = true;

    # Serve UI on 5050
    host = "0.0.0.0";  # fixes IPv6 localhost issue
    port = 5050;

    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  systemd.services.ollama.serviceConfig.Environment = [
    "OLLAMA_KEEP_ALIVE=30s"
  ];
}

