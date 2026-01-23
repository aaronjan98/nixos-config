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

      myOverlays = [
        (final: prev: {
          breeze-hacked-cursor = final.callPackage ./pkgs/breeze-hacked-cursor/default.nix { };
        })
      ];

      pkgs = import nixpkgs {
        inherit system;
        overlays = myOverlays;
      };
    in
    {
      nixosConfigurations.thinkpad-t14 = pkgs.lib.nixosSystem {
        inherit system;

        pkgs = pkgs;

        modules = [
          ./hosts/thinkpad-t14/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}

