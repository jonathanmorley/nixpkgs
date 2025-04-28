{
  description = "Jonathan's Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    darwin = {
      url = "github:jonathanmorley/nix-darwin/fix-cacerts-with-spaces";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    oktaws = {
      url = "github:jonathanmorley/oktaws";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    darwin,
    oktaws,
    flake-parts,
    ...
  }: let
    darwinModules = {
      profiles,
      username,
      sshKeys,
      ...
    }: [
      ./darwin.nix
      home-manager.darwinModules.home-manager
      {
        nixpkgs.overlays = [
          (final: prev: {
            # Custom packages
            oktaws = oktaws.packages.${prev.system}.default;
            # Newer packages (unstable)
            colima = nixpkgs-unstable.legacyPackages.${prev.system}.colima;
            gitify = nixpkgs-unstable.legacyPackages.${prev.system}.gitify;
            mise = nixpkgs-unstable.legacyPackages.${prev.system}.mise.overrideAttrs {
              doCheck = false;
            };
          })
        ];
        nixpkgs.config.allowUnfree = true;
        nixpkgs.config.allowUnsupportedSystem = true;

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {inherit profiles username sshKeys;};
        home-manager.users."${username}" = import ./home.nix;
      }
    ];
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
      };
      flake = {
        darwinConfigurations = {
          # GitHub CI
          "ci-x86_64-darwin" = darwin.lib.darwinSystem rec {
            system = "x86_64-darwin";
            specialArgs.profiles = [];

            modules = darwinModules {
              profiles = specialArgs.profiles;
              username = "runner";
              sshKeys = {
                "github.com" = "";
              };
            };
          };

          # GitHub CI
          "ci-aarch64-darwin" = darwin.lib.darwinSystem rec {
            system = "aarch64-darwin";
            specialArgs.profiles = [];

            modules = darwinModules {
              profiles = specialArgs.profiles;
              username = "runner";
              sshKeys = {
                "github.com" = "";
              };
            };
          };

          # Cvent MacBook Air
          "FVFFT3XKQ6LR" = darwin.lib.darwinSystem rec {
            system = "aarch64-darwin";
            specialArgs.profiles = ["cvent"];

            modules = darwinModules {
              profiles = specialArgs.profiles;
              username = "jonathan";
              sshKeys = {
                "cvent" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKuaMIMcObM1KyhncM9Qndv91P5EDreRxz5pFA7xSHaX";
                "github.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0l85pYmr5UV3FTMAQnmZYyv1wVNeKej4YnIP8sk5fW";
              };
            };
          };

          # Personal iMac
          "smoke" = darwin.lib.darwinSystem rec {
            system = "x86_64-darwin";
            specialArgs.profiles = ["personal"];

            modules = darwinModules {
              profiles = specialArgs.profiles;
              username = "jonathan";
              sshKeys = {
                "github.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJbG+RkEeZ8WakJorykKKRPsJ1Su2c8Up/clPmuSqew";
              };
            };
          };
        };
      };
    };
}
