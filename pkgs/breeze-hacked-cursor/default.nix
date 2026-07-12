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
    from copy import deepcopy
    import xml.etree.ElementTree as ET
    import re

    svg = Path("src/cursors.svg")
    namespaces = []
    for _, ns in ET.iterparse(svg, events=("start-ns",)):
        if ns not in namespaces:
            namespaces.append(ns)
    for prefix, uri in namespaces:
        ET.register_namespace(prefix, uri)

    # The upstream theme uses separate semi-transparent base shapes underneath
    # the accent shapes. Hide those filled bases, add a light halo behind each
    # accent shape for dark-background contrast, then stroke the accent shape
    # itself in black so the border follows the visible red body.
    def upsert(style, key, value):
        if re.search(rf"(^|;){re.escape(key)}:", style):
            return re.sub(rf"(^|;){re.escape(key)}:[^;]*", lambda m: f"{m.group(1)}{key}:{value}", style)
        return f"{style};{key}:{value}"

    def hide_base_style(style):
        if "fill:#192629" in style:
            style = re.sub(r"opacity:[^;]+", "opacity:0", style)
            style = re.sub(r"fill-opacity:[^;]+", "fill-opacity:0", style)
            style = style.replace("fill:#192629", "fill:#000000")

        if "fill:#000000" in style and "filter:url" in style:
            style = re.sub(r"opacity:[^;]+", "opacity:0", style)
            style = re.sub(r"fill-opacity:[^;]+", "fill-opacity:0", style)
        return style

    def accent_style(style):
        if "fill:#E62600" in style:
            style = upsert(style, "stroke", "#000000")
            style = upsert(style, "stroke-width", "0.8")
            style = upsert(style, "stroke-linejoin", "round")
            style = upsert(style, "stroke-linecap", "round")
            style = upsert(style, "paint-order", "stroke fill markers")
        return style

    def halo_style(style):
        style = upsert(style, "fill", "none")
        style = upsert(style, "fill-opacity", "0")
        style = upsert(style, "stroke", "#f2f0e8")
        style = upsert(style, "stroke-opacity", "0.95")
        style = upsert(style, "stroke-width", "1.45")
        style = upsert(style, "stroke-linejoin", "round")
        style = upsert(style, "stroke-linecap", "round")
        style = upsert(style, "paint-order", "stroke fill markers")
        return style

    tree = ET.parse(svg)
    root = tree.getroot()

    for parent in root.iter():
        children = list(parent)
        inserts = []
        for index, child in enumerate(children):
            style = child.get("style")
            if not style:
                continue

            child.set("style", hide_base_style(style))
            style = child.get("style")

            if "fill:#E62600" in style:
                halo = deepcopy(child)
                halo.set("style", halo_style(style))
                halo.set("id", f"{child.get('id', 'cursor-shape')}-halo")
                child.set("style", accent_style(style))
                inserts.append((index, halo))

        for offset, (index, halo) in enumerate(inserts):
            parent.insert(index + offset, halo)

    tree.write(svg, encoding="utf-8", xml_declaration=True)
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
