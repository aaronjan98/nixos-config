{ pkgs, ... }:

# RStudio on NixOS runs as a single-instance Electron app, and its built-in
# "Open Project in New Session" is broken in this build: it relaunches the bare
# `electron` binary WITHOUT the RStudio app-resources path, so you get an empty
# Electron welcome window instead of a new session.
#
# The reliable way to get a second, fully isolated session is to invoke the
# `rstudio` wrapper directly with a project file:
#
#     rstudio /path/to/project.Rproj
#
# That launches `electron <app> <project.Rproj>`, which spins up its own rsession
# on its own port alongside any existing window. This module wraps that in a
# fuzzel picker (mirroring the Obsidian "Spawn Window" launcher).

let
  rstudio-project = pkgs.writeShellScriptBin "rstudio-project" ''
    set -euo pipefail
    export PATH=$PATH:${pkgs.lib.makeBinPath [
      pkgs.fuzzel
      pkgs.findutils
      pkgs.coreutils
      pkgs.libnotify
    ]}

    # Where to look for RStudio projects.
    roots=("$HOME/Documents" "$HOME/Repositories")

    # Collect *.Rproj files, pruning heavy directories.
    mapfile -t projs < <(
      find "''${roots[@]}" \
        \( -name .git -o -name node_modules -o -name .direnv \) -prune -o \
        -type f -name '*.Rproj' -print 2>/dev/null | sort
    )

    if [ "''${#projs[@]}" -eq 0 ]; then
      notify-send "RStudio" "No .Rproj files found under Documents or Repositories."
      exit 0
    fi

    # Build a pretty label -> path map (label = project directory name).
    declare -A MAP
    labels=()
    for p in "''${projs[@]}"; do
      dir="$(dirname "$p")"
      label="$(basename "$dir")"
      # Disambiguate duplicate project names by their parent directory.
      if [ -n "''${MAP[$label]:-}" ]; then
        label="$label ($(basename "$(dirname "$dir")"))"
      fi
      MAP["$label"]="$p"
      labels+=("$label")
    done

    # Route through the host-scaled fuzzel wrapper so the popup matches the
    # Super+Space menu / emoji picker size (fuzzel.ini is tuned for HiDPI and
    # renders oversized on the 1080p host). Fall back to raw fuzzel if absent.
    picker=(fuzzel)
    fz="$HOME/.config/hypr/scripts/fz"
    [ -x "$fz" ] && picker=("$fz")

    choice="$(printf '%s\n' "''${labels[@]}" | "''${picker[@]}" --dmenu --prompt 'RStudio project: ')"
    [ -z "''${choice:-}" ] && exit 0

    target="''${MAP[$choice]:-}"
    if [ -z "$target" ]; then
      notify-send "RStudio" "No project matched \"$choice\"."
      exit 1
    fi

    # Detach so the launcher can exit; each invocation is its own isolated session.
    setsid rstudio "$target" </dev/null >/dev/null 2>&1 &
  '';

  rstudio-project-desktop = pkgs.makeDesktopItem {
    name = "rstudio-project";
    desktopName = "RStudio (Project Picker)";
    exec = "${rstudio-project}/bin/rstudio-project";
    icon = "rstudio";
    categories = [ "Development" ];
    terminal = false;
  };
in
{
  environment.systemPackages = [
    rstudio-project
    rstudio-project-desktop
  ];
}
