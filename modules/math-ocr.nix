{ config, pkgs, lib, ... }:

let
  mathOcrScript = builtins.readFile ../scripts/math-ocr.sh;
in
{
  options = { };

  config = {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "math-ocr" mathOcrScript)
    ];
  };
}

