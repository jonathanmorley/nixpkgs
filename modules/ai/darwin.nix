{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.trajectory
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew.casks = [
    # The nixpkgs opencode-desktop build is unusable here: its darwin build
    # ships a capitalized bin/OpenCode shim that silently shadows the opencode
    # CLI in the shared home-manager profile (case-insensitive APFS never
    # triggers the buildEnv collision check), and the Nix build disables macOS
    # code signing, so the app's GPU/network helper processes crash-loop. The
    # brew cask is the signed upstream build and installs only the .app
    # bundle — no bin artifacts, so terminal `opencode` keeps resolving to
    # the CLI.
    #
    # OpenCode Desktop tracks the v2 stable DMGs at
    # https://opencode.ai/files/bin/<version>/ (see taps/opencode and
    # https://opencode.ai/v2/docs); bump the version there to update. The
    # upstream homebrew-cask `opencode-desktop` still tracks the v1 releases,
    # so the fully-qualified local cask below takes precedence.
    "local/homebrew-opencode/opencode-desktop"
  ];
}
