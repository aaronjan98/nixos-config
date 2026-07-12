{ config, pkgs, lib, ... }:

let
  orchestratorConversation = pkgs.stdenvNoCC.mkDerivation {
    name = "orchestrator-conversation";
    src = ./ha-custom-components;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r orchestrator_conversation $out/
    '';
  };
in {
  services.home-assistant = {
    enable = true;
    openFirewall = true;

    extraComponents = [
      "esphome"              # auto-discovers ESPHome satellites on the LAN
      "wyoming"              # voice pipeline bridge to Whisper + Piper
      "assist_pipeline"
      "wake_word"
      "openai_conversation"
      "ollama"
      "google_generative_ai_conversation"  # native Gemini integration
      "met"                  # built-in weather provider
      "radio_browser"
    ];

    extraPackages = ps: [ ps.ollama ];

    customComponents = [ orchestratorConversation ];

    config = {
      homeassistant = {
        name = "Home";
        unit_system = "us_customary";
        time_zone = "America/Los_Angeles";
        currency = "USD";
      };
      default_config = {};
      http = {
        server_port = 8123;
      };
    };
  };

  # Wyoming Faster-Whisper — speech-to-text
  services.wyoming.faster-whisper.servers."en-us" = {
    enable = true;
    model = "small-int8";
    language = "en";
    uri = "tcp://127.0.0.1:10300";
    device = "cpu";
  };

  # Wyoming Piper — text-to-speech
  services.wyoming.piper.servers."en-us" = {
    enable = true;
    voice = "en_US-lessac-medium";
    uri = "tcp://127.0.0.1:10200";
  };
}
