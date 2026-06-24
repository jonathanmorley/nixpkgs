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

mkdir -p "$tmp_dir/Codex.app/Contents/Resources"
mkdir -p "$tmp_dir/bin"

lapdog_bin="$tmp_dir/lapdog"
printf '#!/usr/bin/env bash\nprintf "lapdog %%s\\n" "$*"\n' >"$lapdog_bin"
chmod +x "$lapdog_bin"

ca_bundle="$tmp_dir/ca-bundle.crt"
printf 'test ca\n' >"$ca_bundle"

codesign_bin="$tmp_dir/codesign"
codesign_log="$tmp_dir/codesign.log"
cat >"$codesign_bin" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODESIGN_LOG"
SH
chmod +x "$codesign_bin"

LAPDOG_BIN="$lapdog_bin" \
  LOCAL_BIN_DIR="$tmp_dir/bin" \
  CODEX_APP="$tmp_dir/Codex.app" \
  CODEX_LAPDOG_APP="$tmp_dir/Codex Lapdog.app" \
  LAPDOG_SSL_CERT_FILE="$ca_bundle" \
  CODESIGN="$codesign_bin" \
  CODESIGN_LOG="$codesign_log" \
  "$script" install

claude_wrapper="$tmp_dir/bin/claude-lapdog-desktop"
codex_wrapper="$tmp_dir/bin/codex-lapdog-app"

[[ -x $claude_wrapper ]] || fail "Claude wrapper was not executable"
[[ -x $codex_wrapper ]] || fail "Codex wrapper was not executable"

assert_file_contains "$claude_wrapper" "exec \"$lapdog_bin\" claude \"\$@\""
assert_file_contains "$codex_wrapper" "exec \"$lapdog_bin\" codex app \"\$@\""
assert_file_contains "$claude_wrapper" "$ca_bundle"
assert_file_contains "$claude_wrapper" "REQUESTS_CA_BUNDLE"
assert_file_contains "$claude_wrapper" "NODE_EXTRA_CA_CERTS"
assert_file_contains "$codex_wrapper" "$ca_bundle"
assert_file_contains "$codex_wrapper" "REQUESTS_CA_BUNDLE"

codex_app_exe="$tmp_dir/Codex Lapdog.app/Contents/MacOS/Codex Lapdog"
[[ -x $codex_app_exe ]] || fail "Codex Lapdog app executable was not created"
assert_file_contains "$codex_app_exe" "exec \"$codex_wrapper\" \"\$@\""
[[ -f $codesign_log ]] || fail "codesign was not called"
assert_file_contains "$codesign_log" "--force --deep --sign -"
assert_file_contains "$codesign_log" "$tmp_dir/Codex Lapdog.app"
assert_file_not_contains "$script" "ENABLE_CLAUDE_DESKTOP_ASAR_PATCH"
assert_file_not_contains "$script" "patch_claude_asar"
assert_file_not_contains "$script" "patch_claude_plist"
assert_file_not_contains "$script" "LSEnvironment:CLAUDE_CODE_LOCAL_BINARY"

assert_home_config_contains "_lapdog_cert_file"
# shellcheck disable=SC2016
assert_home_config_contains 'SSL_CERT_FILE="$_lapdog_cert_file"'
# shellcheck disable=SC2016
assert_home_config_contains 'command lapdog "$@"'
assert_darwin_config_contains "launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY"
assert_darwin_config_contains "/usr/local/bin/claude-lapdog-desktop"

printf 'PASS: lapdog desktop hooks\n'
