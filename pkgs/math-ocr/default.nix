{ lib
, writeShellApplication
, pix2tex
, grim
, slurp
, wl-clipboard
, libnotify
}:

writeShellApplication {
  name = "math-ocr";

  runtimeInputs = [
    pix2tex
    grim
    slurp
    wl-clipboard
    libnotify
  ];

  text = builtins.readFile ../../scripts/math-ocr.sh;

  # Disable shellcheck failures during build
  checkPhase = "true";

  meta = with lib; {
    description = "Wayland screenshot -> pix2tex -> clipboard + notification";
    license = licenses.mit;
  };
}

