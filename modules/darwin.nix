# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  ...
}: let
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://jonathanmorley.cachix.org"
  ];
  trustedPublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "jonathanmorley.cachix.org-1:5P5EOY4b+AC2G1XIzjluXmoWBSK6GiMg4UHV4+gCgwI="
  ];
in {
  # Nix is managed by nix-darwin (vanilla Nix) now.
  #
  # Determinate Nix was originally used for its "certs from the macOS
  # Keychain" feature; that is reproduced here by exporting the system
  # keychains to a PEM bundle (see `updateNixKeychainCerts` below) and
  # pointing Nix's `ssl-cert-file` at it — exactly what determinate-nixd
  # did under the hood.
  #
  # Previous Determinate config (kept for reference, requires re-adding the
  # `determinate` flake input + module to flip back):
  #   determinateNix = {
  #     enable = true;
  #     customSettings = {
  #       trusted-users = [config.system.primaryUser];
  #       inherit substituters;
  #       trusted-public-keys = trustedPublicKeys;
  #     };
  #   };
  nix = {
    enable = true;
    # Keep Lix (the official installer already uses it); swap to pkgs.nix for
    # vanilla Nix from nixpkgs.
    package = pkgs.lix;
    settings = {
      # Certificates from the macOS Keychain (see updateNixKeychainCerts).
      ssl-cert-file = "/etc/nix/macos-keychain.crt";

      experimental-features = "nix-command flakes";

      trusted-users = [config.system.primaryUser];
      inherit substituters;
      trusted-public-keys = trustedPublicKeys;
    };
  };

  # Regenerate /etc/nix/macos-keychain.crt from the macOS Keychain on
  # activation. The export is byte-identical to what determinate-nixd wrote,
  # so the existing file keeps working until the keychain changes (then this
  # regenerates it). Run `darwin-rebuild switch` manually after changing
  # certificates in Keychain.
  system.activationScripts.updateNixKeychainCerts.text = ''
    /bin/mkdir -p /etc/nix
    /usr/bin/security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >/tmp/macos-keychain.crt
    /usr/bin/security find-certificate -a -p /Library/Keychains/System.keychain >>/tmp/macos-keychain.crt
    if ! /usr/bin/cmp -s /tmp/macos-keychain.crt /etc/nix/macos-keychain.crt; then
      /bin/cp /tmp/macos-keychain.crt /etc/nix/macos-keychain.crt
      /usr/sbin/chown root:wheel /etc/nix/macos-keychain.crt
      /bin/chmod 0644 /etc/nix/macos-keychain.crt
    fi
    /bin/rm -f /tmp/macos-keychain.crt
  '';

  environment.pathsToLink = ["/share/zsh"];
  environment.systemPath = ["${config.homebrew.prefix}/bin"];
  environment.shells = [pkgs.zsh];

  fonts.packages = [pkgs.nerd-fonts.fira-code];

  programs.zsh.enable = true;

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    enable = true;
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      cleanup = "uninstall";
    };
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
      # https://github.com/nixos/nixpkgs/issues/516928
      "warp"
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

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.activationScripts.extraActivation.text = ''
    # Force reload of preference cache to apply trackpad settings
    killall cfprefsd 2>/dev/null || true

    # Symlink gh into /usr/local/bin so non-Nix-aware apps (e.g. Claude Desktop) can find it
    mkdir -p /usr/local/bin
    ln -sf "${lib.getExe pkgs.gh}" /usr/local/bin/gh
  '';
}
