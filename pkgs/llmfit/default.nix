{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "llmfit";
  version = "0.6.3";

  src = fetchFromGitHub {
    owner = "AlexsJones";
    repo = "llmfit";
    rev = "v${version}";
    hash = "sha256-pIM/GIgmsSe7+5KURl2rq/qEik0GzPjacnsa2IdQk6U=";
  };

  cargoHash = "sha256-7sExR2ah2dezHmYu8MyKEagy0kcTtHKYVTQ9ecN+PM4=";

  meta = {
    description = "Terminal tool to right-size LLM models to your hardware";
    homepage = "https://github.com/AlexsJones/llmfit";
    license = lib.licenses.mit;
    mainProgram = "llmfit";
  };
}
