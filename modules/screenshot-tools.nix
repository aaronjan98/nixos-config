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

      # Same fuzzel-dismiss race as shot-region-save: wait for the menu to fully leave the compositor.
      sleep 0.08

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

      # Same fuzzel-dismiss race as shot-region-save: wait for the menu to fully leave the compositor.
      sleep 0.08

      grim -o "$mon" "$file"

      echo "Saved: $file"
    '')

    (writeShellScriptBin "shot-menu" ''
      set -euo pipefail

      # Route through the host-scaled fuzzel wrapper so this menu matches the
      # size of every other fuzzel popup (Super+Space launcher, emoji picker,
      # etc.) instead of the raw fuzzel.ini defaults (tuned for the Framework's
      # HiDPI panel, oversized on the ThinkPad's 1080p panel). The wrapper picks
      # size by hostname, not monitor layout, so plugging/unplugging the
      # external display doesn't change which size applies. Falls back to raw
      # fuzzel if the dotfile script isn't present.
      #
      # Also tag this popup with its own layer-shell namespace so a layerrule
      # can kill just its animation (see 40-windowrules.conf) without touching
      # the fade on every other fuzzel popup — that's what left a ghost frame
      # behind in fullscreen shots.
      picker=(fuzzel --namespace=fuzzel-shot)
      fz="$HOME/.config/hypr/scripts/fz"
      [ -x "$fz" ] && picker=("$fz" --namespace=fuzzel-shot)

      choice="$(
        printf "%s\n" \
          "Region → Save" \
          "Fullscreen (all displays) → Save" \
          "Fullscreen (focused display) → Save" \
          "Open screenshots folder" \
        | "''${picker[@]}" --dmenu --prompt "Screenshot: "
      )"

      # User hit Escape / cancelled
      if [ -z "''${choice:-}" ]; then
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

