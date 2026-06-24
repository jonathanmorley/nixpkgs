#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
script="$repo_root/modules/ai/lapdog-desktop-hooks.sh"

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
mkdir -p "$tmp_dir/bin"

lapdog_bin="$tmp_dir/lapdog"
printf '#!/usr/bin/env bash\nprintf "lapdog %%s\\n" "$*"\n' >"$lapdog_bin"
chmod +x "$lapdog_bin"

ca_bundle="$tmp_dir/ca-bundle.crt"
printf 'test ca\n' >"$ca_bundle"

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

LAPDOG_BIN="$lapdog_bin" \
  LOCAL_BIN_DIR="$tmp_dir/bin" \
  CODEX_LAPDOG_APP="$tmp_dir/Codex Lapdog.app" \
  LAPDOG_SSL_CERT_FILE="$ca_bundle" \
  "$script" install

claude_wrapper="$tmp_dir/bin/claude-lapdog-desktop"
codex_wrapper="$tmp_dir/bin/codex-lapdog-app"

[[ -x $claude_wrapper ]] || fail "Claude wrapper was not executable"
[[ -x $codex_wrapper ]] || fail "Codex wrapper was not executable"

assert_file_contains "$claude_wrapper" "exec \"$lapdog_bin\" claude \"\$@\""
assert_file_contains "$codex_wrapper" "exec \"$lapdog_bin\" codex \"\$@\""
assert_file_not_contains "$codex_wrapper" "codex app"
assert_file_contains "$claude_wrapper" "$ca_bundle"
assert_file_contains "$claude_wrapper" "REQUESTS_CA_BUNDLE"
assert_file_contains "$claude_wrapper" "NODE_EXTRA_CA_CERTS"
assert_file_contains "$codex_wrapper" "$ca_bundle"
assert_file_contains "$codex_wrapper" "REQUESTS_CA_BUNDLE"

[[ ! -e "$tmp_dir/Codex Lapdog.app" ]] || fail "legacy Codex Lapdog app was not removed"
assert_file_not_contains "$script" "ENABLE_CLAUDE_DESKTOP_ASAR_PATCH"
assert_file_not_contains "$script" "patch_claude_asar"
assert_file_not_contains "$script" "patch_claude_plist"
assert_file_not_contains "$script" "LSEnvironment:CLAUDE_CODE_LOCAL_BINARY"
assert_file_contains "$script" "local.lapdog.codex"

assert_home_config_contains "_lapdog_cert_file"
# shellcheck disable=SC2016
assert_home_config_contains 'SSL_CERT_FILE="$_lapdog_cert_file"'
# shellcheck disable=SC2016
assert_home_config_contains 'command lapdog "$@"'
assert_darwin_config_contains "launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY"
assert_darwin_config_contains "/usr/local/bin/claude-lapdog-desktop"
assert_darwin_config_contains "launchd.user.envVariables.CODEX_CLI_PATH"
assert_darwin_config_contains "/usr/local/bin/codex-lapdog-app"

printf 'PASS: lapdog desktop hooks\n'
