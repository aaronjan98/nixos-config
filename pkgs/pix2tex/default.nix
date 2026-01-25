{ lib
, fetchFromGitHub
, python3Packages
, makeWrapper
, writeShellApplication
, grim
, slurp
, wl-clipboard
, libnotify
}:

let
  # --- pix2tex build (UNCHANGED from your working version) ---
  timm_054 = python3Packages.timm.overridePythonAttrs (old: rec {
    version = "0.5.4";
    src = python3Packages.fetchPypi {
      pname = "timm";
      inherit version;
      hash = "sha256-XXuS5mp2xDIAmrqQ1RXqeogqrlc0FafFJp42F9+QHB8=";
    };
    doCheck = false;
    pytestCheckPhase = "true";
  });

  pix2tex = python3Packages.buildPythonApplication rec {
    pname = "pix2tex";
    version = "0.1.4-git-5c1ac92";

    src = fetchFromGitHub {
      owner = "lukas-blecher";
      repo = "LaTeX-OCR";
      rev = "5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80";
      sha256 = "sha256-tzfvJaE9UJe9Fy/eTMczJaMbk8qfSrqWvriVKO7+SKQ=";
    };

    pyproject = true;
    build-system = with python3Packages; [ setuptools wheel ];
    doCheck = false;

    nativeBuildInputs = [ makeWrapper ];

    propagatedBuildInputs = with python3Packages; [
      torch torchvision pillow pyyaml requests tqdm munch numpy pandas
      tokenizers transformers einops
      x-transformers albumentations
      opencv4
      timm_054
      pyperclip
    ];

    dontCheckRuntimeDeps = true;
    pythonRuntimeDepsCheck = [ ];

    pythonImportsCheck = [ "pix2tex" "torch" "cv2" ];

    postInstall = ''
      for b in "$out/bin/pix2tex" "$out/bin/latexocr"; do
        if [ -x "$b" ]; then
          wrapProgram "$b" \
            --set-default XDG_CACHE_HOME "''${XDG_CACHE_HOME:-$HOME/.cache}"
        fi
      done
    '';
  };

  latexocr-shot = writeShellApplication {
    name = "latexocr-shot";

    runtimeInputs = [
      pix2tex
      grim
      slurp
      wl-clipboard
      libnotify
    ];

    text = builtins.readFile ../../scripts/latexocr-shot.sh;
  };

in
latexocr-shot

