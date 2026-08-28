{
  lib,
  pkgs,
  config,
  ...
}: let
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

    ## Repository Freshness

    Repositories cloned to disk (including `~/.nixpkgs` and repos under `~/Developer`) may be out of date with the latest upstream `main`. When an investigation reads a local repository, consider whether the checkout might be stale and, if freshness matters to the task, fetch the latest from upstream before drawing conclusions.

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
        # Minimal Claude Code compat fork (see https://github.com/jonathanmorley/opencode-claude-compat) — was oh-my-openagent@4.19.4
        "@jonathanmorley/opencode-claude-compat@0.1.0"
        "@warp-dot-dev/opencode-warp@0.1.7"
        "superpowers@git+https://github.com/obra/superpowers.git#b36e0829c6d0140e93cfef2ca599b1b07d4a7797"
        "@dietrichgebert/ponytail@4.9.0"
        "${pkgs.trajectory}/.trajectory/plugin/trajectory-opencode"
      ];
      mcp = {
        trajectory = {
          type = "local";
          command = ["${pkgs.trajectory}/bin/trajectory" "mcp"];
          enabled = true;
        };
      };
      skills = {
        paths = ["${pkgs.trajectory}/.trajectory/plugin/trajectory-opencode/skills"];
      };
      permission = {
        bash = {
          "*" = "allow";
          "sudo *" = "deny";
        };
      };
    };
  };

  # # OpenCode Desktop ships an OpenCode.app bundle that Home Manager links into
  # # ~/Applications via targets.darwin.linkApps. It is not packaged for
  # # x86_64-darwin, so guard on availability to keep Intel hosts evaluating.
  # home.packages =
  #   lib.optionals (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.opencode-desktop)
  #   [pkgs.opencode-desktop];

  # # oh-my-openagent config — no longer needed for compat-only fork.
  # # Revert (uncomment) if switching back to oh-my-openagent.
  # # NOTE: `defaultModel` (from specialArgs.opencodeModel) was removed for deadnix;
  # # restore `specialArgs` in the module args and `defaultModel` below before reverting.
  # xdg.configFile."opencode/oh-my-openagent.jsonc" = {
  #   source = pkgs.writers.writeJSON "oh-my-openagent.jsonc" {
  #     "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
  #     agents = {
  #       hephaestus = {
  #         model = defaultModel;
  #       };
  #       oracle = {
  #         model = defaultModel;
  #       };
  #       momus = {
  #         model = defaultModel;
  #       };
  #       explore = {
  #         model = defaultModel;
  #       };
  #       librarian = {
  #         model = defaultModel;
  #       };
  #     };
  #     categories = {
  #       deep = {
  #         model = defaultModel;
  #       };
  #       ultrabrain = {
  #         model = defaultModel;
  #       };
  #     };
  #     runtime_fallback = true;
  #   };
  # };

  # Enable trajectory with default configuration.
  services.trajectory = {
    enable = true;
    export.traces = "standard";
    identity.user_email = "morley.jonathan@gmail.com";
  };

  # Register Trajectory plugin with Claude Code on every activation.
  # OpenCode needs no registration — its plugin is loaded via the settings.plugin path.
  home.activation.trajectory-setup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Ensure Homebrew and profile binaries are on PATH for claude detection
    export PATH="/opt/homebrew/bin:/usr/local/bin:''${PATH:-}"

    if command -v claude >/dev/null 2>&1; then
      ${pkgs.trajectory}/bin/trajectory setup --clients cc --non-interactive || true
    fi
  '';

  # OpenCode server for OpenCode Mobile connectivity
  # Runs opencode serve as a launchd agent
  # Bound to localhost — exposed to tailnet via tailscale serve
  # Port 4096 is the default for OpenCode Mobile
  launchd.agents.opencode-serve = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.opencode}/bin/opencode"
        "serve"
        "--hostname"
        "127.0.0.1"
        "--port"
        "4096"
      ];

      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.xdg.dataHome}/opencode-server/serve.log";
      StandardErrorPath = "${config.xdg.dataHome}/opencode-server/serve.log";
    };
  };

  # Expose opencode server to Tailscale network
  home.activation.tailscale-opencode-serve = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if command -v tailscale >/dev/null 2>&1; then
      tailscale serve --bg --set-config --https=off 4096 2>/dev/null || true
    fi
  '';

  programs.git.ignores = [
    "/.worktrees/"
    ".omo"
    "docs/superpowers/"
  ];

  # Disable fsmonitor for git, as it can cause worktree operations to hang indefinitely on macOS. See
  # See https://github.com/anthropics/claude-code/issues/75781
  programs.git.settings.core.fsmonitor = false;
}
