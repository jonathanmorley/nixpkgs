{
  darwin,
  determinate,
  home-manager,
  nixpkgs,
  oktaws,
  fnox,
}: {
  system ? "aarch64-darwin",
  specialArgs,
  extraDarwinModules ? [],
  extraHomeModules ? [],
  ...
}:
darwin.lib.darwinSystem {
  inherit system specialArgs;
  modules =
    [
      determinate.darwinModules.default
      ../modules/darwin.nix
      ../modules/ai/darwin.nix
      ../modules/secrets/bitwarden.darwin.nix
      ../modules/secrets/1password.darwin.nix
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
            (_final: prev: {
              # Custom packages
              fnox = fnox.packages.${prev.stdenv.hostPlatform.system}.default;
              oktaws = oktaws.packages.${prev.stdenv.hostPlatform.system}.default;
              gig = prev.callPackage ../pkgs/gig {};
              mempalace = prev.callPackage ../pkgs/mempalace {};
              trajectory = prev.callPackage ../pkgs/trajectory {};
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
                ../modules/home.nix
                ../modules/ai/home.nix
                ../modules/docker/home.nix
                ../modules/git/home.nix
                ../modules/secrets/fnox.home.nix
              ]
              ++ extraHomeModules;
            home = {
              username = specialArgs.username;
              homeDirectory = nixpkgs.lib.mkForce "/Users/${specialArgs.username}";
              stateVersion = specialArgs.stateVersions.homeManager;
            };
          };
        };
      }
    ]
    ++ nixpkgs.lib.optional (builtins.elem "personal" specialArgs.profiles) ../modules/personal/darwin.nix
    ++ extraDarwinModules;
}
