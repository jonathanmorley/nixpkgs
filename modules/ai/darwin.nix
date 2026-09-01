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
    # brew casks are the signed upstream builds and install only the .app
    # bundles — no bin artifacts, so terminal `opencode` keeps resolving to
    # the v1 CLI.
    #
    # Stable desktop (OpenCode.app) is the general-release cask. The beta
    # desktop (OpenCode Beta.app) tracks https://github.com/anomalyco/opencode-beta
    # (via https://opencode.ai/download/beta/darwin-aarch64-dmg) for tabs +
    # nightly features; the beta tap dropped `conflicts_with` so both apps
    # coexist.
    "opencode-desktop"
    "local/homebrew-opencode-beta/opencode-desktop-beta"
  ];
}
