{
  darwin,
  determinate,
  gitignore,
  home-manager,
  nixpkgs,
  nixpkgs-unstable,
  oktaws,
}: {
  system ? "aarch64-darwin",
  specialArgs,
  extraDarwinModules ? [],
  extraHomeModules ? [],
  ...
}: let
  extendedSpecialArgs =
    specialArgs
    // {
      inherit gitignore;
      opencodeModel = specialArgs.opencodeModel or "opencode/big-pickle";
    };
in
  darwin.lib.darwinSystem {
    inherit system;
    specialArgs = extendedSpecialArgs;
    modules =
      [
        determinate.darwinModules.default
        ../modules/options.nix
        ../modules/darwin.nix
        ../modules/ai/darwin.nix
        ../modules/secrets/bitwarden.darwin.nix
        ../modules/secrets/1password.darwin.nix
        {
          system.stateVersion = extendedSpecialArgs.stateVersions.darwin;
          system.primaryUser = extendedSpecialArgs.username;

          jm.profiles = extendedSpecialArgs.profiles or [];
          jm.sshProvider = extendedSpecialArgs.sshProvider or null;
          jm.sshKeys = extendedSpecialArgs.sshKeys or {};
          jm.opencodeModel = extendedSpecialArgs.opencodeModel;
        }
        home-manager.darwinModules.home-manager
        {
          nixpkgs = {
            config.allowUnfree = true;
            config.allowUnsupportedSystem = true;
            overlays = [
              (_final: prev: {
                # Custom packages
                # fnox from nixpkgs rather than its flake, which evaluates
                # with a deprecation warning and misses the binary cache.
                fnox = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.fnox;
                oktaws = oktaws.packages.${prev.stdenv.hostPlatform.system}.default;
                mempalace = prev.callPackage ../pkgs/mempalace {};
                trajectory = prev.callPackage ../pkgs/trajectory {};
              })
            ];
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = extendedSpecialArgs;
            users.${extendedSpecialArgs.username} = {
              imports =
                [
                  ../modules/home.nix
                  ../modules/ai/home.nix
                  ../modules/docker/home.nix
                  ../modules/git/home.nix
                  ../modules/secrets/fnox.home.nix
                ]
                ++ extraHomeModules;
              home = {
                username = extendedSpecialArgs.username;
                homeDirectory = nixpkgs.lib.mkForce "/Users/${extendedSpecialArgs.username}";
                stateVersion = extendedSpecialArgs.stateVersions.homeManager;
              };
            };
          };
        }
      ]
      ++ nixpkgs.lib.optional (builtins.elem "personal" extendedSpecialArgs.profiles) ../modules/personal/darwin.nix
      ++ extraDarwinModules;
  }
