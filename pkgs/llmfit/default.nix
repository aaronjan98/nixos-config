{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "llmfit";
  version = "0.6.5";

  src = fetchFromGitHub {
    owner = "AlexsJones";
    repo = "llmfit";
    rev = "v${version}";
    hash = "sha256-cCRAM1SuGoErY3Md/sZR42nG7PGZWEsSMM53kLsbdNI=";
  };

  patches = [
    ./hf-accept-encoding-identity.patch
  ];

  cargoHash = "sha256-Y16liGWowcDPiEiCYXpch09Rl653wCvW2jPmQRAEino=";

  meta = {
    description = "Terminal tool to right-size LLM models to your hardware";
    homepage = "https://github.com/AlexsJones/llmfit";
    license = lib.licenses.mit;
    mainProgram = "llmfit";
  };
}
