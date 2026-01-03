{
  description = "NixOS configuration for aj";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.thinkpad-t14 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/thinkpad-t14/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}
