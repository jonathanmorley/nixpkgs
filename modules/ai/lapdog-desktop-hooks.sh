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
CODEX_LAPDOG_APP="${CODEX_LAPDOG_APP:-/Applications/Codex Lapdog.app}"
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"
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
    printf 'exec "%s" codex "$@"\n' "$LAPDOG_BIN"
  } >"$CODEX_WRAPPER"
  chmod 0755 "$CODEX_WRAPPER"
}

remove_legacy_codex_lapdog_app() {
  local info_plist="$CODEX_LAPDOG_APP/Contents/Info.plist"
  local bundle_id

  if [[ ! -d $CODEX_LAPDOG_APP ]]; then
    return
  fi

  if [[ ! -f $info_plist || ! -x $PLISTBUDDY ]]; then
    warn "skipping removal of $CODEX_LAPDOG_APP; cannot verify generated bundle id"
    return
  fi

  bundle_id="$("$PLISTBUDDY" -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || true)"
  if [[ $bundle_id == "local.lapdog.codex" ]]; then
    rm -rf "$CODEX_LAPDOG_APP"
  else
    warn "skipping removal of $CODEX_LAPDOG_APP; unexpected bundle id: ${bundle_id:-missing}"
  fi
}

write_claude_wrapper
write_codex_wrapper
remove_legacy_codex_lapdog_app

printf '[lapdog-hooks] installed Lapdog hooks\n' >&2
