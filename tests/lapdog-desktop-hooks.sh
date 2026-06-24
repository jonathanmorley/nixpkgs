#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
script="$repo_root/modules/ai/lapdog-cleanup.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq -- "$expected" "$file"; then
    printf 'File did not contain expected text: %s\n' "$expected" >&2
    printf '%s\n' "--- $file ---" >&2
    sed -n '1,160p' "$file" >&2
    fail "missing expected text"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    printf 'File contained unexpected text: %s\n' "$unexpected" >&2
    printf '%s\n' "--- $file ---" >&2
    sed -n '1,160p' "$file" >&2
    fail "found unexpected text"
  fi
}

assert_home_config_contains() {
  local expected="$1"

  assert_file_contains "$repo_root/modules/ai/home.nix" "$expected"
}

assert_darwin_config_contains() {
  local expected="$1"

  assert_file_contains "$repo_root/modules/ai/darwin.nix" "$expected"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/Codex Lapdog.app/Contents"

cat >"$tmp_dir/Codex Lapdog.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>local.lapdog.codex</string>
</dict>
</plist>
PLIST

CODEX_LAPDOG_APP="$tmp_dir/Codex Lapdog.app" "$script" install
[[ ! -e "$tmp_dir/Codex Lapdog.app" ]] || fail "legacy Codex Lapdog app was not removed"

assert_file_contains "$script" "local.lapdog.codex"
assert_file_not_contains "$script" "claude-lapdog-desktop"
assert_file_not_contains "$script" "codex-lapdog-app"
assert_file_not_contains "$script" "exec "

assert_darwin_config_contains 'mkLapdogWrapper "claude-lapdog" "claude"'
assert_darwin_config_contains 'mkLapdogWrapper "codex-lapdog" "codex"'
# shellcheck disable=SC2016
assert_darwin_config_contains 'exec "${config.homebrew.prefix}/bin/lapdog"'
assert_darwin_config_contains "launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "launchd.user.envVariables.CODEX_CLI_PATH"
assert_darwin_config_contains "launchctl unsetenv CODEX_CLI_PATH"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "/usr/local/bin/claude-lapdog-desktop"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "/usr/local/bin/codex-lapdog-app"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "enableLapdogHooks"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" 'config.system.primaryUser != "runner"'
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "SSL_CERT_FILE"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "NIX_SSL_CERT_FILE"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "REQUESTS_CA_BUNDLE"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "NODE_EXTRA_CA_CERTS"
assert_file_not_contains "$repo_root/modules/ai/darwin.nix" "NODE_USE_SYSTEM_CA"

assert_home_config_contains 'command claude-lapdog "$@"'
assert_home_config_contains 'command codex-lapdog "$@"'
assert_file_not_contains "$repo_root/modules/ai/home.nix" "command lapdog"

printf 'PASS: lapdog desktop hooks\n'
