{
  description = "NixOS configuration for aj";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.thinkpad-t14 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/thinkpad-t14/configuration.nix
        ];
      };
    };
}

