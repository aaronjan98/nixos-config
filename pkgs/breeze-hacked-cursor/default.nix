{ lib
, stdenvNoCC
, fetchFromGitHub
, inkscape
, xorg
, bash
, makeWrapper
, python3
}:

stdenvNoCC.mkDerivation {
  pname = "breeze-hacked-cursor-theme";
  version = "unstable-2026-01-23";

  src = fetchFromGitHub {
    owner = "clayrisser";
    repo = "breeze-hacked-cursor-theme";
    rev = "6b908e82db55e4254edacdbb00c7bff850473272";
    hash = "sha256-Hc3eBDqCi58g0lTjpkZF4F29CAJvibSKffu5VI8Qqlw=";
  };

  nativeBuildInputs = [
    bash
    makeWrapper
    inkscape
    xorg.xcursorgen
    python3
  ];

  postPatch = ''
    chmod +x ./build.py ./recolor-cursor.sh 2>/dev/null || true
    patchShebangs ./build.py ./recolor-cursor.sh 2>/dev/null || true

    # Upstream only builds 24/36/48px assets. Add larger raster sizes so
    # XCURSOR_SIZE/HYPRCURSOR_SIZE=72 can resolve to a real cursor image.
    substituteInPlace ./build.py \
      --replace-fail "scales = [1, 1.5, 2]" "scales = [1, 1.5, 2, 2.5, 3, 4]"
  '';

  preBuild = ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$HOME" "$XDG_CACHE_HOME"
  
    ./recolor-cursor.sh \
      --accent-color "#E62600" \
      --base-color   "#192629" \
      --border-color "#666666" \
      --logo-color   "#E62600"

    python3 - <<'PY'
    from pathlib import Path
    import re

    svg = Path("src/cursors.svg")
    text = svg.read_text()

    # The upstream theme uses separate semi-transparent base shapes underneath
    # the accent shapes. Hide those filled bases and stroke the accent shapes
    # directly so the black border follows the visible red body.
    def rewrite_style(match):
        style = match.group(1)
        if "fill:#192629" in style:
            style = re.sub(r"opacity:[^;]+", "opacity:0", style)
            style = re.sub(r"fill-opacity:[^;]+", "fill-opacity:0", style)
            style = style.replace("fill:#192629", "fill:#000000")

        if "fill:#000000" in style and "filter:url" in style:
            style = re.sub(r"opacity:[^;]+", "opacity:0", style)
            style = re.sub(r"fill-opacity:[^;]+", "fill-opacity:0", style)

        if "fill:#E62600" in style:
            style = style.replace("stroke:none", "stroke:#000000")
            if "stroke:#000000" not in style:
                style += ";stroke:#000000"
            if "stroke-width:" not in style:
                style += ";stroke-width:0.25"
            if "stroke-linejoin:" not in style:
                style += ";stroke-linejoin:round"
            if "stroke-linecap:" not in style:
                style += ";stroke-linecap:round"
            if "paint-order:" not in style:
                style += ";paint-order:stroke fill markers"

        return f'style="{style}"'

    text = re.sub(r'style="([^"]*)"', rewrite_style, text)
    svg.write_text(text)
    PY
  '';

  # Be explicit: build the theme
  buildPhase = ''
    runHook preBuild
    make
    runHook postBuild
  '';

  # Be explicit: install by copying theme dirs into $out/share/icons
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/icons"

    # Copy any built cursor theme directories (cursors/ + index.theme)
    found=0
    for d in ./*; do
      if [ -d "$d" ] && [ -d "$d/cursors" ] && [ -f "$d/index.theme" ]; then
        cp -r "$d" "$out/share/icons/"
        found=1
      fi
    done

    if [ "$found" -ne 1 ]; then
      echo "ERROR: did not find any cursor theme directories (expected a dir with cursors/ and index.theme)."
      echo "Top-level directories:"
      ls -la
      exit 1
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Breeze Hacked cursor theme, recolored during build";
    homepage = "https://github.com/clayrisser/breeze-hacked-cursor-theme";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
