{pkgs, ...}: {
  home.file.".claude/CLAUDE.md".text = ''
    # Claude Code Instructions
  '';

  # home.file.".github/copilot-instructions.md".text = ''
  #   # GitHub Copilot Instructions
  # '';

  home.packages = with pkgs; [
    ollama
    # Just to satisfy Zencoder's need for npx
    nodejs
  ];
}
