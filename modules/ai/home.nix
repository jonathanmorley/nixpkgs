{
  lib,
  pkgs,
  config,
  ...
}: let
  # Trajectory's OpenCode wiring needs both the service and its OpenCode
  # integration enabled; a consumer disabling services.trajectory must get
  # no references to the package at all.
  trajectoryOpenCode = config.services.trajectory.enable && config.services.trajectory.opencode.enable;
in {
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
          "@openchamber/opencode-claude@1.6.0"
          "superpowers@git+https://github.com/obra/superpowers.git#2ce8aa15d05bd57213e6f746f953aafb7ded7a8b"
          "@dietrichgebert/ponytail@5.3.2"
        ]
        ++ lib.optional trajectoryOpenCode
        "${pkgs.trajectory}/.trajectory/plugin/trajectory-opencode";
      mcp = lib.optionalAttrs trajectoryOpenCode {
        trajectory = {
          type = "local";
          command = ["${pkgs.trajectory}/bin/trajectory" "mcp"];
          enabled = true;
        };
      };
      skills = lib.optionalAttrs trajectoryOpenCode {
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

  programs.git.ignores = [
    "/.worktrees/"
    ".omo"
  ];

  # Disable fsmonitor for git, as it can cause worktree operations to hang indefinitely on macOS. See
  # See https://github.com/anthropics/claude-code/issues/75781
  programs.git.settings.core.fsmonitor = false;
}
