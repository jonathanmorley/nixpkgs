{
  description = "Jonathan's Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:anomalyco/opencode/v1.18.4";

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
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    darwin,
    oktaws,
    flake-parts,
    ...
  }: let
    mkDarwinSystem = import ./lib/mkDarwinSystem.nix {
      inherit darwin home-manager nixpkgs oktaws;
      inherit (inputs) opencode;
      inherit (inputs) determinate;
    };

    stateVersions = {
      darwin = "7";
      homeManager = "26.05";
    };

    keys = {
      personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJbG+RkEeZ8WakJorykKKRPsJ1Su2c8Up/clPmuSqew";
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./treefmt.nix
      ];
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem = {pkgs, ...}: {
        checks.opencode =
          pkgs.runCommand "opencode-tests" {
            nativeBuildInputs = [
              pkgs.nix
              pkgs.jq
            ];
          } ''
            cd ${self}
            export HOME="$TMPDIR"
            export XDG_CACHE_HOME="$TMPDIR"
            ${./tests/opencode.sh}
            touch "$out"
          '';

        checks.trajectory = pkgs.runCommand "trajectory-tests" {} ''
          cd ${self}
          ${./tests/trajectory.sh}
          touch "$out"
        '';
      };

      flake = {
        lib = {inherit mkDarwinSystem;};

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
