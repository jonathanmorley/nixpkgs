#!/usr/bin/env bash
# Tests pkgs/trajectory/launcher.sh against a fake Nix binary and a fake
# install under ~/.trajectory. Usage: trajectory-launcher.sh LAUNCHER
# The fake Nix binary must record `nix` and its arguments to "$RAN".
set -euo pipefail

launcher=$1
stderr="$PWD/stderr"

export HOME="$PWD/home"
# The fakes record which one ran, and with what, here (HOME may be unset).
export RAN="$PWD/ran"
mkdir -p "$HOME"
unset TRAJECTORY_HOME

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# fake <dir> <name>: a trajectory that records its name and arguments.
fake() {
  mkdir -p "$1"
  cat >"$1/trajectory" <<EOF
#!$BASH
printf '%s\n' "$2" "\$@" >"\$RAN"
exit "\${FAKE_EXIT:-0}"
EOF
  chmod +x "$1/trajectory"
}

# run <args...>: runs the launcher, keeping its status and stderr.
run() {
  rm -f "$RAN"
  set +e
  "$launcher" "$@" 2>"$stderr"
  status=$?
  set -e
}

# expect <name> <args...>: the launcher ran that fake with exactly <args>, silently.
expect() {
  local want=$1
  shift
  run "$@"
  [ "$status" -eq 0 ] || fail "trajectory $*: exited $status: $(cat "$stderr")"
  [ "$(cat "$RAN")" = "$(printf '%s\n' "$want" "$@")" ] || fail "trajectory $*: ran $(head -1 "$RAN"), want $want"
  [ ! -s "$stderr" ] || fail "trajectory $*: wrote to stderr: $(cat "$stderr")"
}

# expect_warning <text> <args...>: the Nix binary ran, after one warning line containing <text>.
expect_warning() {
  local text=$1
  shift
  run "$@"
  [ "$status" -eq 0 ] || fail "trajectory $*: exited $status: $(cat "$stderr")"
  [ "$(cat "$RAN")" = "$(printf '%s\n' nix "$@")" ] || fail "trajectory $*: ran $(head -1 "$RAN"), want nix"
  [ "$(wc -l <"$stderr")" -eq 1 ] || fail "trajectory $*: stderr is not one line: $(cat "$stderr")"
  grep -q -- "$text" "$stderr" || fail "trajectory $*: stderr lacks '$text': $(cat "$stderr")"
}

# No install under ~/.trajectory: the Nix binary runs, silently.
expect nix version
expect nix setup --clients cc --non-interactive
TRAJECTORY_HOME='' expect nix version

# An install under ~/.trajectory owns the state: its binary runs.
fake "$HOME/.trajectory/bin" installed
expect installed version
expect installed managed reconcile --scope user --yes
TRAJECTORY_HOME='' expect installed version

# TRAJECTORY_HOME moves the install.
fake "$HOME/elsewhere/bin" elsewhere
TRAJECTORY_HOME="$HOME/elsewhere" expect elsewhere doctor
expect installed doctor

# A relative TRAJECTORY_HOME is not looked at, even if it exists.
[ -x home/.trajectory/bin/trajectory ] || fail "test setup: no relative install"
TRAJECTORY_HOME=home/.trajectory expect_warning "not an absolute path" doctor

# Without HOME there is no default install directory.
(
  unset HOME
  expect nix version
  TRAJECTORY_HOME='' expect nix version
  TRAJECTORY_HOME="$PWD/home/.trajectory" expect installed version
)

# An install binary that is a link to the launcher itself is not run again;
# one linked elsewhere is.
rm "$HOME/.trajectory/bin/trajectory"
ln -s "$launcher" "$HOME/.trajectory/bin/trajectory"
expect_warning "no runnable bin/trajectory" status
mkdir -p "$HOME/linkdir"
ln -s "$launcher" "$HOME/linkdir/trajectory"
ln -sf "$HOME/linkdir/trajectory" "$HOME/.trajectory/bin/trajectory"
expect_warning "no runnable bin/trajectory" status
ln -sf "$HOME/elsewhere/bin/trajectory" "$HOME/.trajectory/bin/trajectory"
expect elsewhere status
rm "$HOME/.trajectory/bin/trajectory"
fake "$HOME/.trajectory/bin" installed

# A leftover that cannot run does not win, and says so.
chmod -x "$HOME/.trajectory/bin/trajectory"
expect_warning "no runnable bin/trajectory" version
chmod +x "$HOME/.trajectory/bin/trajectory"
mkdir -p "$HOME/empty"
TRAJECTORY_HOME="$HOME/empty" expect_warning "no runnable bin/trajectory" version

# The exit status is the binary's.
FAKE_EXIT=3 run status
[ "$status" -eq 3 ] || fail "exit status $status, want 3"
[ "$(head -1 "$RAN")" = installed ] || fail "status ran $(head -1 "$RAN")"

echo "trajectory launcher tests passed"
