{ lib
, python3Packages
, fetchFromGitHub
, makeWrapper
}:

python3Packages.buildPythonApplication rec {
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
    torch
    torchvision
    pillow
    pyyaml
    requests
    tqdm
    munch
    numpy
    pandas
    tokenizers
    transformers
    einops
    opencv4
    timm
    pyperclip
    albumentations
    x-transformers
  ];

  dontCheckRuntimeDeps = true;
  pythonRuntimeDepsCheck = [ ];

  postPatch = ''
    ck="pix2tex/dataset/transforms.py"
    if [ -f "$ck" ]; then
      # 1) Fix GaussNoise arg for stricter validation
      substituteInPlace "$ck" \
        --replace-warn "alb.GaussNoise(10, p=.2)" \
                       "alb.GaussNoise(var_limit=(10,10), p=.2)"

      # 2) Fix albumentations>=2 ImageCompression signature:
      #    old: alb.ImageCompression(95, p=.3)
      #    new: alb.ImageCompression(compression_type='jpeg', quality_lower=95, quality_upper=95, p=.3)
      substituteInPlace "$ck" \
        --replace-warn "alb.ImageCompression(95, p=.3)" \
                       "alb.ImageCompression(compression_type='jpeg', quality_lower=95, quality_upper=95, p=.3)"
    fi

    # 3) Make pix2tex write checkpoints into a cache path (avoid /nix/store)
    ck2="pix2tex/model/checkpoints/get_latest_checkpoint.py"
    if [ -f "$ck2" ]; then
      substituteInPlace "$ck2" \
        --replace-warn 'path = os.path.dirname(__file__)' \
                      'path = os.path.join(os.path.expanduser(os.getenv("XDG_CACHE_HOME","~/.cache")), "pix2tex", "checkpoints"); os.makedirs(path, exist_ok=True)'
    fi
  '';

  postInstall = ''
    for b in "$out/bin/pix2tex" "$out/bin/latexocr"; do
      if [ -x "$b" ]; then
        wrapProgram "$b" \
          --set-default XDG_CACHE_HOME "''${XDG_CACHE_HOME:-$HOME/.cache}"
      fi
    done
  '';

  pythonImportsCheck = [ "pix2tex" ];

  meta = with lib; {
    description = "pix2tex (LaTeX-OCR): convert images of equations to LaTeX";
    homepage = "https://github.com/lukas-blecher/LaTeX-OCR";
    license = lib.licenses.mit;
  };
}

