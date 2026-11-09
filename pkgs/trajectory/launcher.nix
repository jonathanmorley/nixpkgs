# A `trajectory` for PATH that prefers an install managed outside Nix (the
# upstream installer or an MDM, which self-update under $TRAJECTORY_HOME,
# default ~/.trajectory) and falls back to the Nix package. One binary
# version then touches that directory's state, and PATH still works
# without the other install. See launcher.sh.
{
  bash,
  coreutils,
  lib,
  replaceVars,
  runCommand,
  # The fallback, normally pkgs.trajectory.
  trajectory,
}:
runCommand "trajectory-launcher" {
  meta.mainProgram = "trajectory";
  passthru = {inherit trajectory;};
} ''
  install -Dm755 ${replaceVars ./launcher.sh {
    bash = lib.getExe bash;
    realpath = "${coreutils}/bin/realpath";
    trajectory = lib.getExe trajectory;
  }} "$out/bin/trajectory"
''
