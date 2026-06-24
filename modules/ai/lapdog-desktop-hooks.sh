#!/usr/bin/env bash
set -euo pipefail

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
CODEX_APP="${CODEX_APP:-/Applications/Codex.app}"
CODEX_LAPDOG_APP="${CODEX_LAPDOG_APP:-/Applications/Codex Lapdog.app}"
PLUTIL="${PLUTIL:-/usr/bin/plutil}"
CODESIGN="${CODESIGN:-/usr/bin/codesign}"
LAPDOG_SSL_CERT_FILE="${LAPDOG_SSL_CERT_FILE:-${SSL_CERT_FILE:-${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}}}"

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
    warn "codesign not found at $CODESIGN; $name may not launch"
    return
  fi

  if ! "$CODESIGN" --force --deep --sign - "$app" >/dev/null 2>&1; then
    warn "failed to ad-hoc sign $name at $app"
  fi
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

write_claude_wrapper
write_codex_wrapper
create_codex_lapdog_app
sign_app "$CODEX_LAPDOG_APP" "Codex Lapdog"

printf '[lapdog-hooks] installed Lapdog hooks\n' >&2
