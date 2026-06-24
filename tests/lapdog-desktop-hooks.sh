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

assert_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual

  actual="$(/usr/libexec/PlistBuddy -c "Print $key" "$plist")"
  if [[ $actual != "$expected" ]]; then
    fail "expected $key to be '$expected', got '$actual'"
  fi
}

assert_plist_key_absent() {
  local plist="$1"
  local key="$2"

  if /usr/libexec/PlistBuddy -c "Print $key" "$plist" >/dev/null 2>&1; then
    fail "expected $key to be absent"
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

create_asar_fixture() {
  local asar_path="$1"

  ASAR_PATH="$asar_path" python3 - <<'PY'
import hashlib
import json
import os
import struct

asar_path = os.environ["ASAR_PATH"]
index_js = (
    b'"use strict";'
    b'class kUr{constructor(){this.localBinaryPath=null;'
    b'this.localBinaryInitPromise=null;'
    b'D.info(`[CCD] Initialized with version ${this.requiredVersion}`),'
    b'process.env.CLAUDE_CODE_LOCAL_BINARY}'
    b'async initLocalBinary(e){return e}}'
)
other_js = b'console.log("other");'
files = [
    ([".vite", "build", "index.js"], index_js),
    ([".vite", "build", "other.js"], other_js),
]

header = {"files": {}}
offset = 0
data = bytearray()
for parts, content in files:
    node = header["files"]
    for part in parts[:-1]:
        node = node.setdefault(part, {"files": {}})["files"]
    node[parts[-1]] = {
        "size": len(content),
        "offset": str(offset),
        "integrity": {
            "algorithm": "SHA256",
            "hash": hashlib.sha256(content).hexdigest(),
            "blockSize": 4194304,
            "blocks": [hashlib.sha256(content).hexdigest()],
        },
    }
    data.extend(content)
    offset += len(content)

payload = json.dumps(header, separators=(",", ":")).encode()
padding = (4 - (len(payload) % 4)) % 4
prefix = struct.pack("<IIII", 4, len(payload) + padding + 8, len(payload) + padding + 4, len(payload))
with open(asar_path, "wb") as f:
    f.write(prefix)
    f.write(payload)
    f.write(b"\0" * padding)
    f.write(data)
PY
}

read_asar_index() {
  local asar_path="$1"

  ASAR_PATH="$asar_path" python3 - <<'PY'
import json
import os
import struct

asar_path = os.environ["ASAR_PATH"]
with open(asar_path, "rb") as f:
    data = f.read()
json_size = struct.unpack_from("<I", data, 12)[0]
padding = (4 - (json_size % 4)) % 4
header = json.loads(data[16:16 + json_size])
entry = header["files"][".vite"]["files"]["build"]["files"]["index.js"]
start = 16 + json_size + padding + int(entry["offset"])
content = data[start:start + entry["size"]]
print(content.decode())
PY
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/Claude.app/Contents/Resources"
mkdir -p "$tmp_dir/Codex.app/Contents/Resources"
mkdir -p "$tmp_dir/bin"

lapdog_bin="$tmp_dir/lapdog"
printf '#!/usr/bin/env bash\nprintf "lapdog %%s\\n" "$*"\n' >"$lapdog_bin"
chmod +x "$lapdog_bin"

ca_bundle="$tmp_dir/ca-bundle.crt"
printf 'test ca\n' >"$ca_bundle"

codesign_log="$tmp_dir/codesign.log"
codesign_bin="$tmp_dir/codesign"
cat >"$codesign_bin" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODESIGN_LOG"
SH
chmod +x "$codesign_bin"

lsregister_log="$tmp_dir/lsregister.log"
lsregister_bin="$tmp_dir/lsregister"
cat >"$lsregister_bin" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LSREGISTER_LOG"
SH
chmod +x "$lsregister_bin"

claude_plist="$tmp_dir/Claude.app/Contents/Info.plist"
cat >"$claude_plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.anthropic.claudefordesktop</string>
  <key>ElectronAsarIntegrity</key>
  <dict>
    <key>Resources/app.asar</key>
    <dict>
      <key>algorithm</key>
      <string>SHA256</string>
      <key>hash</key>
      <string>old-hash</string>
    </dict>
  </dict>
  <key>LSEnvironment</key>
  <dict>
    <key>MallocNanoZone</key>
    <string>0</string>
  </dict>
</dict>
</plist>
PLIST

create_asar_fixture "$tmp_dir/Claude.app/Contents/Resources/app.asar"

LAPDOG_BIN="$lapdog_bin" \
  LOCAL_BIN_DIR="$tmp_dir/bin" \
  CLAUDE_APP="$tmp_dir/Claude.app" \
  CODEX_APP="$tmp_dir/Codex.app" \
  CODEX_LAPDOG_APP="$tmp_dir/Codex Lapdog.app" \
  LAPDOG_SSL_CERT_FILE="$ca_bundle" \
  CODESIGN="$codesign_bin" \
  CODESIGN_LOG="$codesign_log" \
  LSREGISTER="$lsregister_bin" \
  LSREGISTER_LOG="$lsregister_log" \
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
assert_plist_key_absent "$claude_plist" ":LSEnvironment:CLAUDE_CODE_LOCAL_BINARY"

unpatched_index="$(read_asar_index "$tmp_dir/Claude.app/Contents/Resources/app.asar")"
[[ $unpatched_index == *"process.env.CLAUDE_CODE_LOCAL_BINARY}"* ]] ||
  fail "Claude ASAR was unexpectedly patched by default"
[[ $unpatched_index != *"this.localBinaryInitPromise=process.env.CLAUDE_CODE_LOCAL_BINARY?this.initLocalBinary(process.env.CLAUDE_CODE_LOCAL_BINARY):null"* ]] ||
  fail "Claude ASAR initialized the local binary override by default"

assert_plist_value "$claude_plist" ":ElectronAsarIntegrity:Resources/app.asar:hash" "old-hash"

codex_app_exe="$tmp_dir/Codex Lapdog.app/Contents/MacOS/Codex Lapdog"
[[ -x $codex_app_exe ]] || fail "Codex Lapdog app executable was not created"
assert_file_contains "$codex_app_exe" "exec \"$codex_wrapper\" \"\$@\""
[[ -f $codesign_log ]] || fail "codesign was not called"
assert_file_contains "$codesign_log" "--force --deep --sign -"
assert_file_not_contains "$codesign_log" "$tmp_dir/Claude.app"
assert_file_contains "$codesign_log" "$tmp_dir/Codex Lapdog.app"
[[ -f $lsregister_log ]] || fail "lsregister was not called"
assert_file_not_contains "$lsregister_log" "$tmp_dir/Claude.app"
assert_file_contains "$lsregister_log" "$tmp_dir/Codex Lapdog.app"

assert_home_config_contains "_lapdog_cert_file"
# shellcheck disable=SC2016
assert_home_config_contains 'SSL_CERT_FILE="$_lapdog_cert_file"'
# shellcheck disable=SC2016
assert_home_config_contains 'command lapdog "$@"'
assert_darwin_config_contains "launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY"
assert_darwin_config_contains "/usr/local/bin/claude-lapdog-desktop"

LAPDOG_BIN="$lapdog_bin" \
  LOCAL_BIN_DIR="$tmp_dir/bin" \
  CLAUDE_APP="$tmp_dir/Claude.app" \
  CODEX_APP="$tmp_dir/Codex.app" \
  CODEX_LAPDOG_APP="$tmp_dir/Codex Lapdog.app" \
  LAPDOG_SSL_CERT_FILE="$ca_bundle" \
  CODESIGN="$codesign_bin" \
  CODESIGN_LOG="$codesign_log" \
  LSREGISTER="$lsregister_bin" \
  LSREGISTER_LOG="$lsregister_log" \
  ENABLE_CLAUDE_DESKTOP_ASAR_PATCH=1 \
  "$script" install

assert_plist_value "$claude_plist" ":LSEnvironment:CLAUDE_CODE_LOCAL_BINARY" "$claude_wrapper"

patched_index="$(read_asar_index "$tmp_dir/Claude.app/Contents/Resources/app.asar")"
[[ $patched_index == *"this.localBinaryInitPromise=process.env.CLAUDE_CODE_LOCAL_BINARY?this.initLocalBinary(process.env.CLAUDE_CODE_LOCAL_BINARY):null"* ]] ||
  fail "Claude ASAR did not initialize the local binary override when opt-in was enabled"

expected_hash="$(shasum -a 256 "$tmp_dir/Claude.app/Contents/Resources/app.asar" | awk '{print $1}')"
assert_plist_value "$claude_plist" ":ElectronAsarIntegrity:Resources/app.asar:hash" "$expected_hash"
assert_file_contains "$codesign_log" "$tmp_dir/Claude.app"
assert_file_contains "$lsregister_log" "$tmp_dir/Claude.app"

printf 'PASS: lapdog desktop hooks\n'
