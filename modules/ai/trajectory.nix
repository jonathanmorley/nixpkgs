{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.trajectory;
  homeDirectory = config.home.homeDirectory;
  defaultHome = "${homeDirectory}/.trajectory";

  # A path under the home directory, relative to it, or "" if it is not
  # under it or not in normal form (an empty, `.` or `..` segment, which
  # includes a trailing `/`): string comparisons below rely on normal form.
  relativeToHome = path: let
    relative = lib.removePrefix "${homeDirectory}/" path;
    segments = lib.splitString "/" relative;
  in
    if lib.hasPrefix "${homeDirectory}/" path && builtins.all (s: s != "" && s != "." && s != "..") segments
    then relative
    else "";
  homeRelative = relativeToHome cfg.home;
  selectorRelative = relativeToHome cfg.selector.file;
  # The installed install's home is ~/.trajectory; the Nix home must be
  # neither it nor inside it. Compared in lower case: on a case-insensitive
  # file system (APFS by default) ~/.Trajectory is the same directory.
  insideInstalledHome = lib.toLower (builtins.head (lib.splitString "/" homeRelative)) == ".trajectory";

  # What goes on PATH and runs the agents: the package itself, or a launcher
  # that prefers an install managed outside Nix (see pkgs/trajectory/launcher.sh),
  # optionally choosing between the two at run time with the selector.
  binary =
    if cfg.selector.enable
    then
      pkgs.callPackage ../../pkgs/trajectory/launcher.nix {
        trajectory = cfg.package;
        selector = {
          file = selectorRelative;
          inherit (cfg) home;
          inherit (cfg.server) port;
          installedPort = cfg.selector.installedPort;
        };
      }
    else if cfg.preferInstalled
    then pkgs.callPackage ../../pkgs/trajectory/launcher.nix {trajectory = cfg.package;}
    else cfg.package;

  configDefaultsYaml = pkgs.writers.writeYAML "trajectory-config.defaults.yaml" cfg.managedDefaults;

  configYaml = pkgs.writers.writeYAML "trajectory-config.yaml" {
    # Credentials live in the OS keychain. Without a mode the auth section
    # stays empty but is kept so the file mirrors what `trajectory config`
    # writes.
    auth = lib.optionalAttrs (cfg.auth.mode != "") {inherit (cfg.auth) mode;};
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
    # Without user_email, trajectory.user_email is the user name plus identity.user_email_suffix, never git.
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

    home = lib.mkOption {
      type = lib.types.str;
      default = defaultHome;
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.trajectory"'';
      description = ''
        The Nix install's TRAJECTORY_HOME, under the home directory. The
        config files are written here. Only the selector's `nix` mode runs
        Trajectory in it, so without the selector it must stay the default.
      '';
    };

    auth = {
      mode = lib.mkOption {
        type = lib.types.enum ["" "managed_keychain"];
        default = "";
        description = ''
          How Trajectory finds credentials. `managed_keychain` reads only the
          OS keychain accounts named by each destination's `api_key_ref`.
        '';
      };
    };

    managedDefaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      example = lib.literalExpression ''
        {
          auth.mode = "managed_keychain";
          required_destinations = [
            {
              name = "team";
              type = "dd_llmobs";
              site = "datadoghq.com";
              ml_app = "coding-agents";
              api_key_ref = "team-trajectory-api-key";
            }
          ];
        }
      '';
      description = ''
        Written to config.defaults.yaml in the home, Trajectory's managed
        defaults: for managed keys (required destinations, auth.mode,
        export.site and others) these win over config.yaml. Use it to give a
        Nix install the same organization settings as another install,
        without syncing them from org.config_source. Holds no secrets: name
        keychain accounts with `api_key_ref`. Not written when empty.
      '';
    };

    selector = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Choose between this Nix install and an install managed outside Nix
          at run time, without a rebuild. The launcher on PATH reads
          `selector.file` (or TRAJECTORY_ACTIVE): `nix` runs the package with
          TRAJECTORY_HOME set to `home`, TRAJECTORY_PORT to `server.port`, and
          client reconcile turned off, so it never rewrites the other
          install's client integrations; anything else, or no file, runs the
          other install as `preferInstalled` does. `trajectory-select` writes
          and reports the choice. Serve starts on demand, so the launchd
          agents, `clients` and the OpenCode wiring must be off: wire clients
          to the launcher yourself.
        '';
      };

      file = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.configHome}/trajectory/active";
        defaultText = lib.literalExpression ''"''${config.xdg.configHome}/trajectory/active"'';
        description = "The selector file, under the home directory. It holds `nix` or `installed`.";
      };

      installedPort = lib.mkOption {
        type = lib.types.port;
        default = 19222;
        description = "The serve port of the install managed outside Nix, which `server.port` must differ from.";
      };
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

    clients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Coding-agent clients to register with Trajectory via `trajectory setup --clients`";
      example = ["cc" "codex" "cursor"];
    };

    opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Wire the Trajectory plugin, MCP server, and skills into OpenCode. Disable when a Claude Code compatibility layer already provides Trajectory config in OpenCode to avoid duplication.";
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

    configFile = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Write ~/.trajectory/config.yaml from the options above. Disable when
          another install (the upstream installer or an MDM) owns that file.
        '';
      };
    };

    preferInstalled = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Put a launcher on PATH that runs $TRAJECTORY_HOME/bin/trajectory
        (default ~/.trajectory/bin/trajectory) when it exists, and the
        package otherwise, so a self-updating install managed outside Nix
        keeps one binary version over its state. The agents and client setup
        use the same launcher.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = homeRelative != "";
          message = "services.trajectory.home (${cfg.home}) must be a normal path under the home directory (${homeDirectory}), without empty, `.` or `..` segments or a trailing `/`.";
        }
        {
          assertion = cfg.selector.enable || cfg.home == defaultHome;
          message = "services.trajectory.home is only used by the selector; set services.trajectory.selector.enable or leave home at ${defaultHome}.";
        }
      ]
      ++ lib.optionals cfg.selector.enable [
        {
          assertion = !insideInstalledHome;
          message = "services.trajectory.home must be neither ${defaultHome} nor inside it with the selector: that directory belongs to the other install.";
        }
        {
          assertion = cfg.server.port != cfg.selector.installedPort;
          message = "services.trajectory.server.port must differ from selector.installedPort (${toString cfg.selector.installedPort}) with the selector.";
        }
        {
          assertion = selectorRelative != "";
          message = "services.trajectory.selector.file (${cfg.selector.file}) must be a normal path under the home directory (${homeDirectory}), without empty, `.` or `..` segments or a trailing `/`.";
        }
        {
          assertion = !cfg.serve.enable;
          message = "services.trajectory.serve.enable must be false with the selector: serve starts on demand for the selected install.";
        }
        {
          assertion = !cfg.view.enable;
          message = "services.trajectory.view.enable must be false with the selector.";
        }
        {
          assertion = cfg.clients == [];
          message = "services.trajectory.clients must be empty with the selector: `trajectory setup` would rewrite client integrations the other install shares.";
        }
        {
          assertion = !cfg.opencode.enable;
          message = "services.trajectory.opencode.enable must be false with the selector: its MCP entry runs the package outside the selector.";
        }
      ];

    home.packages = [binary];

    # Trajectory configuration
    home.file."${homeRelative}/config.yaml" = lib.mkIf cfg.configFile.enable {source = configYaml;};
    home.file."${homeRelative}/config.defaults.yaml" = lib.mkIf (cfg.configFile.enable && cfg.managedDefaults != {}) {source = configDefaultsYaml;};

    # Register the Trajectory plugin with configured clients on every
    # activation. OpenCode needs no registration: its plugin is loaded via
    # the settings.plugin path in modules/ai/home.nix.
    home.activation.trajectory-setup = lib.mkIf (cfg.clients != []) (lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Ensure Homebrew and profile binaries are on PATH for client detection
      export PATH="/opt/homebrew/bin:/usr/local/bin:''${PATH:-}"

      ${binary}/bin/trajectory setup --clients "${lib.concatStringsSep "," cfg.clients}" --non-interactive || true
    '');

    # Launchd agent for trajectory serve
    launchd.agents.trajectory-serve = lib.mkIf cfg.serve.enable {
      enable = true;
      config = {
        ProgramArguments = [
          "${binary}/bin/trajectory"
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
          "${binary}/bin/trajectory"
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
