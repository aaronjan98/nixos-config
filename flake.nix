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

      myOverlay = (final: prev: {
        breeze-hacked-cursor =
          final.callPackage ./pkgs/breeze-hacked-cursor/default.nix { };
      });
    in
    {
      nixosConfigurations.thinkpad-t14 = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # Apply your overlay the "normal" NixOS way:
          ({ ... }: { nixpkgs.overlays = [ myOverlay ]; })

          ./hosts/thinkpad-t14/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}

