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
    nix = {
      url = "github:DeterminateSystems/nix-src";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-parts.follows = "flake-parts";
      inputs.git-hooks-nix.follows = "git-hooks-nix";
    };
    determinate = {
      url = "github:DeterminateSystems/determinate";
      inputs.nix.follows = "nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    gitignore = {
      url = "github:github/gitignore";
      flake = false;
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    darwin,
    oktaws,
    flake-parts,
    gitignore,
    ...
  }: let
    mkDarwinSystem = import ./lib/mkDarwinSystem.nix {
      inherit darwin home-manager nixpkgs oktaws gitignore;
      inherit (inputs) determinate nixpkgs-unstable nix-homebrew homebrew-core homebrew-cask;
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
        inputs.git-hooks-nix.flakeModule
      ];
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        # kept for CI format check (ubuntu-latest runner)
        "x86_64-linux"
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: let
        mkModuleEval = let
          inherit (pkgs) lib;
          evalDefault = lib.evalModules {
            modules = [./modules/options.nix];
          };
          cfgDefault = evalDefault.config.jm;
        in
          assert cfgDefault.profiles == [];
          assert cfgDefault.sshProvider == null;
          assert cfgDefault.sshKeys == {};
            pkgs.runCommand "module-eval" {} "touch $out";
      in {
        checks = {
          trajectory = pkgs.runCommand "trajectory-tests" {} ''
            cd ${self}
            ${./tests/trajectory.sh}
            touch "$out"
          '';
          # pre-commit is auto-wired by git-hooks-nix via check.enable (default: true)
          module-eval = mkModuleEval;
          module-eval-set = let
            inherit (pkgs) lib;
            eval = lib.evalModules {
              modules = [
                ./modules/options.nix
                {
                  jm = {
                    profiles = ["personal"];
                    sshProvider = "1password";
                    sshKeys."github.com" = "ssh-ed25519 test";
                  };
                }
              ];
            };
            cfg = eval.config.jm;
          in
            assert cfg.profiles == ["personal"];
            assert cfg.sshProvider == "1password";
            assert cfg.sshKeys."github.com" == "ssh-ed25519 test";
              pkgs.runCommand "module-eval-set" {} "touch $out";
          module-eval-bitwarden = let
            inherit (pkgs) lib;
            eval = lib.evalModules {
              modules = [
                ./modules/options.nix
                {
                  jm = {
                    profiles = [];
                    sshProvider = "bitwarden";
                    sshKeys."github.com" = "ssh-ed25519 test";
                  };
                }
              ];
            };
            cfg = eval.config.jm;
          in
            assert cfg.profiles == [];
            assert cfg.sshProvider == "bitwarden";
            assert cfg.sshKeys."github.com" == "ssh-ed25519 test";
              pkgs.runCommand "module-eval-bitwarden" {} "touch $out";
          module-eval-opencode-model = let
            inherit (pkgs) lib;
            eval = lib.evalModules {
              modules = [
                ./modules/options.nix
                {
                  jm = {
                    profiles = ["personal"];
                    sshProvider = "1password";
                    sshKeys."github.com" = "ssh-ed25519 test";
                    opencodeModel = "opencode/small-pickle";
                  };
                }
              ];
            };
            cfg = eval.config.jm;
          in
            assert cfg.profiles == ["personal"];
            assert cfg.sshProvider == "1password";
            assert cfg.opencodeModel == "opencode/small-pickle";
            assert cfg.sshKeys."github.com" == "ssh-ed25519 test";
              pkgs.runCommand "module-eval-opencode-model" {} "touch $out";
        };
        devShells.default = config.pre-commit.devShell;
        pre-commit.settings = {
          hooks.treefmt = {
            enable = true;
            package = config.treefmt.build.wrapper;
          };
        };
      };

      flake = {
        lib = {inherit mkDarwinSystem;};

        darwinConfigurations = {
          # GitHub Actions
          "gha-aarch64-darwin" = nixpkgs.lib.makeOverridable mkDarwinSystem {
            specialArgs = {
              inherit stateVersions;
              profiles = [];
              username = "runner";
              sshKeys."github.com" = "";
            };
          };

          # Personal Macbook Air
          "medusa" = mkDarwinSystem {
            specialArgs = {
              inherit stateVersions;
              profiles = ["personal"];
              sshProvider = "1password";
              username = "jonathan";
              sshKeys."github.com" = keys.personal;
              opencodeServer = {
                enable = true;
                port = 4096;
                hostname = "127.0.0.1";
                password = null;
              };
            };
          };

          # Personal iMac
          "smoke" = mkDarwinSystem {
            system = "x86_64-darwin";
            specialArgs = {
              inherit stateVersions;
              profiles = ["personal"];
              sshProvider = "1password";
              username = "jonathan";
              sshKeys."github.com" = keys.personal;
            };
          };
        };
      };
    };
}
