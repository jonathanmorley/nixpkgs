#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[lapdog-hooks] %s\n' "$*" >&2
}

warn() {
  printf '[lapdog-hooks] warning: %s\n' "$*" >&2
}

die() {
  printf '[lapdog-hooks] error: %s\n' "$*" >&2
  exit 1
}

command_name="${1:-install}"

if [[ $command_name != "install" ]]; then
  die "unsupported command: $command_name"
fi

PRIMARY_USER="${PRIMARY_USER:-${SUDO_USER:-${USER:-jonathan}}}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-/usr/local/bin}"
CLAUDE_APP="${CLAUDE_APP:-/Applications/Claude.app}"
CODEX_APP="${CODEX_APP:-/Applications/Codex.app}"
CODEX_LAPDOG_APP="${CODEX_LAPDOG_APP:-/Applications/Codex Lapdog.app}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"
PLUTIL="${PLUTIL:-/usr/bin/plutil}"
CODESIGN="${CODESIGN:-/usr/bin/codesign}"
LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
LAPDOG_SSL_CERT_FILE="${LAPDOG_SSL_CERT_FILE:-${SSL_CERT_FILE:-${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}}}"
ENABLE_CLAUDE_DESKTOP_ASAR_PATCH="${ENABLE_CLAUDE_DESKTOP_ASAR_PATCH:-0}"

