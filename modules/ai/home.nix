{pkgs, ...}: {
  home.file.".claude/CLAUDE.md".text = ''
    # Personal preferences

    ## General

    I like to keep test-coverage high, and test-driven development is a good way to ensure that.
    I like to match the style and conventions of the codebase I'm working in, even if they don't match other personal preferences.
    I prefer to use TypeScript for new projects, unless there is a compelling reason to use another language.

    ## NodeJS

    I prefer pnpm as a package manager over npm or yarn.
    I prefer `execa` over something like `child_process`.
    I prefer `vitest` over `jest` for testing.
    I like to use @tsconfig/... for my TypeScript configuration, and I prefer to extend from those rather than writing my own from scratch.
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
    rtk init --global --hook-only --auto-patch >/dev/null
  '';
}
