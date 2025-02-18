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
  nix.settings = {
    trusted-users = ["@admin"];
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = false;
    experimental-features = "nix-command flakes";
  };

  environment.pathsToLink = ["/share/zsh"];
  environment.systemPath = [config.homebrew.brewPrefix];
  environment.shells = [pkgs.zsh];

  environment.variables = {
    DOCKER_HOST = "unix:///Users/jonathan/.colima/default/docker.sock";
    NODE_EXTRA_CA_CERTS = lib.optional cvent "/Library/Application Support/Netskope/STAgent/download/nscacert.pem";
  };

  fonts.packages = [
    (pkgs.nerdfonts.override {
      fonts = ["FiraCode"];
    })
  ];

  programs.zsh.enable = true;

  services.nix-daemon.enable = true;

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";
    brews = [
      # gh is implicitly installed for attestation purposes.
      # this prevents it from being repeatedly installed, then uninstalled
      "gh"
    ];
    casks =
      [
        # https://github.com/NixOS/nixpkgs/issues/254944
        "1password"
        # Not available in nixpkgs
        "disk-inventory-x"
        # The 1Password extension does not unlock with biometrics if FF is installed via nix
        "firefox"
        # Not available in nixpkgs
        "lulu"
        # Raycast won't configure itself to run at startup if installed by nix
        "raycast"
        # Nix is refusing to build slack
        # mkdir: cannot create directory '/nix/store/8sxv71mr0sa9qdg02b4fflwaf0jglpra-slack-4.39.95/Applications/Slack.app': Operation not permitted
        "slack"
        # Nix is refusing to build vscode
        # mkdir: cannot create directory '/nix/store/df3lynf0asnl973l6mhpk5749c5z642j-vscode-1.92.0/Applications/Visual Studio Code.app': Operation not permitted
        "visual-studio-code"
        # Warp from nix will complain about not being able to auto-update on startup
        "warp"
      ]
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-outlook"
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-excel";
  };

  security.pam.enableSudoTouchIdAuth = true;
  security.pki.certificateFiles = lib.optional cvent "/Library/Application Support/Netskope/STAgent/download/nscacert.pem";

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
          "/Applications/Warp.app"
          "/Applications/Firefox.app"
        ]
        ++ lib.optional cvent "/Applications/Slack.app"
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
