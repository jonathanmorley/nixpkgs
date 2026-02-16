# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Nix is managed by the Determinate Nix Installer, not nix-darwin.
  nix.enable = false;

  # Manually write custom settings to the designated file
  environment.etc."nix/nix.custom.conf".text = ''
    # Your custom Nix configuration settings go here
    extra-experimental-features = ca-derivations impure-derivations
    trusted-users = ${config.system.primaryUser}

    extra-substituters = https://nix-community.cachix.org https://jonathanmorley.cachix.org
    extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= jonathanmorley.cachix.org-1:5P5EOY4b+AC2G1XIzjluXmoWBSK6GiMg4UHV4+gCgwI=
  '';

  environment.pathsToLink = ["/share/zsh"];
  environment.systemPath = [config.homebrew.brewPrefix];
  environment.shells = [pkgs.zsh];

  fonts.packages = [pkgs.nerd-fonts.fira-code];

  programs.zsh.enable = true;

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";
    casks = [
      # Not available in nixpkgs
      "eqmac"
      # The 1Password extension does not unlock with biometrics if FF is installed via nix
      "firefox"
      # ice-bar is still at 0.11.12. brew beta or 0.11.13 needed for Tahoe compatability
      "jordanbaird-ice@beta"
      # Not available in nixpkgs
      "lulu"
      # Not available in nixpkgs
      "oversight"
      # https://github.com/warpdotdev/Warp/issues/1991
      "warp"
      # Insiders is not available in nixpkgs
      "visual-studio-code@insiders"
      # Cannot allow screensharing with nix package
      "zoom"
    ];
  };

  security.pam.services.sudo_local.touchIdAuth = true;

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
      persistent-apps = [
        "/Applications/Warp.app"
        "/Applications/Firefox.app"
      ];
      show-recents = false;
      wvous-bl-corner = 5; # Start Screen Saver
      wvous-br-corner = 13; # Lock Screen
      wvous-tl-corner = 2; # Mission Control
      wvous-tr-corner = 4; # Desktop
    };
    finder.ShowPathbar = true;
    trackpad = {
      ActuationStrength = 0;
      FirstClickThreshold = 0;
    };
  };

  # right clicking behaviour (bottom right corner)
  system.defaults.trackpad.TrackpadRightClick = false;
  system.defaults.NSGlobalDomain."com.apple.trackpad.trackpadCornerClickBehavior" = 1;

  # disable pinch-to-zoom
  # This doesnt take effect, even after restarting the dock
  system.defaults.CustomUserPreferences = {
    "com.apple.AppleMultitouchTrackpad".TrackpadPinch = 0;
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.activationScripts.extraActivation.text = ''
    # Force reload of preference cache to apply trackpad settings
    killall cfprefsd 2>/dev/null || true
  '';
}
