{ lib, pkgs }:

let
  pix2texLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
  ];

  suryaLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
  ];

  math-ocr = pkgs.writeShellApplication {
    name = "math-ocr";

    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.bash
      pkgs.systemd
      pkgs.jq
      pkgs.file
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
    ];

    runtimeEnv.PIX2TEX_EXTRA_LIBRARY_PATH = pix2texLibraryPath;

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/math-ocr.sh;
  };

  ocr-correct-last = pkgs.writeShellApplication {
    name = "ocr-correct-last";

    runtimeInputs = [
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.jq
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
    ];

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/ocr-correct-last.sh;
  };

  text-ocr = pkgs.writeShellApplication {
    name = "text-ocr";

    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.bash
      pkgs.systemd
      pkgs.jq
      pkgs.file
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.gawk
      pkgs.tesseract
    ];

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/text-ocr.sh;
  };

  ocr-combined = pkgs.writeShellApplication {
    name = "ocr-combined";

    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.bash
      pkgs.systemd
      pkgs.jq
      pkgs.file
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.llama-cpp
    ];

    runtimeEnv.SURYA_EXTRA_LIBRARY_PATH = suryaLibraryPath;

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/ocr-combined.sh;
  };

  bootstrap-surya-ocr = pkgs.writeShellApplication {
    name = "bootstrap-surya-ocr";

    runtimeInputs = [
      pkgs.python312
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.llama-cpp
    ];

    runtimeEnv.SURYA_EXTRA_LIBRARY_PATH = suryaLibraryPath;

    text = builtins.readFile ../scripts/bootstrap-surya-ocr.sh;
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

    runtimeEnv.PIX2TEX_EXTRA_LIBRARY_PATH = pix2texLibraryPath;

    text = builtins.readFile ../scripts/bootstrap-pix2tex.sh;
  };
in
pkgs.symlinkJoin {
  name = "math-ocr-tools";

  paths = [
    math-ocr
    ocr-correct-last
    text-ocr
    ocr-combined
    bootstrap-surya-ocr
    bootstrap-pix2tex
  ];

  meta = with lib; {
    description = "Screenshot OCR tools for math and text capture";
    license = licenses.mit;
  };
}
