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
      inherit (inputs) nixpkgs-unstable nix-homebrew homebrew-core homebrew-cask;
    };

    stateVersions = {
      darwin = 7;
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
        # Apple Silicon only; Nixpkgs 26.11 (current unstable) dropped
        # x86_64-darwin support, and the Intel `smoke` iMac config is retired.
        "aarch64-darwin"
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
          vscode-update-mode = pkgs.runCommand "vscode-update-mode-tests" {} ''
            ${./tests/vscode-update-mode.sh} ${pkgs.callPackage ./pkgs/vscode-update-mode {}}/bin/vscode-update-mode
            touch "$out"
          '';
          # Settings are set through programs.vscode when it writes settings.json,
          # and by the activation step otherwise, never both.
          vscode-update-mode-hm = let
            inherit (pkgs) lib;
            # programs.vscode.profiles.<name>.mutableUserSettings is only in newer
            # Home Manager; declare it for the pinned one.
            hmHasMutableSettings =
              lib.hasInfix "mutableUserSettings"
              (builtins.readFile "${inputs.home-manager}/modules/programs/vscode/mkVscodeModule.nix");
            mutableSettingsOption = lib.optional (!hmHasMutableSettings) {
              options.programs.vscode.profiles = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options.mutableUserSettings = lib.mkEnableOption "writable settings.json";
                });
              };
            };
            # The CI host's Home Manager with `module`, and with or without
            # modules/vscode/home.nix.
            hmWith = withModule: module:
              (self.darwinConfigurations.gha-aarch64-darwin.extendModules {
                modules = [
                  {
                    home-manager.users.runner = {
                      imports = [module] ++ mutableSettingsOption;
                      disabledModules = lib.optional (!withModule) ./modules/vscode/home.nix;
                    };
                  }
                ];
              }).config.home-manager.users.runner;
            settingsPath = "/Users/runner/Library/Application Support/Code/User/settings.json";
            activates = hm: hm.home.activation ? vscodeUpdateMode;
            writes = hm: hm.home.file ? ${settingsPath};
            warns = hm: lib.any (lib.hasInfix "enableUpdateCheck") hm.warnings;
            # Shell that checks, at build time, the settings.json `module` makes
            # programs.vscode write: Home Manager's own (without this module)
            # merged with `extra`. This module may change no other file.
            settingsAre = name: module: extra: let
              on = hmWith true module;
              off = hmWith false module;
            in
              if lib.attrNames on.home.file != lib.attrNames off.home.file
              then throw "vscode-update-mode-hm: ${name}: home.file entries differ"
              else if !(writes off)
              then "echo 'PASS: ${name} (programs.vscode writes no settings.json)'"
              else ''
                ${pkgs.jq}/bin/jq -e --slurpfile hm ${off.home.file.${settingsPath}.source} \
                  --argjson extra ${lib.escapeShellArg (builtins.toJSON extra)} \
                  '. == ($hm[0] + $extra)' ${on.home.file.${settingsPath}.source} >/dev/null \
                  || { echo "FAIL: ${name}"; exit 1; }
                echo "PASS: ${name}"
              '';
            vscode = settings: {programs.vscode = {enable = true;} // settings;};
            withSettings = vscode {userSettings.a = 1;};
            withExtensionChecks = vscode {
              userSettings.a = 1;
              profiles.default.enableExtensionUpdateCheck = false;
            };
            withVscodium = {pkgs, ...}: {
              programs.vscode = {
                enable = true;
                package = pkgs.vscodium;
                userSettings.a = 1;
              };
            };
            withUpdates = vscode {
              userSettings.a = 1;
              profiles.default.enableUpdateCheck = true;
            };
            withNoUpdates = vscode {
              userSettings.a = 1;
              profiles.default.enableUpdateCheck = false;
            };
            withMutable = vscode {
              userSettings.a = 1;
              profiles.default.mutableUserSettings = true;
            };
            withPath = vscode {userSettings = ./tests/vscode-update-mode.sh;};
            withPathString = vscode {userSettings = "${./tests/vscode-update-mode.sh}";};
            noUpdates = {"update.mode" = "none";};
            hm = lib.mapAttrs (_: hmWith true) {
              inherit withSettings withVscodium withUpdates withNoUpdates withMutable withPath withPathString;
              default = {};
              enabled = vscode {};
            };
          in
            assert activates hm.default && !writes hm.default && !warns hm.default;
            # Enabled without settings: still a writable file, and no default profile
            # is created (that would make programs.vscode manage the extensions).
            assert activates hm.enabled && !writes hm.enabled && hm.enabled.programs.vscode.profiles == {};
            assert !activates hm.withSettings && !warns hm.withSettings;
            # programs.vscode writes VS Code's paths whatever the package.
            assert !activates hm.withVscodium && !warns hm.withVscodium;
            assert !activates hm.withUpdates && !warns hm.withUpdates;
            assert !activates hm.withNoUpdates && !warns hm.withNoUpdates;
            # Writable settings.json: the activation step sets the key.
            assert activates hm.withMutable && !warns hm.withMutable;
            assert !activates hm.withPath && warns hm.withPath;
            assert !activates hm.withPathString && warns hm.withPathString;
              pkgs.runCommand "vscode-update-mode-hm" {} ''
                ${settingsAre "userSettings get update.mode" withSettings noUpdates}
                ${settingsAre "enableExtensionUpdateCheck = false is kept" withExtensionChecks noUpdates}
                ${settingsAre "vscodium package writes VS Code's settings" withVscodium noUpdates}
                ${settingsAre "enableUpdateCheck = true is kept" withUpdates {}}
                ${settingsAre "enableUpdateCheck = false is kept" withNoUpdates {}}
                ${settingsAre "mutableUserSettings is left to programs.vscode" withMutable {}}
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
          # docs/superpowers/ holds tracked specs/plans in some repos; it must not be globally ignored.
          git-ignores = let
            ignores = self.darwinConfigurations.gha-aarch64-darwin.config.home-manager.users.runner.programs.git.ignores;
          in
            assert builtins.elem "/.worktrees/" ignores;
            assert !(builtins.elem "docs/superpowers/" ignores);
              pkgs.runCommand "git-ignores" {} "touch $out";
          # OpenChamber must start the Nix opencode, which the profile path has to provide.
          openchamber-opencode-binary = let
            cfg = self.darwinConfigurations.gha-aarch64-darwin.config;
            binary = "/etc/profiles/per-user/runner/bin/opencode";
          in
            assert cfg.launchd.user.envVariables.OPENCODE_BINARY == binary;
            assert cfg.launchd.user.agents.opencode-binary-env.serviceConfig.ProgramArguments == ["/bin/launchctl" "setenv" "OPENCODE_BINARY" binary];
            assert cfg.launchd.user.agents.opencode-binary-env.serviceConfig.RunAtLoad;
            assert cfg.home-manager.useUserPackages;
            assert builtins.elem cfg.home-manager.users.runner.programs.opencode.package cfg.home-manager.users.runner.home.packages;
              pkgs.runCommand "openchamber-opencode-binary" {} "touch $out";
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
            };
          };
        };
      };
    };
}
