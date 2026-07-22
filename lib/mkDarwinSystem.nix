{
  darwin,
  determinate,
  home-manager,
  nixpkgs,
  opencode ? null,
  oktaws,
}: {
  system ? "aarch64-darwin",
  specialArgs,
  extraDarwinModules ? [],
  extraHomeModules ? [],
  ...
}:
darwin.lib.darwinSystem {
  inherit system;
  specialArgs = specialArgs // nixpkgs.lib.optionalAttrs (opencode != null) {inherit opencode;};
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
            (_final: prev:
              {
                # Custom packages
                oktaws = oktaws.packages.${prev.stdenv.hostPlatform.system}.default;
                fnox = prev.callPackage ../pkgs/fnox {};
                gig = prev.callPackage ../pkgs/gig {};
                mempalace = prev.callPackage ../pkgs/mempalace {};
                trajectory = prev.callPackage ../pkgs/trajectory {};
              }
              // nixpkgs.lib.optionalAttrs (opencode != null) {
                opencode = opencode.packages.${prev.stdenv.hostPlatform.system}.opencode;
                opencode-desktop = opencode.packages.${prev.stdenv.hostPlatform.system}.opencode-desktop;
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
