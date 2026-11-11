{ lib, stdenvNoCC, fetchzip, makeWrapper, bubblewrap, ripgrep }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openai-codex";
  version = "0.167.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${finalAttrs.version}-linux-x64.tgz";
    hash = "sha256-bOo4/bel3mNhwYa/gjMUj6yRZezeNToekFWheqlcKp4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    vendor_root="$out/lib/openai-codex"
    mkdir -p "$vendor_root" "$out/bin"
    cp -r vendor/x86_64-unknown-linux-musl/. "$vendor_root/"

    chmod +x "$vendor_root/bin/codex"
    makeWrapper "$vendor_root/bin/codex" "$out/bin/codex" \
      --prefix PATH : ${lib.makeBinPath [ bubblewrap ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI — agentic coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "x86_64-linux" ];
  };
})
