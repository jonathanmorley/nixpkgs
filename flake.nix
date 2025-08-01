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
    mkDarwinSystem = {specialArgs, ...}:
      darwin.lib.darwinSystem {
        inherit specialArgs;

        system = "aarch64-darwin";
        modules =
          [
            ./nix-darwin
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
                  })
                ];
              };
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${specialArgs.username} = {
                  imports = [
                    ./home
                    ./home/docker.nix
                    ./home/git.nix
                  ];
                  home = {
                    username = specialArgs.username;
                    homeDirectory = nixpkgs.lib.mkForce "/Users/${specialArgs.username}";
                    stateVersion = specialArgs.stateVersions.homeManager;
                  };
                };
              };
            }
          ]
          ++ nixpkgs.lib.optional (builtins.elem "cvent" specialArgs.profiles) ./nix-darwin/netskope.nix;
      };

    stateVersions = {
      darwin = "6";
      homeManager = "25.05";
    };

    keys = {
      personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJbG+RkEeZ8WakJorykKKRPsJ1Su2c8Up/clPmuSqew";
      cvent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApH3hVfolAMy3yCEFSvif1S6DuVA8D1JH13811GK5wg";
      cventInternal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYpuJAHOyz9TwJiRis+0GdjO27MQUU2FoTLD/WQVuqi";
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
      };

      flake = {
        darwinConfigurations = {
          # GitHub CI
          "ci-aarch64-darwin" = mkDarwinSystem {
            inherit (nixpkgs) pkgs lib;

            specialArgs = {
              inherit stateVersions;
              profiles = [];
              username = "runner";
              sshKeys = {
                "github.com" = "";
              };
            };
          };

          # GitHub CI (x86_64)
          "ci-x86_64-darwin" = (nixpkgs.lib.makeOverridable self.darwinConfigurations."ci-aarch64-darwin").override {
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

          # Personal iMac
          "smoke" = (nixpkgs.lib.makeOverridable darwin.lib.darwinSystem
            {
              inherit (nixpkgs) pkgs lib;
              specialArgs = {
                profiles = ["personal"];
                username = "jonathan";
                sshKeys = {
                  "github.com" = keys.personal;
                };
              };
            }).override {
            system = "x86_64-darwin";
          };
        };
      };
    };
}
