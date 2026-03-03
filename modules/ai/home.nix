{pkgs, ...}: {
  home.file.".claude/CLAUDE.md".text = ''
    > **This file is managed by Nix.** Do not edit `~/.claude/CLAUDE.md` directly.
    > Changes should be made in `~/Developer/nixpkgs/modules/ai/home.nix` and applied via your Nix configuration.

    # Personal preferences

    ## General

    I like to keep test-coverage high, and test-driven development is a good way to ensure that.
    I like to match the style and conventions of the codebase I'm working in, even if they don't match other personal preferences.
    I prefer to use TypeScript for new projects, unless there is a compelling reason to use another language.
    Prefer using existing package dependencies over writing custom code when a well-maintained package already solves the problem.
    Remember to update documentation in the repository (e.g., READMEs, inline docs) when making changes that affect documented behavior.
    Keep PRs and commits small and focused on a single concern. Avoid scope creep beyond what was requested.
    Run the project's formatter and linter before considering a task done.
    I use Nx as a build system and monorepo tool.

    ## NodeJS

    I prefer pnpm as a package manager over npm or yarn.
    I prefer `execa` over something like `child_process`.
    I prefer `vitest` over `jest` for testing.
    I like to use @tsconfig/... for my TypeScript configuration, and I prefer to extend from those rather than writing my own from scratch.
    Place tests in a top-level `tests/` directory, using `*.test.ts` naming.
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

  programs.git.ignores = [
    ".claude/settings.local.json"
  ];
}
