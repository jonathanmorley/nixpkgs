{...}: {
  homebrew = {
    taps = [
      "didhd/tap"
    ];
    casks = [
      # Not available in nixpkgs
      "didhd/tap/amazon-bedrock-client"
      # Stay on latest better
      "opencode-desktop"
      # For running local AI models
      "ollama-app"

    ];
  };
}
