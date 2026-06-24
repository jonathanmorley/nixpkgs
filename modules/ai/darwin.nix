{
  config,
  lib,
  pkgs,
  ...
}: let
  lapdogDesktopHooks = pkgs.writeShellScriptBin "lapdog-desktop-hooks" (builtins.readFile ./lapdog-desktop-hooks.sh);
  enableLapdogHooks = config.system.primaryUser != "runner";
  lapdogSslCertFile =
    config.environment.variables.SSL_CERT_FILE
    or (config.environment.variables.NIX_SSL_CERT_FILE or "/etc/ssl/certs/ca-certificates.crt");
in {
  environment.systemPackages = [
    lapdogDesktopHooks
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = lib.mkIf enableLapdogHooks {
    taps = [
      {
        name = "datadog/lapdog";
        # Homebrew 6 requires explicitly trusting non-official taps before
        # loading their formulae during `brew bundle`.
        trusted = true;
      }
    ];
    brews = [
      # Datadog distributes Lapdog from its own Homebrew tap.
      "lapdog"
      # Lapdog's generated entry points use this Homebrew Python in their shebangs.
      "python@3.13"
    ];
    casks = [
      # Codex Desktop is distributed as a Homebrew cask.
      "codex-app"
    ];
  };

  launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY = lib.mkIf enableLapdogHooks "/usr/local/bin/claude-lapdog-desktop";

  system.activationScripts.extraActivation.text = lib.mkIf enableLapdogHooks ''
    PRIMARY_USER="${config.system.primaryUser}" \
    HOMEBREW_PREFIX="${config.homebrew.prefix}" \
    LAPDOG_BIN="${config.homebrew.prefix}/bin/lapdog" \
    LAPDOG_SSL_CERT_FILE="${lapdogSslCertFile}" \
      ${lib.getExe lapdogDesktopHooks} install
  '';
}
