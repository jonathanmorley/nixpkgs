#!@bash@
# shellcheck shell=bash
# trajectory-select [nix|installed]: picks the Trajectory install that the
# `trajectory` launcher beside this script runs, by writing
# $HOME/@selectorFile@, then reports it. With no argument it only reports.
set -euo pipefail

selector_file='@selectorFile@'

usage() {
  cat <<'EOF'
Usage: trajectory-select [nix|installed]

  nix        run the Nix-packaged Trajectory in its own home and port
  installed  run the install that owns ~/.trajectory (the default)

With no argument, print the selected install, its binary, home and port,
and whether its serve is listening. TRAJECTORY_ACTIVE, when set, overrides
the file for the processes that see it.
EOF
}

if [ -z "${HOME:-}" ]; then
  echo "trajectory-select: HOME is not set" >&2
  exit 1
fi
file="$HOME/$selector_file"

case $# in
0) ;;
1)
  case $1 in
  nix | installed)
    dir=${file%/*}
    @mkdir@ -p "$dir"
    tmp=$(@mktemp@ "$dir/.active.XXXXXX")
    trap '@rm@ -f "$tmp"' EXIT
    printf '%s\n' "$1" >"$tmp"
    @mv@ -f "$tmp" "$file"
    trap - EXIT
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
  esac
  ;;
*)
  usage >&2
  exit 2
  ;;
esac

# The same choice the launcher makes.
active=${TRAJECTORY_ACTIVE:-}
source=TRAJECTORY_ACTIVE
if [ -z "$active" ]; then
  source=$file
  if [ -f "$file" ]; then
    read -r active <"$file" || true
  else
    source=default
  fi
fi
case $active in
nix) ;;
installed) ;;
'') active=installed ;;
*)
  echo "trajectory-select: $source holds '$active', which is neither nix nor installed; the installed install runs" >&2
  active=installed
  ;;
esac

if [ "$active" = nix ]; then
  binary='@trajectory@'
  home='@nixHome@'
  port='@nixPort@'
else
  home=${TRAJECTORY_HOME:-$HOME/.trajectory}
  port=${TRAJECTORY_PORT:-@installedPort@}
  launcher="${BASH_SOURCE[0]%/*}/trajectory"
  binary='@trajectory@'
  if [ -x "$home/bin/trajectory" ] && [ "$(@realpath@ "$home/bin/trajectory")" != "$(@realpath@ "$launcher")" ]; then
    binary="$home/bin/trajectory"
  fi
fi

if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
  serve=listening
else
  serve="not listening"
fi

cat <<EOF
active: $active ($source)
binary: $binary
home: $home
port: $port
serve: $serve
restart: running OpenCode, Claude Code and Trajectory MCP processes keep the install they started with; restart them to switch.
EOF
