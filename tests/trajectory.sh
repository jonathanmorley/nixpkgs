#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$PWD/flake.nix" ] && [ -d "$PWD/modules" ]; then
  ROOT="$PWD"
else
  ROOT="$SCRIPT_ROOT"
fi
FAILED_TESTS=0
TOTAL_TESTS=0

print_result() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_file_exists() {
  local file="$1"
  local description="$2"

  if [ -f "$ROOT/$file" ]; then
    print_result 0 "$description"
  else
    print_result 1 "$description"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Fq "$pattern" "$ROOT/$file"; then
    print_result 0 "$description"
  else
    print_result 1 "$description"
  fi
}

assert_not_contains() {
  local pattern="$1"
  local description="$2"

  if grep -RFiq "$pattern" "$ROOT/modules" "$ROOT/pkgs" "$ROOT/lib" "$ROOT/cert-check.nix" "$ROOT/tests/certs.sh"; then
    print_result 1 "$description"
  else
    print_result 0 "$description"
  fi
}

echo "=========================================="
echo "Trajectory AI Instrumentation Test Suite"
echo "=========================================="
echo ""

assert_file_exists "pkgs/trajectory/default.nix" "Trajectory package exists"
assert_contains "pkgs/trajectory/default.nix" "TRAJECTORY_AUTO_UPDATE" "Trajectory package disables automatic self-update checks"
assert_contains "pkgs/trajectory/default.nix" "managed by Nix" "Trajectory package blocks in-place self-updates"
assert_contains "lib/mkDarwinSystem.nix" "trajectory = prev.callPackage ../pkgs/trajectory {};" "Trajectory is exposed through the package overlay"
assert_contains "modules/ai/darwin.nix" "pkgs.trajectory" "Trajectory binary is installed by the AI Darwin module"
assert_contains "modules/ai/darwin.nix" "trajectory-setup-ai" "AI Darwin module exposes a setup helper"
assert_contains "modules/ai/darwin.nix" "TRAJECTORY_INSTALL_OWNER=nix" "Setup helper writes a Nix-owned Trajectory self-update policy"
assert_contains "modules/ai/darwin.nix" "TRAJECTORY_SELF_UPDATE=disabled" "Setup helper disables Trajectory self-updates"
assert_contains "modules/ai/darwin.nix" "trajectory setup --clients cc --non-interactive" "Setup helper configures Claude Code"
assert_contains "modules/ai/darwin.nix" "trajectory setup --clients codex --non-interactive" "Setup helper configures Codex"
assert_contains "modules/ai/darwin.nix" "CLAUDE_CODE_LOCAL_BINARY" "Claude Desktop still points at the native Claude CLI"
# shellcheck disable=SC2016
assert_contains "modules/ai/darwin.nix" '/etc/profiles/per-user/${config.system.primaryUser}/bin/claude' "Claude Desktop binary path is managed by Nix"
assert_contains "cert-check.nix" "test-trajectory" "Trajectory static test is exposed as a flake app"

assert_not_contains "lapdog" "Lapdog references are removed"
assert_not_contains "datadog/lapdog" "Datadog Lapdog Homebrew tap is removed"
assert_not_contains "codex-lapdog" "Codex Lapdog wrapper is removed"
assert_not_contains "claude-lapdog" "Claude Lapdog wrapper is removed"

echo ""
echo "=========================================="
echo "Results: $((TOTAL_TESTS - FAILED_TESTS))/$TOTAL_TESTS passed"
echo "=========================================="

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
