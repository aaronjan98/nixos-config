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

