{
  description = "NixOS configuration for aj";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-tools.url = "path:./tools";
  };

  outputs = { self, nixpkgs, sops-nix, nix-tools, ... }:
    let
      system = "x86_64-linux";

      myOverlay = (final: prev: {
        breeze-hacked-cursor = final.callPackage ./pkgs/breeze-hacked-cursor/default.nix { };
        #pix2tex = final.callPackage ./pkgs/pix2tex { };
        llmfit = final.callPackage ./pkgs/llmfit/default.nix { };
      });
    in
    {
      nixosConfigurations.thinkpad-t14 = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit nix-tools; };

        modules = [
          ({ ... }: { nixpkgs.overlays = [ myOverlay ]; })

          ./hosts/thinkpad-t14/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };


      packages.x86_64-linux = let
        pkgsWithOverlay = import nixpkgs { inherit system; overlays = [ myOverlay ]; };
      in {
        # inherit (pkgsWithOverlay) pix2tex;
      };
    };
}

