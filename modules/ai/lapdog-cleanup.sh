#!/usr/bin/env bash
set -euo pipefail

warn() {
  printf '[lapdog-cleanup] warning: %s\n' "$*" >&2
}

die() {
  printf '[lapdog-cleanup] error: %s\n' "$*" >&2
  exit 1
}

command_name="${1:-install}"

if [[ $command_name != "install" ]]; then
  die "unsupported command: $command_name"
fi

CODEX_LAPDOG_APP="${CODEX_LAPDOG_APP:-/Applications/Codex Lapdog.app}"
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"

if [[ -d $CODEX_LAPDOG_APP ]]; then
  info_plist="$CODEX_LAPDOG_APP/Contents/Info.plist"
  if [[ ! -f $info_plist || ! -x $PLISTBUDDY ]]; then
    warn "skipping removal of $CODEX_LAPDOG_APP; cannot verify generated bundle id"
    exit 0
  fi

  bundle_id="$("$PLISTBUDDY" -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || true)"
  if [[ $bundle_id == "local.lapdog.codex" ]]; then
    rm -rf "$CODEX_LAPDOG_APP"
  else
    warn "skipping removal of $CODEX_LAPDOG_APP; unexpected bundle id: ${bundle_id:-missing}"
  fi
fi

printf '[lapdog-cleanup] removed legacy generated apps\n' >&2
