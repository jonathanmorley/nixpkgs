#!/usr/bin/env bash
# Tests the selector in pkgs/trajectory/launcher.sh and trajectory-select
# against a fake Nix binary and a fake install. Usage:
#   trajectory-selector.sh LAUNCHER SELECT NIX_HOME NIX_PORT INSTALLED_PORT
# The launcher must be built with the selector file at
# $HOME/.config/trajectory/active and the installed home at
# $HOME/.trajectory (relative to HOME, as the check builds it). The fake Nix
# binary records `nix`, its arguments, and the variables below to "$RAN".
set -euo pipefail

launcher=$1
select=$2
nix_home=$3
nix_port=$4
installed_port=$5
stderr="$PWD/stderr"
stdout="$PWD/stdout"

export HOME="$PWD/home"
export RAN="$PWD/ran"
mkdir -p "$HOME"
unset TRAJECTORY_HOME TRAJECTORY_PORT TRAJECTORY_ACTIVE
unset TRAJECTORY_DISABLE_RUNTIME_ASSET_RECONCILE TRAJECTORY_DISABLE_STARTUP_RECONCILE TRAJECTORY_DISABLE_CLIENT_WATCHERS
selector="$HOME/.config/trajectory/active"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# The fake installed binary records its name, arguments and environment.
mkdir -p "$HOME/.trajectory/bin"
cat >"$HOME/.trajectory/bin/trajectory" <<EOF
#!$BASH
{
  printf '%s\n' installed "\$@"
  printf 'home=%s\n' "\${TRAJECTORY_HOME-unset}"
  printf 'port=%s\n' "\${TRAJECTORY_PORT-unset}"
  printf 'asset=%s\n' "\${TRAJECTORY_DISABLE_RUNTIME_ASSET_RECONCILE-unset}"
  printf 'startup=%s\n' "\${TRAJECTORY_DISABLE_STARTUP_RECONCILE-unset}"
  printf 'watchers=%s\n' "\${TRAJECTORY_DISABLE_CLIENT_WATCHERS-unset}"
  printf 'capture=%s\n' "\${TRAJECTORY_CAPTURE_URL-unset}"
  printf 'binary=%s\n' "\${TRAJECTORY_BINARY-unset}"
  printf 'other=%s\n' "\${TRAJECTORY_OTHER-unset}"
  printf 'disabled=%s\n' "\${TRAJECTORY_DISABLED-unset}"
  printf 'keychain=%s\n' "\${TRAJECTORY_DISABLE_KEYCHAIN-unset}"
} >"\$RAN"
EOF
chmod +x "$HOME/.trajectory/bin/trajectory"

run() {
  rm -f "$RAN"
  set +e
  "$launcher" "$@" >"$stdout" 2>"$stderr"
  status=$?
  set -e
}

# ran <name> <args...>: that binary ran with exactly <args>.
ran() {
  local want=$1
  shift
  [ "$status" -eq 0 ] || fail "trajectory $*: exited $status: $(cat "$stderr")"
  [ "$(head -n $(($# + 1)) "$RAN")" = "$(printf '%s\n' "$want" "$@")" ] ||
    fail "trajectory $*: ran $(head -1 "$RAN") $(sed -n '2p' "$RAN"), want $want"
}

# env_is <key> <value>: the binary that ran saw <key>=<value>.
env_is() {
  grep -qxF "$1=$2" "$RAN" || fail "$1: want '$2', got '$(grep "^$1=" "$RAN" || true)'"
}

quiet() {
  [ ! -s "$stderr" ] || fail "unexpected stderr: $(cat "$stderr")"
}

# nix_ran <args...>: the Nix binary ran in the Nix home and port, with client
# reconcile turned off, so it never rewrites another install's client setup,
# capture pointed at its own port, and no other caller TRAJECTORY_* variable.
nix_ran() {
  ran nix "$@"
  env_is home "$nix_home"
  env_is port "$nix_port"
  env_is asset 1
  env_is startup 1
  env_is watchers 1
  env_is capture "http://127.0.0.1:$nix_port"
  env_is binary unset
  env_is other unset
}

# refused <args...>: nothing ran, and the launcher said why, with status 2.
refused() {
  [ "$status" -eq 2 ] || fail "trajectory $*: exited $status, want 2"
  [ ! -e "$RAN" ] || fail "trajectory $*: ran $(head -1 "$RAN")"
  [ -s "$stderr" ] || fail "trajectory $*: refused without saying why"
}

