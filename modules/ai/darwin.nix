{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.trajectory
  ];

  # OpenChamber Desktop is installed by Nix (see pkgs/openchamber-desktop,
  # wired into home.packages in modules/ai/home.nix) rather than Homebrew:
  # its OpenChamber.app bundle has no bin artifacts, so terminal `opencode`
  # keeps resolving to the v2 CLI. OpenCode Desktop is intentionally not
  # installed.
}
