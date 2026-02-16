{
  description = "Jonathan's Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oktaws = {
      url = "github:jonathanmorley/oktaws/v0.23.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
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
    mkDarwinSystem = {
      system ? "aarch64-darwin",
      specialArgs,
      ...
    }:
      darwin.lib.darwinSystem {
        inherit specialArgs system;
        modules =
          [
            ./modules/darwin.nix
            ./modules/ai/darwin.nix
            {
              system.stateVersion = specialArgs.stateVersions.darwin;
              system.primaryUser = specialArgs.username;
            }
            home-manager.darwinModules.home-manager
            {
              nixpkgs = {
                config.allowUnfree = true;
                config.allowUnsupportedSystem = true;
                overlays = [
                  (final: prev: {
                    # Custom packages
                    oktaws = oktaws.packages.${prev.system}.default;
                    gig = prev.callPackage ./pkgs/gig {};
                    bat = nixpkgs-unstable.legacyPackages.${prev.system}.bat; # To get 0.26.1
                  })
                ];
              };
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${specialArgs.username} = {
                  imports =
                    [
                      ./modules/home.nix
                      ./modules/ai/home.nix
                      ./modules/docker/home.nix
                      ./modules/git/home.nix
                    ]
                    ++ nixpkgs.lib.optional (builtins.elem "cvent" specialArgs.profiles) ./modules/cvent/home.nix;
                  home = {
                    username = specialArgs.username;
                    homeDirectory = nixpkgs.lib.mkForce "/Users/${specialArgs.username}";
                    stateVersion = specialArgs.stateVersions.homeManager;
                  };
                };
              };
            }
          ]
          ++ nixpkgs.lib.optional (builtins.elem "cvent" specialArgs.profiles) ./modules/cvent/darwin.nix
          ++ nixpkgs.lib.optional (builtins.elem "personal" specialArgs.profiles) ./modules/personal/darwin.nix;
      };

    stateVersions = {
      darwin = "6";
      homeManager = "25.11";
    };

    keys = {
      personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJbG+RkEeZ8WakJorykKKRPsJ1Su2c8Up/clPmuSqew";
      cvent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApH3hVfolAMy3yCEFSvif1S6DuVA8D1JH13811GK5wg";
      cventInternal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYpuJAHOyz9TwJiRis+0GdjO27MQUU2FoTLD/WQVuqi";
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [./treefmt.nix];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      flake = {
        darwinConfigurations = {
          # GitHub CI
          "ci-aarch64-darwin" = nixpkgs.lib.makeOverridable mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;
            specialArgs = {
              inherit stateVersions;
              profiles = [];
              username = "runner";
              sshKeys."github.com" = "";
            };
          };

          # GitHub CI (x86_64)
          "ci-x86_64-darwin" = self.darwinConfigurations."ci-aarch64-darwin".override {
            system = "x86_64-darwin";
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
