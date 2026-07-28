{...}: {
  # Non-work applications — only included when the "personal" profile is active.
  homebrew.casks = [
    # The GUI is not available in nixpkgs
    "tailscale-app"
    "balenaetcher"
    "bambu-studio"
    # Not available in nixpkgs
    "chrome-remote-desktop-host"
  ];
}
