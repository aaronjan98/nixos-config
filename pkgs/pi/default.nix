{ lib, buildNpmPackage, fetchzip, fd, makeWrapper }:

buildNpmPackage (finalAttrs: {
  pname = "pi";
  version = "0.73.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha256-ZBSiOoKig+TGR7tswMro9CCmrQ5AI6Yf21XkBFastao=";
  };

  npmDepsHash = "sha256-2z31LDLzHqn6/ImMaw58PlQH/KdZdWthc7wiiYpCFhU=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ]}
  '';

  meta = {
    description = "Minimal, extensible agentic coding agent";
    homepage = "https://github.com/badlogic/pi-mono";
    downloadPage = "https://www.npmjs.com/package/@mariozechner/pi-coding-agent";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
})
