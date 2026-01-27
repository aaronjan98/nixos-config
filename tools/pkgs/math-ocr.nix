{ lib, pkgs }:

pkgs.writeShellApplication {
  name = "math-ocr";

  # Put everything your script calls into PATH at runtime
  runtimeInputs = [
    #pkgs.pix2tex
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

  meta = with lib; {
    description = "Screenshot-to-LaTeX OCR using pix2tex (AJ tool wrapper)";
    license = licenses.mit;
  };
}

