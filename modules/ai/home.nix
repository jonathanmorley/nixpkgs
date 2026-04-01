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

    ## Networking

    Some Cvent endpoints are behind VPN. If requests to Cvent services fail or time out, the user may need to connect to the Cvent VPN for them to become accessible.

    ## Claude Code

    When making compromises in a plan or implementation (e.g., skipping edge cases, using a workaround, deferring a refactor), record them in the most appropriate location (TODO comments in code, project CLAUDE.md, or memory files) so that future sessions can resolve them.
    Commit often to preserve progress, but do not push unless explicitly asked.
    CI runs various targets including lint and unit tests. Run these before pushing (but not necessarily before every commit).
    When opening a PR, always add the `ai:autofix` label to it (e.g., `gh pr edit --add-label "ai:autofix"`).
    Always create a PR for completed work. PRs are my preferred workflow for reviewing and merging changes.

    ## Superpowers Plugin

    When executing plans, always use the 'Subagent-Driven' execution option. Do not prompt for which execution method to use.
  '';

  # home.file.".github/copilot-instructions.md".text = ''
  #   # GitHub Copilot Instructions
  # '';

  home.packages = with pkgs; [
    ollama
    # Just to satisfy Zencoder's need for npx
    nodejs
  ];

  programs.zsh.initContent = ''
    rbw unlock
  '';

  programs.git.ignores = [
    ".claude/settings.local.json"
  ];

  home.shellAliases.claude = "claude --permission-mode=bypassPermissions --enable-auto-mode --allow-dangerously-skip-permissions";
}
