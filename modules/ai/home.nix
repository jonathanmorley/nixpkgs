{pkgs, ...}: {
  home.file.".claude/CLAUDE.md".text = ''
    # Personal preferences

    ## General

    I like to keep test-coverage high,
    and test-driven development is a good way to ensure that.

    ## NodeJS

    I prefer pnpm as a pacakge manager over npm or yarn.
    I prefer `execa` over something like `child_process`.
  '';

  # home.file.".github/copilot-instructions.md".text = ''
  #   # GitHub Copilot Instructions
  # '';

  home.packages = with pkgs; [
    ollama
    rtk
    # Just to satisfy Zencoder's need for npx
    nodejs
  ];

  programs.zsh.initContent = ''
    rtk init --global
  '';
}
