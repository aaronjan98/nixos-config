{ lib, pkgs }:

pkgs.writeShellApplication {
  name = "record-session";

  runtimeInputs = [
    pkgs.ffmpeg
    pkgs.whisper-cpp
    pkgs.curl
    pkgs.coreutils
    pkgs.util-linux  # setsid
  ];

  text = builtins.readFile ../scripts/record-session.sh;

  meta = with lib; {
    description = "Record mic to WAV until Ctrl+C, then transcribe with whisper.cpp (small.en)";
    license = licenses.mit;
  };
}
