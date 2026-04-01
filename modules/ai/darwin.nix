{...}: {
  homebrew = {
    taps = [
      "didhd/tap"
    ];
    casks = [
      # Not available in nixpkgs
      "didhd/tap/amazon-bedrock-client"
      # Stay on latest better
      "claude-code@latest"
      # Stay on latest better
      "copilot-cli"
      # For running local AI models
      "ollama-app"
      # Stay on latest better
      "claude-code"
      "claude"
    ];
  };
}
