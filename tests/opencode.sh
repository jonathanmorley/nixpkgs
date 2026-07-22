#!/usr/bin/env bash
set -euo pipefail

snapshot="$(mktemp)"
trap 'rm -f "$snapshot"' EXIT
failures=0

nix eval --impure --json --file ./opencode-check.nix >"$snapshot"

assert() {
  local description="$1"
  local query="$2"

  if jq -e "$query" "$snapshot" >/dev/null; then
    printf 'PASS: %s\n' "$description"
  else
    printf 'FAIL: %s\n' "$description"
    return 1
  fi
}

check() {
  if ! assert "$@"; then
    failures=$((failures + 1))
  fi
}

cli_name='opencode-1.18.4+49c69c5'
desktop_name='opencode-desktop-1.18.4+49c69c5'

check "medusa uses aarch64-darwin" '.medusa.system == "aarch64-darwin"'
check "medusa exposes the OpenCode CLI overlay" ".medusa.overlay.cli == \"$cli_name\""
check "medusa exposes the OpenCode desktop overlay" ".medusa.overlay.desktop == \"$desktop_name\""
check "medusa installs the OpenCode desktop package" ".medusa.systemPackages | index(\"$desktop_name\") != null"
check "medusa does not cask OpenCode desktop" '.medusa.casks | index("opencode-desktop") == null'

check "gha-aarch64-darwin uses aarch64-darwin" '."gha-aarch64-darwin".system == "aarch64-darwin"'
check "gha-aarch64-darwin exposes the OpenCode CLI overlay" ".\"gha-aarch64-darwin\".overlay.cli == \"$cli_name\""
check "gha-aarch64-darwin exposes the OpenCode desktop overlay" ".\"gha-aarch64-darwin\".overlay.desktop == \"$desktop_name\""
check "gha-aarch64-darwin installs the OpenCode desktop package" ".\"gha-aarch64-darwin\".systemPackages | index(\"$desktop_name\") != null"
check "gha-aarch64-darwin does not cask OpenCode desktop" '."gha-aarch64-darwin".casks | index("opencode-desktop") == null'

check "smoke uses x86_64-darwin" '.smoke.system == "x86_64-darwin"'
check "smoke exposes the OpenCode CLI overlay" ".smoke.overlay.cli == \"$cli_name\""
check "smoke exposes the OpenCode desktop overlay" ".smoke.overlay.desktop == \"$desktop_name\""
check "smoke casks OpenCode desktop" '.smoke.casks | index("opencode-desktop") != null'
check "smoke does not install the OpenCode desktop package" ".smoke.systemPackages | index(\"$desktop_name\") == null"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
