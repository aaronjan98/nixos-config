{ lib, pkgs }:

let
  math-ocr = pkgs.writeShellApplication {
    name = "math-ocr";

    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.file
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
    ];

    text = builtins.readFile ../scripts/math-ocr.sh;
  };

  bootstrap-pix2tex = pkgs.writeShellApplication {
    name = "bootstrap-pix2tex";

    runtimeInputs = [
      pkgs.git
      pkgs.openssh
      pkgs.python311
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
    ];

    text = builtins.readFile ../scripts/bootstrap-pix2tex.sh;
  };
in
pkgs.symlinkJoin {
  name = "math-ocr-tools";

  paths = [
    math-ocr
    bootstrap-pix2tex
  ];

  meta = with lib; {
    description = "Screenshot-to-LaTeX OCR using pix2tex (AJ tool wrapper)";
    license = licenses.mit;
  };
}
