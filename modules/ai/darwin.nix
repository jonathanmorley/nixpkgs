{
  config,
  pkgs,
  ...
}: let
  aiToolPath = "/etc/profiles/per-user/${config.system.primaryUser}/bin:${config.homebrew.prefix}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  trajectorySetupAi = pkgs.writeShellScriptBin "trajectory-setup-ai" ''
    set -euo pipefail

    export PATH="${aiToolPath}:''${PATH:-}"

    ${pkgs.trajectory}/bin/trajectory setup --clients cc --non-interactive
    ${pkgs.trajectory}/bin/trajectory setup --clients codex --non-interactive
  '';
in {
  environment.systemPackages = [
    pkgs.mempalace
    pkgs.trajectory
    trajectorySetupAi
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew.brews = [
    # ollama's launchd service integration is only available via Homebrew on macOS.
    "ollama"
  ];
}
