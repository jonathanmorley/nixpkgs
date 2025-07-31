{
  description = "Jonathan's Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oktaws = {
      url = "github:jonathanmorley/oktaws/master";
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

          # Cvent MacBook Pro
          "D3W27G1QW9" = darwin.lib.darwinSystem rec {
            system = "aarch64-darwin";
            specialArgs.profiles = ["cvent"];

            modules = darwinModules {
              profiles = specialArgs.profiles;
              username = "jonathan";
              sshKeys = {
                "cvent" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYpuJAHOyz9TwJiRis+0GdjO27MQUU2FoTLD/WQVuqi";
                "github.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApH3hVfolAMy3yCEFSvif1S6DuVA8D1JH13811GK5wg";
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
