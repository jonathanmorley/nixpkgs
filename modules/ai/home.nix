{
  lib,
  pkgs,
  config,
  ...
}: {
  home.packages = [
    # OpenChamber Desktop .app bundle (see pkgs/openchamber-desktop).
    # Home Manager linkApps symlinks it into ~/Applications. OpenCode
    # Desktop is intentionally not installed.
    pkgs.openchamber-desktop
  ];

  programs.opencode = {
    enable = true;
    context = ''
      Follow repository conventions and keep changes focused. Test behavior, run relevant checks, and update documentation when appropriate.
    '';
    settings = {
      # Trajectory plugin/MCP/skills are wired into OpenCode only when
      # services.trajectory.opencode.enable is set. The opencode-claude-compat
      # plugin above already provides a Claude Code compatibility layer, so
      # wiring Trajectory in OpenCode too risks duplicating its configuration.
      plugin =
        [
          # Minimal Claude Code compat fork (see https://github.com/jonathanmorley/opencode-claude-compat) — was oh-my-openagent@4.19.4
          "@jonathanmorley/opencode-claude-compat@0.3.0"
          "@openchamber/opencode-claude@1.3.7"
          "@warp-dot-dev/opencode-warp@0.1.7"
          "superpowers@git+https://github.com/obra/superpowers.git#8ca22dba9a94f28898bbce59f2537ff4d87c747d"
          "@dietrichgebert/ponytail@4.12.0"
        ]
        ++ lib.optional config.services.trajectory.opencode.enable
        "${pkgs.trajectory}/.trajectory/plugin/trajectory-opencode";
      mcp = lib.optionalAttrs config.services.trajectory.opencode.enable {
        trajectory = {
          type = "local";
          command = ["${pkgs.trajectory}/bin/trajectory" "mcp"];
          enabled = true;
        };
      };
      skills = lib.optionalAttrs config.services.trajectory.opencode.enable {
        paths = ["${pkgs.trajectory}/.trajectory/plugin/trajectory-opencode/skills"];
      };
    };
  };

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
    clients = ["cc"];
  };

  # Register Trajectory plugin with configured clients on every activation.
  # OpenCode needs no registration — its plugin is loaded via the settings.plugin path.
  home.activation.trajectory-setup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Ensure Homebrew and profile binaries are on PATH for client detection
    export PATH="/opt/homebrew/bin:/usr/local/bin:''${PATH:-}"

    clients="${lib.concatStringsSep "," config.services.trajectory.clients}"
    if [ -n "$clients" ]; then
      ${pkgs.trajectory}/bin/trajectory setup --clients "$clients" --non-interactive || true
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
  ];

  # Disable fsmonitor for git, as it can cause worktree operations to hang indefinitely on macOS. See
  # See https://github.com/anthropics/claude-code/issues/75781
  programs.git.settings.core.fsmonitor = false;
}
