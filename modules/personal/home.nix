{...}: {
  # Personal-only OpenCode MCP servers — only included when the "personal"
  # profile is active (see lib/mkDarwinSystem.nix). Keeps the baseline
  # (gha-aarch64-darwin, profiles = []) free of personal integrations.
  programs.opencode.settings.mcp.robinhood-trading = {
    type = "remote";
    url = "https://agent.robinhood.com/mcp/trading";
    enabled = true;
  };
}
