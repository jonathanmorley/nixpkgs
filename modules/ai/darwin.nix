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

  homebrew.casks = [
    # nixpkgs' opencode-desktop is unusable here: its darwin build ships a
    # capitalized bin/OpenCode shim that silently shadows the opencode CLI in
    # the shared home-manager profile (case-insensitive APFS never triggers the
    # buildEnv collision check), and the Nix build disables macOS code signing,
    # so the app's GPU/network helper processes crash-loop. The brew cask is
    # the signed upstream build and installs only OpenCode.app — no bin
    # artifacts, so terminal `opencode` keeps resolving to the CLI.
    "opencode-desktop"
  ];
}
