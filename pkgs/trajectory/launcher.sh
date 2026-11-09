#!@bash@
# shellcheck shell=bash
# Runs the Trajectory install that owns $TRAJECTORY_HOME (default
# ~/.trajectory) when it is present, else the Nix-packaged binary.
set -euo pipefail

home=${TRAJECTORY_HOME:-}
if [ -z "$home" ] && [ -n "${HOME:-}" ]; then
  home="$HOME/.trajectory"
fi
case $home in
/*)
  # Not when the install binary is a link back to this launcher: that
  # would loop. The environment is left alone, so whatever the install
  # binary spawns sees exactly what the user ran.
  if [ -x "$home/bin/trajectory" ] && [ "$(@realpath@ "$home/bin/trajectory")" != "$(@realpath@ "${BASH_SOURCE[0]}")" ]; then
    exec "$home/bin/trajectory" "$@"
  fi
  if [ -e "$home" ]; then
    echo "trajectory: $home has no runnable bin/trajectory; running the Nix-packaged binary" >&2
  fi
  ;;
?*)
  echo "trajectory: TRAJECTORY_HOME is not an absolute path; running the Nix-packaged binary" >&2
  ;;
esac
exec @trajectory@ "$@"
