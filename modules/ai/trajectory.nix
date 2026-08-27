{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.trajectory;

  configYaml = pkgs.writers.writeYAML "trajectory-config.yaml" {
    # Credentials live in the OS keychain; the auth section stays empty but is
    # kept so the file mirrors what `trajectory config` writes.
    auth = {};
    deployment = {
      ring = cfg.deployment.ring;
    };
    server = {
      port = cfg.server.port;
    };
    local_ui = {
      auto_start = cfg.local_ui.auto_start;
    };
    capture = {
      redact_pii = cfg.capture.redact_pii;
      retention_days = cfg.capture.retention_days;
      max_disk_bytes = cfg.capture.max_disk_bytes;
      include_headless_agents = cfg.capture.include_headless_agents;
    };
    export = {
      site = cfg.export.site;
      ml_app = cfg.export.ml_app;
      metrics = cfg.export.metrics;
      traces = cfg.export.traces;
      sensitivity = {
        enabled = cfg.export.sensitivity.enabled;
        scanning_mode = cfg.export.sensitivity.scanning_mode;
        near_realtime_interval_minutes = cfg.export.sensitivity.near_realtime_interval_minutes;
      };
    };
    # An empty identity section means trajectory falls back to system/git identity.
    identity = lib.optionalAttrs (cfg.identity.user_email != "") {
      user_email = cfg.identity.user_email;
    };
    features = {
      enabled = cfg.features.enabled;
    };
    cross_client_resume = {
      enabled = cfg.cross_client_resume.enabled;
      targets = cfg.cross_client_resume.targets;
    };
    publish_trust = {
      allowed_origins = cfg.publish_trust.allowed_origins;
      require_committed = cfg.publish_trust.require_committed;
      allowed_sites = cfg.publish_trust.allowed_sites;
    };
    segmentation = {
      enabled = cfg.segmentation.enabled;
      interval = cfg.segmentation.interval;
    };
    org = {
      markers_repo = cfg.org.markers_repo;
      markers_path = cfg.org.markers_path;
      sync_interval = cfg.org.sync_interval;
    };
    required_destinations = cfg.required_destinations;
    tags = cfg.tags;
  };
in {
  options.services.trajectory = {
    enable = lib.mkEnableOption "trajectory";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.trajectory;
      description = "The trajectory package to use";
    };

    deployment = {
      ring = lib.mkOption {
        type = lib.types.str;
        default = "stable";
        description = "Release channel for updates, usually stable or beta";
      };
    };

    server = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 19222;
        description = "Local capture server port";
      };
    };

    local_ui = {
      auto_start = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatic local-ui startup from non-manual flows";
      };
    };

    capture = {
      redact_pii = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "PII redaction in captured content";
      };

      retention_days = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Local JSONL retention in days; 0 keeps files indefinitely";
      };

      max_disk_bytes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "Maximum disk usage for local capture in bytes; 0 means unlimited";
      };

      include_headless_agents = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Capture headless (non-interactive) agent sessions";
      };
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
        type = lib.types.enum ["off" "minimal" "standard" "full"];
        default = "off";
        description = "Trace export mode";
      };

      metrics = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable metrics export";
      };

      sensitivity = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable sensitivity classification of exported content";
        };

        scanning_mode = lib.mkOption {
          type = lib.types.enum ["off" "balanced" "near_realtime"];
          default = "off";
          description = "Sensitivity classification mode";
        };

        near_realtime_interval_minutes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 30;
          description = "Interval in minutes between near-realtime sensitivity scans";
        };
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

    cross_client_resume = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable cross-client transcript reconstruction";
      };

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Clients targeted by cross-client resume";
      };
    };

    publish_trust = {
      allowed_origins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Git origins allowed to load project publish.trajectory.yaml overlays";
      };

      require_committed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require project publish configs to be git-tracked";
      };

      allowed_sites = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Optional Datadog site allowlist for project-created destinations";
      };
    };

    segmentation = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Async task segmentation";
      };

      interval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Number of turns between segmentation passes";
      };
    };

    org = {
      markers_repo = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Repository providing managed organization markers";
      };

      markers_path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path within the markers repository";
      };

      sync_interval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3600;
        description = "Interval in seconds between organization config syncs";
      };
    };

    required_destinations = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      description = "Managed publish destinations that user and project configuration cannot remove";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Low-cardinality tags added to published Datadog spans and metrics";
      example = {
        team = "platform";
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
    home.file.".trajectory/config.yaml".source = configYaml;

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
