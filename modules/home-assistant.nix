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
    passthru = {
      isHomeAssistantComponent = true;
      domain = "orchestrator_conversation";
    };
  };
in {
  services.home-assistant = {
    enable = true;
    openFirewall = true;

    extraComponents = [
      "esphome"              # auto-discovers ESPHome satellites on the LAN
      "matter"               # local Matter control (KP125M speaker plug, etc.)
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

  # Matter server — local controller the HA "matter" integration connects to
  # (ws://localhost:5580/ws). Lets HA commission and drive Matter devices like
  # the KP125M speaker plug directly on the LAN, bypassing python-kasa (which
  # cannot speak the plug's newer TPAP encryption).
  services.matter-server.enable = true;

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

  # Wyoming Piper — Brazilian Portuguese voice, used by the "Português" Assist
  # pipeline so Portuguese answers are spoken naturally. STT needs no change:
  # the existing small-int8 Whisper is multilingual and advertises pt already.
  services.wyoming.piper.servers."pt-br" = {
    enable = true;
    voice = "pt_BR-faber-medium";
    uri = "tcp://127.0.0.1:10201";
  };
}
