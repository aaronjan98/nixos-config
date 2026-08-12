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
      pkgs.imagemagick
    ];

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/text-ocr.sh;
  };

  customSplitRuntimeInputs = [
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.bash
    pkgs.systemd
    pkgs.tesseract
    pkgs.imagemagick
    pkgs.coreutils
    pkgs.openssh
  ];

  mkOcrCustomSplit = name: extraRuntimeEnv: pkgs.writeShellApplication {
    inherit name;

    runtimeInputs = customSplitRuntimeInputs;

    runtimeEnv = {
      PIX2TEX_EXTRA_LIBRARY_PATH = pix2texLibraryPath;
    } // extraRuntimeEnv;

    text = ''
      if [ -n "''${PIX2TEX_EXTRA_LIBRARY_PATH:-}" ]; then
        export LD_LIBRARY_PATH="''${PIX2TEX_EXTRA_LIBRARY_PATH}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      fi

      exec ${pkgs.python312}/bin/python3 ${../scripts/ocr-custom-split.py} "$@"
    '';
  };

  ocr-custom-split = mkOcrCustomSplit "ocr-custom-split" {};

  ocr-custom-split-sauron = mkOcrCustomSplit "ocr-custom-split-sauron" {
    OCR_CUSTOM_BACKEND = "sauron";
    OCR_CUSTOM_DISPLAY_BACKEND = "sauron";
    OCR_CUSTOM_INLINE_BACKEND = "sauron";
  };

  combinedRuntimeInputs = [
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
    pkgs.openssh
    pkgs.llama-cpp
  ];

  ocr-combined = pkgs.writeShellApplication {
    name = "ocr-combined";

    runtimeInputs = combinedRuntimeInputs;

    runtimeEnv.SURYA_EXTRA_LIBRARY_PATH = suryaLibraryPath;

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/ocr-combined.sh;
  };

  ocr-combined-sauron = pkgs.writeShellApplication {
    name = "ocr-combined-sauron";

    runtimeInputs = combinedRuntimeInputs;

    runtimeEnv = {
      OCR_BACKEND = "sauron";
      SURYA_EXTRA_LIBRARY_PATH = suryaLibraryPath;
    };

    excludeShellChecks = [ "SC2016" ];

    text = builtins.readFile ../scripts/ocr-combined.sh;
  };

  ocr-combined-stop = pkgs.writeShellApplication {
    name = "ocr-combined-stop";

    runtimeInputs = [
      pkgs.libnotify
      pkgs.jq
      pkgs.coreutils
      pkgs.procps
    ];

    text = builtins.readFile ../scripts/ocr-combined-stop.sh;
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
    ocr-custom-split
    ocr-custom-split-sauron
    ocr-combined
    ocr-combined-sauron
    ocr-combined-stop
    bootstrap-surya-ocr
    bootstrap-pix2tex
  ];

  meta = with lib; {
    description = "Screenshot OCR tools for math and text capture";
    license = licenses.mit;
  };
}
