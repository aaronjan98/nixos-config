{ lib, buildNpmPackage, fetchzip, fd, makeWrapper }:

buildNpmPackage (finalAttrs: {
  pname = "pi";
  version = "0.67.68";

  src = fetchzip {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha256-s9mqbi9LmqhdUrRCjf+tpnsX8x1C4Kz4sJYNV1vpk/A=";
  };

  npmDepsHash = "sha256-S9f+6kB1yVHBb7y20YqCpHf1FMTj0NuUf4ioJ5gfmLo=";

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
