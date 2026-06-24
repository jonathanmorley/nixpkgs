{
  config,
  lib,
  ...
}: let
  isCiRunner = config.home.username == "runner";
  context = ''
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

    ## Networking

    Some Cvent endpoints are behind VPN. If requests to Cvent services fail or time out, the user may need to connect to the Cvent VPN for them to become accessible.

    ## Superpowers Plugin

    When executing plans, do not prompt for which execution method to use. Use 'Subagent-Driven' execution when tasks are genuinely independent and parallelizable; for linear or small plans, execute inline.
  '';
in
  lib.mkIf (!isCiRunner) {
    programs.claude-code = {
      enable = true;
      context = context;
    };

    programs.codex = {
      enable = true;
      context = context;
    };

    programs.opencode = {
      enable = true;
      context = context;
    };

    programs.zsh.initContent = ''
      rbw unlock

      claude-raw() {
        command claude "$@"
      }

      claude() {
        command claude-lapdog "$@"
      }

      codex-raw() {
        command codex "$@"
      }

      codex() {
        command codex-lapdog "$@"
      }
    '';

    programs.git.ignores = [
      ".claude/settings.local.json"
    ];
  }
