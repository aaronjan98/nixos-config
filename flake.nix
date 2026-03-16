{
  description = "AJ's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-tools.url = "path:./tools";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, nix-tools, ... }:
    let
      system = "x86_64-linux";

      allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "open-webui"
	  "cursor"
        ];

      localOverlay = (final: prev: {
        breeze-hacked-cursor = final.callPackage ./pkgs/breeze-hacked-cursor/default.nix { };
        # pix2tex = final.callPackage ./pkgs/pix2tex { };
        llmfit = final.callPackage ./pkgs/llmfit/default.nix { };
        models = final.callPackage ./pkgs/models/default.nix { };
      });

      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config = {
          inherit allowUnfreePredicate;
        };
        overlays = [ localOverlay ];
      };

      myOverlay = (final: prev:
        (localOverlay final prev) // {
          open-webui = pkgsUnstable.open-webui;
          llmfit = pkgsUnstable.llmfit;
          models = pkgsUnstable.models;
          code-cursor = pkgsUnstable.code-cursor;
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

      packages.x86_64-linux =
        let
          pkgsWithOverlay = import nixpkgs {
            inherit system;
            overlays = [ myOverlay ];
          };
        in {
          # inherit (pkgsWithOverlay) pix2tex;
        };
    };
}
