{lib, ...}: {
  options.jm = {
    profiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Profiles to enable for this host (e.g. \"personal\" for non-work apps).";
      example = ["personal"];
    };

    sshProvider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["1password" "bitwarden"]);
      default = null;
      description = "SSH provider for authentication and commit signing.";
      example = "1password";
    };

    sshKeys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "SSH public keys by domain (e.g. github.com).";
      example = {
        "github.com" = "ssh-ed25519 AAAAC3...";
      };
    };

    opencodeModel = lib.mkOption {
      type = lib.types.str;
      default = "opencode/big-pickle";
      description = "Model to use for OpenCode AI coding agents.";
      example = "opencode/big-pickle";
    };

    opencodeServer = lib.mkOption {
      type = lib.types.nullOr {
        enable = lib.types.bool;
        port = lib.types.int;
        hostname = lib.types.str;
        password = lib.types.nullOr lib.types.str;
      };
      default = null;
      description = "OpenCode server configuration for OpenCode Mobile connectivity.";
      example = {
        enable = true;
        port = 4096;
        hostname = "0.0.0.0";
        password = "strong-password";
      };
    };
  };
}
