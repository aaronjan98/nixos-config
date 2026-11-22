{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, glibc }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "antigravity-cli";
  version = "1.5.9";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.9-4515810895593472/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-ix9eVnefJDSgrzbxtxWoOSoITeVQ+MaLx5gh+V+r8/o=";
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
