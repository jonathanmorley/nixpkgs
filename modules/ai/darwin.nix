{...}: {
  homebrew = {
    taps = [
      "didhd/tap"
    ];
    brews = [
      # Stay on latest better
      "opencode"
    ];
    casks = [
      # Not available in nixpkgs
      "didhd/tap/amazon-bedrock-client"
      # For running local AI models
      "ollama-app"

    ];
  };
}
