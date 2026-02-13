{ pkgs, config, ... }:

let
  keyPath = config.sops.secrets."obsidian/api_key".path;
  
  port = "27123";

  obsidian-remote = pkgs.writeShellScriptBin "obsidian-remote" ''
    export PATH=$PATH:${pkgs.curl}/bin:${pkgs.libnotify}/bin:${pkgs.jq}/bin

    # --- READ THE SECRET AT RUNTIME ---
    if [ ! -f "${keyPath}" ]; then
        notify-send -u critical "Obsidian Error" "API Key secret not found!"
        exit 1
    fi
    API_KEY=$(cat "${keyPath}")
    # ----------------------------------

    URL="http://127.0.0.1:${port}"
    HEADER="Authorization: Bearer $API_KEY"

    # 1. Test Connection
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "$HEADER" --connect-timeout 0.5 "$URL/")

    if [ "$HTTP_STATUS" == "000" ]; then
      notify-send "Obsidian" "App not running. Launching..."
      ${pkgs.obsidian}/bin/obsidian &
      exit 0
    elif [ "$HTTP_STATUS" == "401" ]; then
      notify-send -u critical "Obsidian Error" "API Key is incorrect."
      exit 1
    fi

    CMD="$1"
    NOTE_NAME="$2"

    if [ "$CMD" == "new-window" ]; then
       curl -X POST "$URL/commands/workspace:new-window" -H "$HEADER" -s > /dev/null
    elif [ "$CMD" == "open-note" ]; then
       curl -X POST "$URL/commands/workspace:new-window" -H "$HEADER" -s > /dev/null
       sleep 0.5
       ENCODED_NOTE=$(echo "$NOTE_NAME" | jq -sRr @uri)
       curl -X POST "$URL/open/$ENCODED_NOTE" -H "$HEADER" -s > /dev/null
    else
       curl -X POST "$URL/commands/workspace:new-window" -H "$HEADER" -s > /dev/null
    fi
  '';

  obsidian-desktop = pkgs.makeDesktopItem {
    name = "obsidian-ipc";
    desktopName = "Obsidian (Smart)";
    exec = "${obsidian-remote}/bin/obsidian-remote new-window";
    icon = "obsidian";
    categories = [ "Office" ];
    terminal = false;
  };
in
{
  sops.secrets."obsidian/api_key" = {
    sopsFile = ../secrets/obsidian.yaml;
    format = "yaml";
    key = "obsidian_key";
    owner = "aj";
  };

  environment.systemPackages = [ 
    obsidian-remote 
    obsidian-desktop
    pkgs.curl
    pkgs.libnotify
    pkgs.jq
  ];
}
