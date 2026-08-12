{ pkgs, nix-tools, ... }:

let
  ocrTools = nix-tools.packages.${pkgs.stdenv.hostPlatform.system}.math-ocr;
in
{
  # Warm, model-resident Surya OCR server that backs `ocr-combined-warm` (Super+N).
  #
  # It loads the Surya detection + math-aware recognition predictors ONCE and
  # reuses them across captures, turning the ~32s cold `surya_ocr` reload into
  # ~14-16s warm inference. Models load lazily on the first request and unload
  # after SURYA_SERVER_IDLE_TIMEOUT seconds of inactivity, so the process sits at
  # a few tens of MB when idle instead of holding ~2-3GB permanently.
  systemd.user.services.surya-ocr-server = {
    description = "Warm model-resident Surya OCR server (local combined text+math)";
    # Start the process at login so the socket is always ready; models are NOT
    # loaded until the first capture, and are released again when idle.
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${ocrTools}/bin/surya-ocr-server";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "SURYA_SERVER_HOST=127.0.0.1"
        "SURYA_SERVER_PORT=8012"
        "SURYA_SERVER_IDLE_TIMEOUT=600"
        "SURYA_SERVER_THREADS=6"
        "TORCH_DEVICE=cpu"
      ];
    };
  };
}
