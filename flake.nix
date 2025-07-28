{
  nixConfig = {
    abort-on-warn = true;
    allow-import-from-derivation = false;
  };

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      {
        systems = import inputs.systems;

        partitionedAttrs = lib.genAttrs [ "checks" "devShells" "formatter" ] (_: "dev");
        partitions.dev = {
          extraInputsFlake = ./dev;
          module = ./dev/imports.nix;
        };

        imports = [
          ./modules/flake-module.nix
          ./modules/nixos-module.nix
          ./modules/prose/implementation.nix
          ./modules/prose/introduction.nix
          ./modules/prose/order.nix
          ./modules/prose/tutorial.nix
          inputs.flake-parts.flakeModules.flakeModules
          inputs.flake-parts.flakeModules.modules
          inputs.flake-parts.flakeModules.partitions
        ];
      }
    );
}
