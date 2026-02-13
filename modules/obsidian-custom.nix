{ pkgs, ... }:

let
  obsidian-smart = pkgs.writeShellScriptBin "obsidian-smart" ''
    if pgrep -x "obsidian" > /dev/null; then
      # Focus Obsidian using hyprctl
      hyprctl dispatch focuswindow obsidian
      sleep 0.1
      # Send your Ctrl+Alt+N hotkey
      ${pkgs.wtype}/bin/wtype -M ctrl -M alt n -m alt -m ctrl
    else
      ${pkgs.obsidian}/bin/obsidian &
    fi
  '';
in
{
  environment.systemPackages = [ obsidian-smart ];

  environment.desktopEntries.obsidian = {
    name = "Obsidian";
    exec = "obsidian-smart";
    icon = "obsidian";
    terminal = false;
    categories = [ "Office" ];
    settings.NoDisplay = "false";
  };
}
