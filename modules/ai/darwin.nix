{
  config,
  pkgs,
  ...
}: let
  aiToolPath = "/etc/profiles/per-user/${config.system.primaryUser}/bin:${config.homebrew.prefix}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  trajectorySetupAi = pkgs.writeShellScriptBin "trajectory-setup-ai" ''
    set -euo pipefail

    export PATH="${aiToolPath}:''${PATH:-}"

    trajectory_home="''${TRAJECTORY_HOME:-$HOME/.trajectory}"
    mkdir -p "$trajectory_home"
    cat > "$trajectory_home/selfupdate.conf" <<'EOF'
    TRAJECTORY_INSTALL_OWNER=nix
    TRAJECTORY_SELF_UPDATE=disabled
    TRAJECTORY_SELF_UPDATE_URL=https://raw.githubusercontent.com/datadog-labs/trajectory/main/RELEASES.json
    EOF

    mkdir -p "$trajectory_home/bin"
    cat > "$trajectory_home/bin/trajectory" <<'EOF'
    #!/bin/sh
    exec "/etc/profiles/per-user/${config.system.primaryUser}/bin/trajectory" "$@"
    EOF
    chmod +x "$trajectory_home/bin/trajectory"

    ${pkgs.trajectory}/bin/trajectory setup --clients cc --non-interactive
    ${pkgs.trajectory}/bin/trajectory setup --clients codex --non-interactive
  '';
in {
  environment.systemPackages = [
    pkgs.trajectory
    trajectorySetupAi
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    casks = [
      # Codex Desktop is distributed as a Homebrew cask.
      "codex-app"
    ];
  };

  launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY = "/etc/profiles/per-user/${config.system.primaryUser}/bin/claude";
}
