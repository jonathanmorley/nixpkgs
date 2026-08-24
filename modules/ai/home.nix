{
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  defaultModel = specialArgs.opencodeModel or "opencode/big-pickle";
  contextPrefix = lib.removeSuffix "\n" ''
    # Personal preferences

    ## General

    I like to keep test-coverage high, and test-driven development is a good way to ensure that.
    I like to match the style and conventions of the codebase I'm working in, even if they don't match other personal preferences.
    I prefer to use TypeScript for new projects, unless there is a compelling reason to use another language.
    Prefer using existing package dependencies over writing custom code when a well-maintained package already solves the problem.
    Ensure every package and repository has a README explaining how to use it. When adding new features or making significant changes, create or update relevant documentation (READMEs, doc sites, inline docs, etc.).
    Keep PRs and commits small and focused on a single concern. Avoid scope creep beyond what was requested.
    Run the project's formatter and linter before considering a task done.
    I use Nx as a build system and monorepo tool.

    ## System Configuration

    This computer is managed by Nix. The flake with configuration derivations is in `~/.nixpkgs`.

    ## Worktrees

    I prefer using an isolated Git worktree for all code changes. When creating one, use the repository-root `.worktrees/` directory.

    ## Testing

    Avoid tests that only assert static file contents. For skills, prefer evaluations that exercise the skill's behavior and validate its outcomes.

    When making compromises in a plan or implementation (e.g., skipping edge cases, using a workaround, deferring a refactor), record them in the most appropriate location (TODO comments in code, project CLAUDE.md, or memory files) so that future sessions can resolve them.
    Commit often to preserve progress, but do not push unless explicitly asked.
    CI runs various targets including lint and unit tests. Run these before pushing (but not necessarily before every commit).
    Before pushing, review the diff for bugs, logic errors, missing edge cases, typos, security issues, and unintended behavioral changes; fix anything found. For pushes with large diffs (roughly >300 lines or touching >5 files), dispatch a subagent to do this review instead of self-reviewing.
    When opening a PR, always add the `ai:autofix` label to it (e.g., `gh pr edit --add-label "ai:autofix"`).
    Always create a PR for completed work. PRs are my preferred workflow for reviewing and merging changes.

    ## NodeJS

    I prefer pnpm as a package manager over npm or yarn.
    I prefer `execa` over something like `child_process`.
    I prefer `vitest` over `jest` for testing.
    I like to use @tsconfig/... for my TypeScript configuration, and I prefer to extend from those rather than writing my own from scratch.
    Place tests in a top-level `tests/` directory, using `*.test.ts` naming.

  '';
  contextSuffix = ''
    ## Superpowers Plugin

    When executing plans, do not prompt for which execution method to use. Use 'Subagent-Driven' execution when tasks are genuinely independent and parallelizable; for linear or small plans, execute inline.
  '';
in {
  programs.opencode = {
    enable = true;
    context = contextPrefix + "\n" + contextSuffix;
    settings = {
      plugin = [
        "oh-my-openagent@4.19.0"
        "@warp-dot-dev/opencode-warp"
        "superpowers@git+https://github.com/obra/superpowers.git"
      ];
    };
  };

  # # OpenCode Desktop ships an OpenCode.app bundle that Home Manager links into
  # # ~/Applications via targets.darwin.linkApps. It is not packaged for
  # # x86_64-darwin, so guard on availability to keep Intel hosts evaluating.
  # home.packages =
  #   lib.optionals (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.opencode-desktop)
  #   [pkgs.opencode-desktop];

  xdg.configFile."opencode/oh-my-openagent.jsonc" = {
    source = pkgs.writers.writeJSON "oh-my-openagent.jsonc" {
      "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
      agents = {
        hephaestus = {
          model = defaultModel;
        };
        oracle = {
          model = defaultModel;
        };
        momus = {
          model = defaultModel;
        };
        explore = {
          model = defaultModel;
        };
        librarian = {
          model = defaultModel;
        };
      };
      categories = {
        deep = {
          model = defaultModel;
        };
        ultrabrain = {
          model = defaultModel;
        };
      };
      runtime_fallback = true;
    };
  };

  home.file.".trajectory/bin/trajectory" = {
    force = true;
    source = "${pkgs.trajectory}/libexec/trajectory";
  };

  home.file.".trajectory/selfupdate.conf" = {
    force = true;
    text = ''
      TRAJECTORY_INSTALL_OWNER=nix
      TRAJECTORY_SELF_UPDATE=disabled
    '';
  };

  home.file.".trajectory/config.defaults.yaml" = {
    force = true;
    text = ''
      capture:
        include_headless_agents: true
    '';
  };

  home.file.".trajectory/intercepts/intercept-shared.mjs" = {
    force = true;
    source = "${pkgs.trajectory}/share/trajectory/intercepts/intercept-shared.mjs";
  };

  home.file.".trajectory/intercepts/bun-llm-intercept.mjs" = {
    force = true;
    source = "${pkgs.trajectory}/share/trajectory/intercepts/bun-llm-intercept.mjs";
  };

  home.file.".trajectory/intercepts/node-llm-spy.cjs" = {
    force = true;
    source = "${pkgs.trajectory}/share/trajectory/intercepts/node-llm-spy.cjs";
  };

  programs.git.ignores = [
    "/.worktrees/"
    ".omo"
  ];

  # Disable fsmonitor for git, as it can cause worktree operations to hang indefinitely on macOS. See
  # See https://github.com/anthropics/claude-code/issues/75781
  programs.git.settings.core.fsmonitor = false;
}