# installed_ran <args...>: the installed binary ran with the caller's
# environment untouched.
installed_ran() {
  ran installed "$@"
  env_is asset unset
  env_is startup unset
  env_is watchers unset
}

# --- The launcher -----------------------------------------------------------

# No selector file: the installed install runs, as without the selector.
run version
installed_ran version
env_is home unset
quiet

mkdir -p "$(dirname "$selector")"

echo nix >"$selector"
run serve --port 1
nix_ran serve --port 1
quiet

# The selection wins over a caller's TRAJECTORY_HOME and TRAJECTORY_PORT:
# both belong to the selected install.
TRAJECTORY_HOME="$HOME/.trajectory" TRAJECTORY_PORT=9 run mcp
nix_ran mcp
quiet

# A caller's capture URL, binary and any other TRAJECTORY_* variable point
# at the other install, so they don't reach the Nix one. Its off switches
# (TRAJECTORY_DISABLED, TRAJECTORY_DISABLE_*) do.
TRAJECTORY_CAPTURE_URL=http://127.0.0.1:9 TRAJECTORY_BINARY="$HOME/.trajectory/bin/trajectory" TRAJECTORY_OTHER=x \
  TRAJECTORY_DISABLED=1 TRAJECTORY_DISABLE_KEYCHAIN=1 run mcp
nix_ran mcp
env_is disabled 1
env_is keychain 1
quiet

# setup and uninstrument (or uninstall) rewrite the client integrations the
# installs share, so nix mode refuses them, after flags too, unless
# TRAJECTORY_SELECTOR_ALLOW_SETUP=1.
for command in setup uninstrument uninstall; do
  run "$command" --clients cc
  refused "$command"
  grep -q TRAJECTORY_SELECTOR_ALLOW_SETUP "$stderr" || fail "$command: refusal does not name the override: $(cat "$stderr")"
  run --json "$command"
  refused --json "$command"
done
TRAJECTORY_SELECTOR_ALLOW_SETUP=1 run setup --clients cc
nix_ran setup --clients cc
# A later argument that happens to be "setup" is not the command.
run doctor setup
nix_ran doctor setup

# Trailing whitespace and a newline-less file still count.
printf 'nix  \n' >"$selector"
run status
nix_ran status
printf 'nix' >"$selector"
run status
nix_ran status

echo installed >"$selector"
run doctor
installed_ran doctor
env_is home unset
quiet

# In installed mode the caller's environment passes through unchanged, and
# setup is the installed install's business.
TRAJECTORY_HOME="$HOME/.trajectory" TRAJECTORY_PORT=9 TRAJECTORY_CAPTURE_URL=http://127.0.0.1:9 TRAJECTORY_BINARY=/b run doctor
installed_ran doctor
env_is home "$HOME/.trajectory"
env_is port 9
env_is capture http://127.0.0.1:9
env_is binary /b
run setup --clients cc
installed_ran setup --clients cc

# Anything else selects the installed install, with one warning line.
echo bogus >"$selector"
run version
installed_ran version
[ "$(wc -l <"$stderr")" -eq 1 ] || fail "bogus selector: stderr is not one line: $(cat "$stderr")"
grep -q "bogus" "$stderr" || fail "bogus selector: warning does not name the value: $(cat "$stderr")"
: >"$selector"
run version
installed_ran version
quiet

# TRAJECTORY_ACTIVE overrides the file both ways.
echo installed >"$selector"
TRAJECTORY_ACTIVE=nix run version
nix_ran version
echo nix >"$selector"
TRAJECTORY_ACTIVE=installed run version
installed_ran version
TRAJECTORY_ACTIVE=Nix run version
installed_ran version
grep -q "TRAJECTORY_ACTIVE" "$stderr" || fail "bad TRAJECTORY_ACTIVE: no warning: $(cat "$stderr")"
TRAJECTORY_ACTIVE='' run version
nix_ran version

# Without HOME there is no selector file: installed (the Nix fallback here,
# since there is no install directory either).
(
  unset HOME
  run version
  ran nix version
  env_is home unset
  env_is asset unset
)

# The exit status is the binary's.
echo nix >"$selector"
FAKE_EXIT=4 run status
[ "$status" -eq 4 ] || fail "exit status $status, want 4"

