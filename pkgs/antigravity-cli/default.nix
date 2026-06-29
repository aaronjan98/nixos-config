{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, glibc }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "antigravity-cli";
  version = "1.0.13";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.13-5758107482193920/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-a/mQRYwRSvOzFz3LwbD7mrk76pHFO2Bf3Wmu3SmiHNk=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 antigravity $out/bin/agy
    runHook postInstall
  '';

  meta = {
    description = "Antigravity CLI — terminal AI coding agent, successor to Gemini CLI";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    mainProgram = "agy";
    platforms = [ "x86_64-linux" ];
  };
})
