{config, ...}: let
  # The Home Manager profile's opencode (useUserPackages), not a store path:
  # the value survives version bumps and garbage collection without a new
  # login.
  opencodeBinary = "/etc/profiles/per-user/${config.system.primaryUser}/bin/opencode";
in {
  # Trajectory is installed per-user by modules/ai/trajectory.nix, gated on
  # services.trajectory.enable, so consumers can switch it off entirely.

  # OpenChamber Desktop is installed by Nix (see pkgs/openchamber-desktop,
  # wired into home.packages in modules/ai/home.nix) rather than Homebrew:
  # its OpenChamber.app bundle has no bin artifacts, so terminal `opencode`
  # keeps resolving to the v2 CLI. OpenCode Desktop is intentionally not
  # installed.

  # OpenChamber otherwise starts the OpenCode CLI bundled in its .app, which
  # lags the Nix one. It reads OPENCODE_BINARY from its environment, and as a
  # GUI app it only sees launchd's. envVariables sets it at activation only
  # (launchctl setenv does not outlive the login session), so the agent sets
  # it again at every login.
  launchd.user.envVariables.OPENCODE_BINARY = opencodeBinary;
  launchd.user.agents.opencode-binary-env.serviceConfig = {
    ProgramArguments = ["/bin/launchctl" "setenv" "OPENCODE_BINARY" opencodeBinary];
    RunAtLoad = true;
  };
}
