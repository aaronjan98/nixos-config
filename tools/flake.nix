{
  description = "AJ personal tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        math-ocr = pkgs.callPackage ./pkgs/math-ocr.nix { };
        record-session = pkgs.callPackage ./pkgs/record-session.nix { };
        hypr-session = pkgs.callPackage ./pkgs/hypr-session.nix { };
      };

      # convenience
      defaultPackage.${system} = self.packages.${system}.math-ocr;
    };
}

