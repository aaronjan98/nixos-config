{ lib, buildNpmPackage, fetchzip, fd, makeWrapper }:

buildNpmPackage (finalAttrs: {
  pname = "pi";
  version = "0.66.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha256-zEHnHOQXvDzMvhUNXB0k6d5ivyncOapUQCXiXKeMSl8=";
  };

  npmDepsHash = "sha256-mki5UrBhH5v01Z1dR3V0PIwz40XkqeiQHw4OsrrXUAQ=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

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