# nix mode refuses to run when the Nix home resolves to the installed home
# or inside it, through symlinks too: the two installs would share state.
linked_home="$PWD/linked-home"
for target in "$nix_home" "${nix_home%/*}"; do
  rm -rf "$linked_home"
  mkdir -p "$linked_home/.config/trajectory"
  echo nix >"$linked_home/.config/trajectory/active"
  ln -s "$target" "$linked_home/.trajectory"
  HOME="$linked_home" run version
  refused version
  grep -qF "$nix_home" "$stderr" || fail "shared home: refusal does not name the Nix home: $(cat "$stderr")"
done

# --- trajectory-select ------------------------------------------------------

sel() {
  set +e
  "$select" "$@" >"$stdout" 2>"$stderr"
  status=$?
  set -e
}

rm -f "$selector"
rm -rf "$(dirname "$selector")"
sel nix
[ "$status" -eq 0 ] || fail "select nix: exited $status: $(cat "$stderr")"
[ "$(cat "$selector")" = nix ] || fail "select nix wrote '$(cat "$selector")'"
grep -q "active: nix" "$stdout" || fail "select nix: no status: $(cat "$stdout")"
grep -qF "home: $nix_home" "$stdout" || fail "select nix: no home: $(cat "$stdout")"
grep -qF "port: $nix_port" "$stdout" || fail "select nix: no port: $(cat "$stdout")"
grep -qi "restart" "$stdout" || fail "select nix: says nothing about restarts: $(cat "$stdout")"
[ -z "$(find "$(dirname "$selector")" -name '.active.*')" ] || fail "select left a temporary file"

sel installed
[ "$status" -eq 0 ] || fail "select installed: exited $status"
[ "$(cat "$selector")" = installed ] || fail "select installed wrote '$(cat "$selector")'"
grep -q "active: installed" "$stdout" || fail "select installed: no status: $(cat "$stdout")"
grep -qF "home: $HOME/.trajectory" "$stdout" || fail "select installed: no home: $(cat "$stdout")"
grep -qF "port: $installed_port" "$stdout" || fail "select installed: no port: $(cat "$stdout")"
grep -qF "binary: $HOME/.trajectory/bin/trajectory" "$stdout" || fail "select installed: no binary: $(cat "$stdout")"

# No argument prints the status and changes nothing.
sel
[ "$status" -eq 0 ] || fail "select: exited $status"
[ "$(cat "$selector")" = installed ] || fail "select with no argument changed the file"
grep -q "active: installed (" "$stdout" || fail "select: no source of the selection: $(cat "$stdout")"
grep -q "serve: not listening" "$stdout" || fail "select: no serve state: $(cat "$stdout")"
TRAJECTORY_ACTIVE=nix sel
grep -q "active: nix (TRAJECTORY_ACTIVE)" "$stdout" || fail "select: TRAJECTORY_ACTIVE not reported: $(cat "$stdout")"

# Bad usage changes nothing and exits 2.
for args in "bogus" "nix installed" "--force"; do
  # shellcheck disable=SC2086
  sel $args
  [ "$status" -eq 2 ] || fail "select $args: exited $status, want 2"
  [ "$(cat "$selector")" = installed ] || fail "select $args changed the file"
  grep -qi "usage" "$stderr" || fail "select $args: no usage: $(cat "$stderr")"
done
sel --help
[ "$status" -eq 0 ] || fail "select --help: exited $status"
grep -qi "usage" "$stdout" || fail "select --help: no usage"

# A directory at the selector path is not written into.
mv "$selector" "$selector.saved"
mkdir "$selector"
sel nix
[ "$status" -ne 0 ] || fail "select nix onto a directory succeeded"
[ -d "$selector" ] || fail "select nix replaced the directory"
[ -z "$(ls -A "$selector")" ] || fail "select nix wrote into the directory: $(ls -A "$selector")"
[ -z "$(find "$(dirname "$selector")" -name '.active.*')" ] || fail "failed select left a temporary file"
rmdir "$selector"
mv "$selector.saved" "$selector"

# A selector path that cannot be written fails loudly and leaves the old value.
chmod a-w "$(dirname "$selector")"
sel nix
chmod u+w "$(dirname "$selector")"
[ "$status" -ne 0 ] || fail "select nix into a read-only directory succeeded"
[ "$(cat "$selector")" = installed ] || fail "failed select changed the file"

echo "trajectory selector tests passed"
