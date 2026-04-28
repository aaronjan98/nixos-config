{ lib, stdenv, fetchzip, makeWrapper, ripgrep, bubblewrap }:

stdenv.mkDerivation (finalAttrs: {
  pname = "openai-codex";
  version = "0.125.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${finalAttrs.version}-linux-x64.tgz";
    hash = "sha256-W0+Iy93irv9EG02gN5oS8ytZ4salwubLd4cTXjBFGHM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 vendor/x86_64-unknown-linux-musl/codex/codex $out/bin/.codex-unwrapped
    makeWrapper $out/bin/.codex-unwrapped $out/bin/codex \
      --prefix PATH : ${lib.makeBinPath [ ripgrep bubblewrap ]}
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
