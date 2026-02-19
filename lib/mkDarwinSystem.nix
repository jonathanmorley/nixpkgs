{
  darwin,
  determinate,
  home-manager,
  nixpkgs,
  nixpkgs-unstable,
  oktaws,
}: {
  system ? "aarch64-darwin",
  specialArgs,
  ...
}:
darwin.lib.darwinSystem {
  inherit specialArgs system;
  modules =
    [
      determinate.darwinModules.default
      ../modules/darwin.nix
      ../modules/ai/darwin.nix
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
              fnox = prev.callPackage ../pkgs/fnox {};
              gig = prev.callPackage ../pkgs/gig {};
              rtk = prev.callPackage ../pkgs/rtk {};
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
                ../modules/home.nix
                ../modules/ai/home.nix
                ../modules/docker/home.nix
                ../modules/git/home.nix
              ]
              ++ nixpkgs.lib.optional (builtins.elem "cvent" specialArgs.profiles) ../modules/cvent/home.nix;
            home = {
              username = specialArgs.username;
              homeDirectory = nixpkgs.lib.mkForce "/Users/${specialArgs.username}";
              stateVersion = specialArgs.stateVersions.homeManager;
            };
          };
        };
      }
    ]
    ++ nixpkgs.lib.optional (builtins.elem "cvent" specialArgs.profiles) ../modules/cvent/darwin.nix
    ++ nixpkgs.lib.optional (builtins.elem "personal" specialArgs.profiles) ../modules/personal/darwin.nix;
}
