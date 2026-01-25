{ lib
, writeShellApplication
, pix2tex
, grim
, slurp
, wl-clipboard
, libnotify
, file
, coreutils
, gnugrep
, gnused
}:

writeShellApplication {
  name = "math-ocr";

  runtimeInputs = [
    pix2tex
    grim
    slurp
    wl-clipboard
    libnotify
    file
    coreutils
    gnugrep
    gnused
  ];

  text = builtins.readFile ../../scripts/math-ocr.sh;

  # Shellcheck style warnings shouldn't fail the build
  checkPhase = ''
    echo "Skipping shellcheck"
  '';

  meta = with lib; {
    description = "Wayland screenshot -> pix2tex -> clipboard + notification";
    license = licenses.mit;
  };
}

