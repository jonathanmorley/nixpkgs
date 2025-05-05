# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  specialArgs,
  ...
}: let
  personal = builtins.elem "personal" specialArgs.profiles;
  cvent = builtins.elem "cvent" specialArgs.profiles;
in {
  # Nix configuration
  nix.enable = false;

  environment.pathsToLink = ["/share/zsh"];
  environment.systemPath = [config.homebrew.brewPrefix];
  environment.shells = [pkgs.zsh];

  environment.variables = {
    DOCKER_HOST = "unix:///Users/jonathan/.colima/default/docker.sock";
    NODE_EXTRA_CA_CERTS = lib.optional cvent "/Library/Application Support/Netskope/STAgent/download/nscacert.pem";
  };

  fonts.packages = [pkgs.nerd-fonts.fira-code];

  programs.zsh.enable = true;

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";
    taps = ["hashicorp/tap"];
    casks =
      [
        # https://github.com/NixOS/nixpkgs/issues/254944
        "1password"
        # The 1Password extension does not unlock with biometrics if FF is installed via nix
        "firefox"
        # Not available in nixpkgs
        "lulu"
        # Not available in nixpkgs
        "oversight"
        "hashicorp-vagrant"
        "virtualbox"
      ]
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-outlook"
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-excel"
      # Screensharing doesn't work with nixpkgs
      ++ lib.optional cvent "zoom";
  };

  security.pam.services.sudo_local.touchIdAuth = true;
  security.pki.certificateFiles = lib.optional cvent "/Library/Application Support/Netskope/STAgent/download/nscacert.pem";

  system.stateVersion = 6;

  system.defaults = {
    ActivityMonitor.IconType = 5; # CPU Usage
    NSGlobalDomain = {
      AppleEnableMouseSwipeNavigateWithScrolls = false;
      AppleEnableSwipeNavigateWithScrolls = false;
      AppleInterfaceStyle = "Dark";
      AppleKeyboardUIMode = 3; # full keyboard control
      AppleShowAllFiles = true;
      InitialKeyRepeat = 10;
      KeyRepeat = 1;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSTextShowsControlCharacters = true;
    };
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
    dock = {
      dashboard-in-overlay = true;
      persistent-apps =
        [
          "${pkgs.warp-terminal}/Applications/Warp.app"
          "/Applications/Firefox.app"
        ]
        ++ lib.optional cvent "${pkgs.slack}/Applications/Slack.app"
        ++ lib.optional cvent "/Applications/Microsoft Outlook.app";
      show-recents = false;
      wvous-bl-corner = 5; # Start Screen Saver
      wvous-br-corner = 13; # Lock Screen
      wvous-tl-corner = 2; # Mission Control
      wvous-tr-corner = 4; # Desktop
    };
    finder.ShowPathbar = true;
    trackpad.ActuationStrength = 0;
    trackpad.FirstClickThreshold = 0;
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };
}
