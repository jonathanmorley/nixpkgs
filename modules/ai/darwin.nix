{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.trajectory
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew.casks = [
    # nixpkgs' opencode-desktop is unusable here: its darwin build ships a
    # capitalized bin/OpenCode shim that silently shadows the opencode CLI in
    # the shared home-manager profile (case-insensitive APFS never triggers the
    # buildEnv collision check), and the Nix build disables macOS code signing,
    # so the app's GPU/network helper processes crash-loop. The brew cask is
    # the signed upstream build and installs only OpenCode.app — no bin
    # artifacts, so terminal `opencode` keeps resolving to the CLI.
    "opencode-desktop"
  ];
}
