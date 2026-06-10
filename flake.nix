{
  description = "Jonathan's Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oktaws = {
      url = "github:jonathanmorley/oktaws/v0.23.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate = {
      url = "github:DeterminateSystems/determinate/v3.21.1";
      # Keep builds independent of FlakeHub credentials in local switches and CI.
      inputs = {
        nix.url = "github:DeterminateSystems/nix-src/v3.21.1";
        nixpkgs.url = "github:NixOS/nixpkgs/4df1b885d76a54e1aa1a318f8d16fd6005b6401f";
        nix.inputs = {
          flake-parts.url = "github:hercules-ci/flake-parts/49f0870db23e8c1ca0b5259734a02cd9e1e371a1";
          git-hooks-nix.url = "github:cachix/git-hooks.nix/80479b6ec16fefd9c1db3ea13aeb038c60530f46";
          nixpkgs.url = "github:NixOS/nixpkgs/0590cd39f728e129122770c029970378a79d076a";
        };
      };
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    darwin,
    oktaws,
    flake-parts,
    ...
  }: let
    mkDarwinSystem = import ./lib/mkDarwinSystem.nix {
      inherit darwin home-manager nixpkgs oktaws;
      inherit (inputs) determinate;
    };

    stateVersions = {
      darwin = "7";
      homeManager = "26.05";
    };

    keys = {
      personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJbG+RkEeZ8WakJorykKKRPsJ1Su2c8Up/clPmuSqew";
      cvent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApH3hVfolAMy3yCEFSvif1S6DuVA8D1JH13811GK5wg";
      cventInternal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYpuJAHOyz9TwJiRis+0GdjO27MQUU2FoTLD/WQVuqi";
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./treefmt.nix
        ./cert-check.nix
      ];
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake = {
        darwinConfigurations = {
          # GitHub Actions
          "gha-aarch64-darwin" = nixpkgs.lib.makeOverridable mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;
            specialArgs = {
              inherit stateVersions;
              profiles = [];
              username = "runner";
              sshKeys."github.com" = "";
            };
          };

          # Cvent MacBook Pro
          "D3W27G1QW9" = mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;
            specialArgs = {
              inherit stateVersions;
              profiles = ["cvent"];
              username = "jonathan";
              sshKeys = {
                cvent = keys.cventInternal;
                "github.com" = keys.cvent;
              };
            };
          };

          # Personal Macbook Air
          "medusa" = mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;
            specialArgs = {
              inherit stateVersions;
              profiles = ["personal"];
              username = "jonathan";
              sshKeys."github.com" = keys.personal;
            };
          };

          # Personal iMac
          "smoke" = mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;
            system = "x86_64-darwin";
            specialArgs = {
              inherit stateVersions;
              profiles = ["personal"];
              username = "jonathan";
              sshKeys."github.com" = keys.personal;
            };
          };
        };
      };
    };
}