if [[ -z ${HOMEBREW_PREFIX:-} ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
  elif [[ -x /usr/local/bin/brew ]]; then
    HOMEBREW_PREFIX="/usr/local"
  else
    HOMEBREW_PREFIX="/opt/homebrew"
  fi
fi

resolve_lapdog_bin() {
  if [[ -n ${LAPDOG_BIN:-} ]]; then
    printf '%s\n' "$LAPDOG_BIN"
    return
  fi

  if [[ -x "$HOMEBREW_PREFIX/bin/lapdog" ]]; then
    printf '%s\n' "$HOMEBREW_PREFIX/bin/lapdog"
    return
  fi

  if [[ -x /opt/homebrew/bin/lapdog ]]; then
    printf '%s\n' /opt/homebrew/bin/lapdog
    return
  fi

  if [[ -x /usr/local/bin/lapdog ]]; then
    printf '%s\n' /usr/local/bin/lapdog
    return
  fi

  if command -v lapdog >/dev/null 2>&1; then
    command -v lapdog
    return
  fi

  die "lapdog is not installed"
}

LAPDOG_BIN="$(resolve_lapdog_bin)"
CLAUDE_WRAPPER="$LOCAL_BIN_DIR/claude-lapdog-desktop"
CODEX_WRAPPER="$LOCAL_BIN_DIR/codex-lapdog-app"
WRAPPER_PATH="/etc/profiles/per-user/$PRIMARY_USER/bin:$HOMEBREW_PREFIX/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

write_wrapper_header() {
  printf '#!/bin/zsh\n'
  printf "export PATH=\"%s:\${PATH:-}\"\n" "$WRAPPER_PATH"
  printf "if [[ -z \${SSL_CERT_FILE:-} && -f \"%s\" ]]; then\n" "$LAPDOG_SSL_CERT_FILE"
  printf '  export SSL_CERT_FILE="%s"\n' "$LAPDOG_SSL_CERT_FILE"
  printf 'fi\n'
  printf "if [[ -n \${SSL_CERT_FILE:-} ]]; then\n"
  printf "  export REQUESTS_CA_BUNDLE=\"\${REQUESTS_CA_BUNDLE:-\$SSL_CERT_FILE}\"\n"
  printf "  export NODE_EXTRA_CA_CERTS=\"\${NODE_EXTRA_CA_CERTS:-\$SSL_CERT_FILE}\"\n"
  printf 'fi\n'
  printf "export NODE_USE_SYSTEM_CA=\"\${NODE_USE_SYSTEM_CA:-1}\"\n"
}

write_claude_wrapper() {
  mkdir -p "$LOCAL_BIN_DIR"
  {
    write_wrapper_header
    printf 'exec "%s" claude "$@"\n' "$LAPDOG_BIN"
  } >"$CLAUDE_WRAPPER"
  chmod 0755 "$CLAUDE_WRAPPER"
}

write_codex_wrapper() {
  mkdir -p "$LOCAL_BIN_DIR"
  {
    write_wrapper_header
    printf 'exec "%s" codex app "$@"\n' "$LAPDOG_BIN"
  } >"$CODEX_WRAPPER"
  chmod 0755 "$CODEX_WRAPPER"
}

sign_app() {
  local app="$1"
  local name="$2"

  if [[ ! -d $app ]]; then
    return
  fi

  if [[ ! -x $CODESIGN ]]; then
    warn "codesign not found at $CODESIGN; $name may not launch after patching"
    return
  fi

  if ! "$CODESIGN" --force --deep --sign - "$app" >/dev/null 2>&1; then
    warn "failed to ad-hoc sign $name at $app"
  fi
}

ensure_plist_dict() {
  local plist="$1"
  local key="$2"

  if ! "$PLISTBUDDY" -c "Print $key" "$plist" >/dev/null 2>&1; then
    "$PLISTBUDDY" -c "Add $key dict" "$plist" >/dev/null
  fi
}

set_plist_string() {
  local plist="$1"
  local key="$2"
  local value="$3"

  if ! "$PLISTBUDDY" -c "Set $key $value" "$plist" >/dev/null 2>&1; then
    "$PLISTBUDDY" -c "Add $key string $value" "$plist" >/dev/null
  fi
}

update_asar_hash() {
  local plist="$1"
  local asar_path="$2"
  local hash

  hash="$(shasum -a 256 "$asar_path" | awk '{print $1}')"
  ensure_plist_dict "$plist" ":ElectronAsarIntegrity"
  ensure_plist_dict "$plist" ":ElectronAsarIntegrity:Resources/app.asar"
  set_plist_string "$plist" ":ElectronAsarIntegrity:Resources/app.asar:algorithm" "SHA256"
  set_plist_string "$plist" ":ElectronAsarIntegrity:Resources/app.asar:hash" "$hash"
}

patch_claude_plist() {
  local plist="$CLAUDE_APP/Contents/Info.plist"

  if [[ ! -f $plist ]]; then
    warn "Claude Info.plist not found at $plist; skipping Claude plist patch"
    return
  fi

  ensure_plist_dict "$plist" ":LSEnvironment"
  set_plist_string "$plist" ":LSEnvironment:CLAUDE_CODE_LOCAL_BINARY" "$CLAUDE_WRAPPER"
  "$PLUTIL" -lint "$plist" >/dev/null
}

patch_claude_asar() {
  local asar_path="$CLAUDE_APP/Contents/Resources/app.asar"

  if [[ ! -f $asar_path ]]; then
    warn "Claude app.asar not found at $asar_path; skipping Claude ASAR patch"
    return
  fi

  LAPDOG_ASAR_PATH="$asar_path" "$PYTHON_BIN" <<'PY'
import hashlib
import json
import os
import stat
import struct
import tempfile

asar_path = os.environ["LAPDOG_ASAR_PATH"]
target = (".vite", "build", "index.js")
old = b"process.env.CLAUDE_CODE_LOCAL_BINARY"
new = (
    b"this.localBinaryInitPromise=process.env.CLAUDE_CODE_LOCAL_BINARY?"
    b"this.initLocalBinary(process.env.CLAUDE_CODE_LOCAL_BINARY):null"
)
block_size = 4194304


def padding_for(size):
    return (4 - (size % 4)) % 4


def walk(files, prefix=()):
    for name, entry in files.items():
        current = prefix + (name,)
        if "files" in entry:
            yield from walk(entry["files"], current)
        elif "offset" in entry and "size" in entry:
            yield current, entry


def integrity_for(content):
    blocks = [
        hashlib.sha256(content[index : index + block_size]).hexdigest()
        for index in range(0, len(content), block_size)
    ]
    if not blocks:
        blocks = [hashlib.sha256(b"").hexdigest()]
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(content).hexdigest(),
        "blockSize": block_size,
        "blocks": blocks,
    }


with open(asar_path, "rb") as f:
    original = f.read()

if len(original) < 16:
    raise SystemExit(f"{asar_path} is too small to be an ASAR archive")

json_size = struct.unpack_from("<I", original, 12)[0]
padding = padding_for(json_size)
header_start = 16
header_end = header_start + json_size
data_start = header_end + padding
header = json.loads(original[header_start:header_end])

entries = sorted(walk(header["files"]), key=lambda item: int(item[1]["offset"]))
contents = {}
for path, entry in entries:
    offset = int(entry["offset"])
    size = int(entry["size"])
    contents[path] = original[data_start + offset : data_start + offset + size]

if target not in contents:
    raise SystemExit("Claude ASAR does not contain .vite/build/index.js")

index_js = contents[target]
if new in index_js:
    changed = False
elif old in index_js:
    contents[target] = index_js.replace(old, new, 1)
    changed = True
else:
    raise SystemExit("Claude ASAR does not contain the expected CLAUDE_CODE_LOCAL_BINARY hook point")

if not changed:
    raise SystemExit(0)

data = bytearray()
offset = 0
for path, entry in entries:
    content = contents[path]
    entry["offset"] = str(offset)
    entry["size"] = len(content)
    if "integrity" in entry:
        entry["integrity"] = integrity_for(content)
    data.extend(content)
    offset += len(content)

payload = json.dumps(header, separators=(",", ":")).encode()
payload_padding = padding_for(len(payload))
prefix = struct.pack(
    "<IIII",
    4,
    len(payload) + payload_padding + 8,
    len(payload) + payload_padding + 4,
    len(payload),
)
rebuilt = prefix + payload + (b"\0" * payload_padding) + bytes(data)

current_mode = stat.S_IMODE(os.stat(asar_path).st_mode)
directory = os.path.dirname(asar_path)
fd, tmp_path = tempfile.mkstemp(prefix=".app.asar.", dir=directory)
try:
    with os.fdopen(fd, "wb") as f:
        f.write(rebuilt)
    os.chmod(tmp_path, current_mode)
    os.replace(tmp_path, asar_path)
finally:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
PY

  update_asar_hash "$CLAUDE_APP/Contents/Info.plist" "$asar_path"
}

create_codex_lapdog_app() {
  local executable_name="Codex Lapdog"
  local info_plist="$CODEX_LAPDOG_APP/Contents/Info.plist"
  local executable="$CODEX_LAPDOG_APP/Contents/MacOS/$executable_name"
  local icon_source="$CODEX_APP/Contents/Resources/electron.icns"
  local icon_target="$CODEX_LAPDOG_APP/Contents/Resources/electron.icns"

  mkdir -p "$CODEX_LAPDOG_APP/Contents/MacOS" "$CODEX_LAPDOG_APP/Contents/Resources"

  cat >"$info_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Codex Lapdog</string>
  <key>CFBundleExecutable</key>
  <string>$executable_name</string>
  <key>CFBundleIconFile</key>
  <string>electron.icns</string>
  <key>CFBundleIdentifier</key>
  <string>local.lapdog.codex</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Lapdog</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
</dict>
</plist>
PLIST

  {
    printf '#!/bin/zsh\n'
    printf 'exec "%s" "$@"\n' "$CODEX_WRAPPER"
  } >"$executable"
  chmod 0755 "$executable"

  if [[ -f $icon_source ]]; then
    cp -f "$icon_source" "$icon_target"
  fi

  "$PLUTIL" -lint "$info_plist" >/dev/null
}

register_apps() {
  if [[ -x $LSREGISTER ]]; then
    [[ $ENABLE_CLAUDE_DESKTOP_ASAR_PATCH == "1" && -d $CLAUDE_APP ]] &&
      "$LSREGISTER" -f "$CLAUDE_APP" >/dev/null 2>&1 || true
    [[ -d $CODEX_LAPDOG_APP ]] && "$LSREGISTER" -f "$CODEX_LAPDOG_APP" >/dev/null 2>&1 || true
  fi
}

install_claude_desktop_hook() {
  if [[ $ENABLE_CLAUDE_DESKTOP_ASAR_PATCH != "1" ]]; then
    log "skipped Claude Desktop ASAR patch; set ENABLE_CLAUDE_DESKTOP_ASAR_PATCH=1 to opt in"
    return
  fi

  patch_claude_plist
  patch_claude_asar
  sign_app "$CLAUDE_APP" "Claude"
}

write_claude_wrapper
write_codex_wrapper
install_claude_desktop_hook
create_codex_lapdog_app
sign_app "$CODEX_LAPDOG_APP" "Codex Lapdog"
register_apps

log "installed Lapdog hooks"
