_: {
  # Trajectory is installed per-user by modules/ai/trajectory.nix, gated on
  # services.trajectory.enable, so consumers can switch it off entirely.

  # OpenChamber Desktop is installed by Nix (see pkgs/openchamber-desktop,
  # wired into home.packages in modules/ai/home.nix) rather than Homebrew:
  # its OpenChamber.app bundle has no bin artifacts, so terminal `opencode`
  # keeps resolving to the v2 CLI. OpenCode Desktop is intentionally not
  # installed.
}
