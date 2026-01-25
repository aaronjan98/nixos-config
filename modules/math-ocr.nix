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

  # Try to locate config.yaml in pix2tex across python versions
  configYaml = "${pkgs.pix2tex}/lib/${pkgs.pix2tex.python.sitePackages}/pix2tex/model/settings/config.yaml";

  math-ocr = pkgs.writeShellApplication {
    name = "math-ocr";

    runtimeInputs = [
      pkgs.pix2tex
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
    ];

    # Export pinned paths into the runtime environment
    # so the script can read them without eval-time substitution.
    runtimeEnv = {
      WEIGHTS_PTH = weights;
      IMAGE_RESIZER_PTH = imageResizer;
      CONFIG_YAML = configYaml;
    };

    text = builtins.readFile ../scripts/math-ocr.sh;
  };
in
{
  environment.systemPackages = [ math-ocr ];
}

