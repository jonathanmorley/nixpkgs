#!@bash@
# shellcheck shell=bash
# Runs the Trajectory install that owns $TRAJECTORY_HOME (default
# ~/.trajectory) when it is present, else the Nix-packaged binary.
#
# Built with a selector, $HOME/@selectorFile@ (or TRAJECTORY_ACTIVE) picks
# the install first: `nix` runs the Nix-packaged binary in its own home and
# port; anything else is the behaviour above.
set -euo pipefail

selector_file='@selectorFile@'
if [ -n "$selector_file" ]; then
  active=${TRAJECTORY_ACTIVE:-}
  if [ -n "$active" ]; then
    source="TRAJECTORY_ACTIVE"
  else
    source="$selector_file"
    if [ -n "${HOME:-}" ] && [ -f "$HOME/$selector_file" ]; then
      read -r active <"$HOME/$selector_file" || true
    fi
  fi
  case $active in
  nix)
    # The client integrations (Claude Code's installed plugins, OpenCode's
    # config and plugin pointer) are shared with the other install. setup
    # and uninstrument rewrite them, so they're refused unless asked for.
    # The command is the first argument that isn't a flag.
    if [ "${TRAJECTORY_SELECTOR_ALLOW_SETUP:-}" != 1 ]; then
      for arg in "$@"; do
        case $arg in
        -*) continue ;;
        setup | uninstrument | uninstall)
          echo "trajectory: '$arg' rewrites the client integrations both installs share, so the selector's nix mode refuses it; set TRAJECTORY_SELECTOR_ALLOW_SETUP=1 to run it anyway" >&2
          exit 2
          ;;
        esac
        break
      done
    fi

    # Never the other install's home, or inside it, symlinks resolved and
    # case ignored (APFS is case-insensitive by default). Without HOME that
    # home is unknown, so nix mode refuses to run.
    if [ -z "${HOME:-}" ]; then
      echo "trajectory: HOME is not set, so the selector's nix mode can't check that @nixHome@ is outside the installed home; refusing it" >&2
      exit 2
    fi
    nix_home=$(@realpath@ -m '@nixHome@')
    installed_home=$(@realpath@ -m "$HOME/.trajectory")
    case ${nix_home,,}/ in
    "${installed_home,,}"/*)
      echo "trajectory: the Nix home @nixHome@ resolves to $nix_home, which is the installed home $installed_home or inside it; refusing the selector's nix mode" >&2
      exit 2
      ;;
    esac

    # The caller's TRAJECTORY_* variables (TRAJECTORY_BINARY,
    # TRAJECTORY_CAPTURE_URL, ...) may point at the other install, so only
    # its off switches pass through.
    while IFS= read -r name; do
      case $name in
      TRAJECTORY_DISABLED | TRAJECTORY_DISABLE_*) ;;
      TRAJECTORY_*) unset "$name" ;;
      esac
    done < <(compgen -e)

    # The selected install owns its home and port, and the intercepts send
    # captures to its serve. It must never reconcile client integrations: a
    # serve or MCP started in a second home rewrites them to point at itself.
    export TRAJECTORY_HOME='@nixHome@'
    export TRAJECTORY_PORT='@nixPort@'
    export TRAJECTORY_CAPTURE_URL='http://127.0.0.1:@nixPort@'
    export TRAJECTORY_DISABLE_RUNTIME_ASSET_RECONCILE=1
    export TRAJECTORY_DISABLE_STARTUP_RECONCILE=1
    export TRAJECTORY_DISABLE_CLIENT_WATCHERS=1
    # The user name Trajectory tags captures with (trajectory.user); it has
    # no config key, and the loop above dropped the caller's. Without one,
    # Trajectory uses the Unix user name.
    nix_user=@nixUser@
    if [ -n "$nix_user" ]; then
      export TRAJECTORY_USER="$nix_user"
    fi
    exec @trajectory@ "$@"
    ;;
  installed | '') ;;
  *)
    echo "trajectory: $source selects '$active', which is neither nix nor installed; running the installed install" >&2
    ;;
  esac
fi

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
