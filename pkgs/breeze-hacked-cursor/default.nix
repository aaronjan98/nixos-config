{ lib
, stdenvNoCC
, fetchFromGitHub
, inkscape
, xorg
, bash
, makeWrapper
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "breeze-hacked-cursor-theme";
  version = "unstable-2026-01-23";

  src = fetchFromGitHub {
    owner = "clayrisser";
    repo = "breeze-hacked-cursor-theme";
    # Pin this to a real commit for reproducibility:
    rev = "6b908e82db55e4254edacdbb00c7bff850473272";
    hash = lib.fakeHash; # <- replace after first build
  };

  nativeBuildInputs = [
    bash
    makeWrapper
    inkscape
    xorg.xcursorgen
  ];

  # Inkscape sometimes wants a writable HOME/cache
  preBuild = ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$HOME" "$XDG_CACHE_HOME"

    patchShebangs .

    # Make it RED
    ./recolor-cursor.sh \
      --accent-color "#ff0000" \
      --base-color   "#ffffff" \
      --border-color "#000000" \
      --logo-color   "#ff0000"
  '';

  installPhase = ''
    runHook preInstall
    make install PREFIX=$out
    runHook postInstall
  '';

  meta = with lib; {
    description = "Breeze Hacked cursor theme, recolored during build";
    homepage = "https://github.com/clayrisser/breeze-hacked-cursor-theme";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
})

