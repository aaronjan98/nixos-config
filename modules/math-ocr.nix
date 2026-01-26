{ config, lib, pkgs, ... }:

let
  weights = pkgs.fetchurl {
    url = "https://github.com/lukas-blecher/LaTeX-OCR/releases/download/v0.0.1/weights.pth";
    sha256 = "1anzl6am328gvkmph3jy2j1y5jym7gc8nnpvhav6q9ixqm0r2gd6";
  };

  imageResizer = pkgs.fetchurl {
    url = "https://github.com/lukas-blecher/LaTeX-OCR/releases/download/v0.0.1/image_resizer.pth";
    sha256 = "0n44f69adbfx7cdmjwr0miv735rxq8jvp434a8mi9bc5k5jj0f0w";
  };

  # Run pix2tex from python311 to avoid the python3.13/nixpkgs pix2tex mismatch.
  pix2texPy = pkgs.python311.withPackages (ps: [
    ps.pix2tex
  ]);

  math-ocr = pkgs.writeShellApplication {
    name = "math-ocr";

    runtimeInputs = [
      pix2texPy
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.file
    ];

    runtimeEnv = {
      WEIGHTS_PTH = weights;
      IMAGE_RESIZER_PTH = imageResizer;
    };

    text = builtins.readFile ../scripts/math-ocr.sh;
  };
in
{
  environment.systemPackages = [ math-ocr ];
}

