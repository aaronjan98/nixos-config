{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "imgview" ''
      set -euo pipefail

      if [ "$#" -lt 1 ]; then
        echo "usage: imgview <image-or-path> [more...]" >&2
        exit 2
      fi

      # Resolve args to absolute paths when possible (helps Firefox open local files reliably)
      resolved=()
      for p in "$@"; do
        if [ -e "$p" ]; then
          resolved+=("file://$(readlink -f "$p")")
        else
          # allow passing URLs or non-existent paths intentionally
          resolved+=("$p")
        fi
      done

      # Open in a new window and avoid session restore weirdness
      exec firefox --new-window "''${resolved[@]}"
    '')
  ];
}

