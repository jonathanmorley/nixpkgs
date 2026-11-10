# A `trajectory` for PATH that prefers an install managed outside Nix (the
# upstream installer or an MDM, which self-update under $TRAJECTORY_HOME,
# default ~/.trajectory) and falls back to the Nix package. One binary
# version then touches that directory's state, and PATH still works
# without the other install. See launcher.sh.
#
# With `selector`, a file picks the install at run time instead: `installed`
# (the behaviour above, and the default) or `nix`, which runs the package in
# its own home and port. `trajectory-select` writes and reports it.
{
  bash,
  coreutils,
  lib,
  replaceVars,
  runCommand,
  # The fallback, normally pkgs.trajectory.
  trajectory,
  # null, or:
  #   file: the selector file, relative to $HOME
  #   home: the Nix install's TRAJECTORY_HOME (absolute)
  #   port: the Nix install's serve port
  #   installedPort: the other install's serve port, for trajectory-select
  selector ? null,
}: let
  withSelector = selector != null;
  vars = {
    bash = lib.getExe bash;
    realpath = "${coreutils}/bin/realpath";
    trajectory = lib.getExe trajectory;
    selectorFile =
      if withSelector
      then selector.file
      else "";
    nixHome =
      if withSelector
      then selector.home
      else "";
    nixPort =
      if withSelector
      then toString selector.port
      else "";
  };
  # Both go inside single-quoted shell literals.
  safe = s: builtins.match "[A-Za-z0-9._/+-]+" s != null;
in
  assert withSelector -> !(lib.hasPrefix "/" selector.file) && safe selector.file;
  assert withSelector -> lib.hasPrefix "/" selector.home && safe selector.home;
    runCommand "trajectory-launcher" {
      meta.mainProgram = "trajectory";
      passthru = {inherit trajectory selector;};
    } (''
        install -Dm755 ${replaceVars ./launcher.sh vars} "$out/bin/trajectory"
      ''
      + lib.optionalString withSelector ''
        install -Dm755 ${replaceVars ./select.sh (vars
          // {
            installedPort = toString selector.installedPort;
            mkdir = "${coreutils}/bin/mkdir";
            mktemp = "${coreutils}/bin/mktemp";
            mv = "${coreutils}/bin/mv";
            rm = "${coreutils}/bin/rm";
          })} "$out/bin/trajectory-select"
      '')
