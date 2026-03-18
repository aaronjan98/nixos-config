{ pkgs, config, ... }:

let
  # --- CONFIGURATION ---
  keyPath = config.sops.secrets."obsidian/api_key".path;
  port = "27123";

  # 1. THE RENAMED PRIMARY LAUNCHER
  # This creates a copy of the Obsidian package with a modified .desktop name
  obsidian-renamed = pkgs.symlinkJoin {
    name = "obsidian-renamed";
    paths = [ pkgs.obsidian ];
    postBuild = ''
      # load the 'wrapProgram' function into the builder
      source "${pkgs.makeWrapper}/nix-support/setup-hook"

      # Remove the symlink to the read-only desktop file
      rm $out/share/applications/obsidian.desktop
      
      # Copy the original file so we can edit it
      cp ${pkgs.obsidian}/share/applications/obsidian.desktop $out/share/applications/obsidian.desktop
      
      # Use sed to replace 'Name=Obsidian' with your preferred name
      sed -i 's/^Name=Obsidian$/Name=Obsidian (Vault Picker)/' $out/share/applications/obsidian.desktop

      # This wraps the binary so that whenever Obsidian runs, it has python3 and basic shell tools in its $PATH.
      wrapProgram $out/bin/obsidian \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 pkgs.bash pkgs.coreutils ]}
    '';
  };

  # 2. THE SMART IPC SCRIPT
  obsidian-remote = pkgs.writeShellScriptBin "obsidian-remote" ''
    export PATH=$PATH:${pkgs.curl}/bin:${pkgs.libnotify}/bin:${pkgs.jq}/bin

    if [ ! -f "${keyPath}" ]; then
        notify-send -u critical "Obsidian Error" "API Key secret not found!"
        exit 1
    fi
    API_KEY=$(cat "${keyPath}")

    URL="http://127.0.0.1:${port}"
    HEADER="Authorization: Bearer $API_KEY"
    
    # Check status
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "$HEADER" --connect-timeout 0.5 "$URL/")

    if [ "$HTTP_STATUS" == "000" ]; then
      notify-send "Obsidian" "App not running. Launching..."
      # Use our renamed package binary
      ${obsidian-renamed}/bin/obsidian &
      exit 0
    elif [ "$HTTP_STATUS" == "401" ]; then
      notify-send -u critical "Obsidian Error" "API Key is incorrect."
      exit 1
    fi

    # Commands
    CMD="$1"
    NOTE_NAME="$2"
    WINDOW_CMD="workspace:new-window"

    if [ "$CMD" == "new-window" ]; then
       curl -X POST "$URL/commands/$WINDOW_CMD" -H "$HEADER" -s > /dev/null
    elif [ "$CMD" == "open-note" ]; then
       curl -X POST "$URL/commands/$WINDOW_CMD" -H "$HEADER" -s > /dev/null
       sleep 0.5
       ENCODED_NOTE=$(echo "$NOTE_NAME" | jq -sRr @uri)
       curl -X POST "$URL/open/$ENCODED_NOTE" -H "$HEADER" -s > /dev/null
    else
       curl -X POST "$URL/commands/$WINDOW_CMD" -H "$HEADER" -s > /dev/null
    fi
  '';

  # 3. THE SMART LAUNCHER ENTRY
  obsidian-smart-desktop = pkgs.makeDesktopItem {
    name = "obsidian-ipc";
    desktopName = "Obsidian (Spawn Window)";
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
    # Use our renamed package INSTEAD of pkgs.obsidian
    obsidian-renamed 
    
    obsidian-remote 
    obsidian-smart-desktop
    
    pkgs.curl
    pkgs.libnotify
    pkgs.jq
  ];
}
