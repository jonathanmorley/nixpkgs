let
  flake = builtins.${"getFlake"} (toString ./.);
  hasOpenCodeInput = flake.inputs ? opencode;

  projectConfiguration = name: let
    configuration = flake.darwinConfigurations.${name};
    pkgs = configuration.pkgs;
    hasCli = hasOpenCodeInput && pkgs ? opencode;
    hasDesktop = hasOpenCodeInput && pkgs ? "opencode-desktop";
  in {
    system = pkgs.stdenv.hostPlatform.system;
    systemPackages = map (package: package.name) configuration.config.environment.systemPackages;
    casks = map (cask: cask.name) configuration.config.homebrew.casks;
    overlay = {
      cli =
        if hasCli
        then pkgs.opencode.name
        else null;
      desktop =
        if hasDesktop
        then pkgs."opencode-desktop".name
        else null;
    };
  };
in {
  medusa = projectConfiguration "medusa";
  gha-aarch64-darwin = projectConfiguration "gha-aarch64-darwin";
  smoke = projectConfiguration "smoke";
}
