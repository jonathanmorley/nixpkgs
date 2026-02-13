# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  specialArgs,
  ...
}: {
  environment.variables.SSH_AUTH_SOCK = "/Users/jonathan/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    casks = [
      # Not available in nixpkgs
      "microsoft-outlook"
      # Not available in nixpkgs
      "microsoft-excel"
    ];
    masApps = {
      # The firefox extension doesnt unlock with biometrics if bitwarden is installed any other way
      "bitwarden" = 1352778147;
    };
  };

  system.defaults.dock.persistent-apps = [
    "${pkgs.slack}/Applications/Slack.app"
    "/Applications/Microsoft Outlook.app"
  ];
}
