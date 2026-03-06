{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "models";
  version = "0.9.7";

  src = fetchFromGitHub {
    owner = "arimxyer";
    repo = "models";
    rev = "v${version}";
    hash = "sha256-nEuGB+h2wBUOoaQuC9rxK71dhwoYONs7gx+JFEa57Vo=";
  };

  cargoHash = "sha256-XMaGuKv9ippmnqt/l8B/xb+Q7YytGpgitXAqur/i6MU=";

  meta = {
    description = "Fast CLI and TUI for browsing AI models, benchmarks, and coding agents";
    homepage = "https://github.com/arimxyer/models";
    license = lib.licenses.mit;
    mainProgram = "models";
  };
}
