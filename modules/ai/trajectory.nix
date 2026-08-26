{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.trajectory;

  configYaml = pkgs.writers.writeYAML "trajectory-config.yaml" {
    export = {
      site = cfg.export.site;
      ml_app = cfg.export.ml_app;
      metrics = cfg.export.metrics;
      traces = cfg.export.traces;
    };
    identity = {
      user_email = cfg.identity.user_email;
    };
    features = {
      enabled = cfg.features.enabled;
    };
  };
in {
  options.services.trajectory = {
    enable = lib.mkEnableOption "trajectory";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.trajectory;
      description = "The trajectory package to use";
    };

    export = {
      site = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Datadog site for export (e.g., datadoghq.com)";
      };

      ml_app = lib.mkOption {
        type = lib.types.str;
        default = "coding-agents";
        description = "ML app name for Datadog";
      };

      traces = lib.mkOption {
        type = lib.types.enum ["off" "standard"];
        default = "off";
        description = "Trace export mode";
      };

      metrics = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable metrics export";
      };
    };

    identity = {
      user_email = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "User email for trajectory identity";
      };
    };

    features = {
      enabled = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Enabled trajectory features";
      };
    };

    serve = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run trajectory serve as a launchd agent";
      };
    };

    view = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run trajectory view as a launchd agent (local-ui on port 8888)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Trajectory configuration
    home.file.".trajectory/config.yaml" = {
      source = configYaml;
      force = true;
    };

    # Launchd agent for trajectory serve
    launchd.agents.trajectory-serve = lib.mkIf cfg.serve.enable {
      enable = true;
      config = {
        ProgramArguments = [
          "${cfg.package}/bin/trajectory"
          "serve"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.xdg.dataHome}/trajectory/serve.log";
        StandardErrorPath = "${config.xdg.dataHome}/trajectory/serve.log";
      };
    };

    # Launchd agent for trajectory view (local-ui)
    launchd.agents.trajectory-view = lib.mkIf cfg.view.enable {
      enable = true;
      config = {
        ProgramArguments = [
          "${cfg.package}/bin/trajectory"
          "view"
          "--no-open"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.xdg.dataHome}/trajectory/view.log";
        StandardErrorPath = "${config.xdg.dataHome}/trajectory/view.log";
      };
    };
  };
}
