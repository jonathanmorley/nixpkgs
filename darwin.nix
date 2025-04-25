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
    experimental-features = "nix-command flakes";
  };

  # Workaround for doing the first `darwin-rebuild switch`. Since nix-darwin only
  # overwrites files that it knows the contents of, I have to take the add the hash
  # of my /etc/nix/nix.conf here before doing my first rebuild so it can overwrite
  # it. You can also move the existing nix.conf to another location, but then none of
  # my settings, like substituters, will be applied when I do the first rebuild. So
  # the plan is to temporarily add the hash here and once the first rebuild is done,
  # remove it. There's an open issue for having nix-darwin backup the file and
  # replace it instead of refusing to run[1].
  #
  # Also, this is an internal option so it may change without notice.
  #
  # [1]: https://github.com/LnL7/nix-darwin/issues/149
  environment.etc."nix/nix.conf".knownSha256Hashes = [
    "cbc38cd586caa7bf3e3b296232ce2690ba42f756bea1b255ec38f99c53d91749"
  ];

  environment.pathsToLink = ["/share/zsh"];
  environment.systemPath = [config.homebrew.brewPrefix];
  environment.shells = [pkgs.zsh];

  environment.variables = {
    DOCKER_HOST = "unix:///Users/jonathan/.colima/default/docker.sock";
    NODE_EXTRA_CA_CERTS = lib.optional cvent "/Library/Application Support/Netskope/STAgent/download/nscacert.pem";
  };

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
  ];

  programs.zsh.enable = true;

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
        # The 1Password extension does not unlock with biometrics if FF is installed via nix
        "firefox"
        # Not available in nixpkgs
        "lulu"
        # Not available in nixpkgs
        "oversight"
        # https://github.com/warpdotdev/Warp/issues/1991
        "warp"
      ]
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-outlook"
      # Not available in nixpkgs
      ++ lib.optional cvent "microsoft-excel";
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
          "/Applications/Warp.app"
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
