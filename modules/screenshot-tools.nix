{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    grim
    slurp

    (writeShellScriptBin "shot-region-save" ''
      set -euo pipefail
    
      dir="$HOME/Pictures/screenshots"
      mkdir -p "$dir"
    
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
    
      geom="$(slurp -b '#00000000' -s '#E6260044' -c '#E62600FF' -w 2)"
      grim -g "$geom" "$file"
    
      echo "Saved: $file"
    '')
  ];
}

