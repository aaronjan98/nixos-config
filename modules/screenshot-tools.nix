{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    grim
    slurp
    fuzzel
    jq

    (writeShellScriptBin "shot-region-save" ''
      set -euo pipefail

      dir="$HOME/Pictures/screenshots"
      mkdir -p "$dir"

      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

      # slurp overlay:
      # - background fully transparent (no grey-out)
      # - selection fill: Ferrari red, very transparent
      # - border: Ferrari red, opaque
      geom="$(slurp -b '#00000000' -s '#E6260022' -c '#E62600FF' -w 2)"

      # IMPORTANT:
      # On wlroots compositors (Hyprland), grim can sometimes capture the slurp overlay
      # if it grabs the frame immediately after slurp finishes. A tiny delay avoids that race.
      sleep 0.08

      grim -g "$geom" "$file"
      echo "Saved: $file"
    '')

    (writeShellScriptBin "shot-full-save" ''
      set -euo pipefail

      dir="$HOME/Pictures/screenshots"
      mkdir -p "$dir"

      file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_full.png"
      grim "$file"

      echo "Saved: $file"
    '')

    (writeShellScriptBin "shot-full-save-monitor" ''
      set -euo pipefail

      dir="$HOME/Pictures/screenshots"
      mkdir -p "$dir"

      # If not running under Hyprland, fall back to full screenshot
      if ! command -v hyprctl >/dev/null 2>&1; then
        exec shot-full-save
      fi

      mon="$(hyprctl activeworkspace -j | jq -r '.monitor // empty' || true)"
      if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        exec shot-full-save
      fi

      file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_$mon.png"
      grim -o "$mon" "$file"

      echo "Saved: $file"
    '')

    (writeShellScriptBin "shot-menu" ''
      set -euo pipefail

      choice="$(
        printf "%s\n" \
          "Region → Save" \
          "Fullscreen (all displays) → Save" \
          "Fullscreen (focused display) → Save" \
          "Open screenshots folder" \
        | fuzzel --dmenu --prompt "Screenshot: "
      )"

      # User hit Escape / cancelled
      if [ -z "${choice:-}" ]; then
        exit 0
      fi

      case "$choice" in
        "Region → Save")
          exec shot-region-save
          ;;
        "Fullscreen (all displays) → Save")
          exec shot-full-save
          ;;
        "Fullscreen (focused display) → Save")
          exec shot-full-save-monitor
          ;;
        "Open screenshots folder")
          exec xdg-open "$HOME/Pictures/screenshots"
          ;;
        *)
          exit 0
          ;;
      esac
    '')
  ];
}

