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

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Fq "$pattern" "$ROOT/$file"; then
    print_result 1 "$description"
  else
    print_result 0 "$description"
  fi
}

assert_not_contains() {
  local pattern="$1"
  local description="$2"

  if grep -RFiq "$pattern" \
    "$ROOT/cert-check.nix" \
    "$ROOT/lib" \
    "$ROOT/modules/ai" \
    "$ROOT/modules/darwin.nix" \
    "$ROOT/modules/docker" \
    "$ROOT/modules/git" \
    "$ROOT/modules/home.nix" \
    "$ROOT/modules/personal" \
    "$ROOT/pkgs"; then
    print_result 1 "$description"
  else
    print_result 0 "$description"
  fi
}

assert_home_file_forced() {
  local path="$1"
  local description="$2"

  if awk -v declaration="home.file.\"$path\" = {" '
    index($0, declaration) {
      in_block = 1
      seen = 1
      next
    }

    in_block && /force = true;/ {
      forced = 1
    }

    in_block && /^  \};$/ {
      done = 1
      in_block = 0
    }

    END {
      exit (seen && done && forced) ? 0 : 1
    }
  ' "$ROOT/modules/ai/home.nix"; then
    print_result 0 "$description"
  else
    print_result 1 "$description"
  fi
}

echo "=========================================="
echo "Trajectory AI Instrumentation Test Suite"
echo "=========================================="
echo ""

assert_file_exists "pkgs/trajectory/default.nix" "Trajectory package exists"
assert_contains "pkgs/trajectory/default.nix" 'version = "0.5.38";' "Trajectory package is pinned to the expected release"
assert_contains "pkgs/trajectory/default.nix" "intercept-shared.mjs" "Trajectory package includes shared intercept asset"
assert_contains "pkgs/trajectory/default.nix" "bun-llm-intercept.mjs" "Trajectory package includes Bun intercept asset"
assert_contains "pkgs/trajectory/default.nix" "node-llm-spy.cjs" "Trajectory package includes Node intercept asset"
assert_contains "pkgs/trajectory/default.nix" "TRAJECTORY_AUTO_UPDATE" "Trajectory package disables automatic self-update checks"
assert_contains "pkgs/trajectory/default.nix" "managed by Nix" "Trajectory package blocks in-place self-updates"
assert_contains "pkgs/trajectory/default.nix" "TRAJECTORY_INSTALL_OWNER=nix" "Trajectory package sets Nix-owned install owner"
assert_contains "pkgs/trajectory/default.nix" "TRAJECTORY_SELF_UPDATE=disabled" "Trajectory package disables self-updates"
assert_contains "pkgs/trajectory/default.nix" "include_headless_agents: true" "Trajectory package enables headless Claude Code capture"
assert_contains "lib/mkDarwinSystem.nix" "trajectory = prev.callPackage ../pkgs/trajectory {};" "Trajectory is exposed through the package overlay"
assert_contains "modules/ai/darwin.nix" "pkgs.trajectory" "Trajectory binary is installed by the AI Darwin module"
assert_file_not_contains "modules/ai/darwin.nix" "trajectory-setup-ai" "Imperative setup helper is removed from Darwin module"
assert_file_not_contains "modules/ai/darwin.nix" "selfupdate.conf" "Darwin module does not write the managed Trajectory self-update policy"
assert_file_exists "modules/ai/trajectory.nix" "Trajectory module exists"
assert_contains "modules/ai/trajectory.nix" "options.services.trajectory" "Trajectory module defines options"
assert_contains "modules/ai/trajectory.nix" "mkEnableOption" "Trajectory module has enable option"
assert_contains "modules/ai/trajectory.nix" "export.site" "Trajectory module has export.site option"
assert_contains "modules/ai/trajectory.nix" "features.enabled" "Trajectory module has features.enabled option"
assert_contains "modules/ai/trajectory.nix" "launchd.agents.trajectory-serve" "Trajectory module configures launchd agent"
assert_contains "modules/ai/trajectory.nix" "launchd.agents.trajectory-view" "Trajectory module configures view launchd agent"
assert_contains "modules/ai/trajectory.nix" 'view' "Trajectory module has view option"
assert_contains "lib/mkDarwinSystem.nix" "trajectory.nix" "Trajectory module is imported"
assert_contains "modules/ai/home.nix" "services.trajectory.enable" "Home Manager enables trajectory module"
assert_contains "modules/ai/home.nix" 'trajectory-opencode/skills' "Home Manager configures Trajectory skills path for OpenCode"
assert_contains "pkgs/trajectory/default.nix" "plugin/trajectory-opencode" "Trajectory package includes OpenCode plugin source"
assert_contains "pkgs/trajectory/default.nix" "claude-marketplace" "Trajectory package includes Claude Code marketplace"
assert_contains "pkgs/trajectory/default.nix" "fetchFromGitHub" "Trajectory package fetches plugin source from GitHub"
assert_contains "modules/ai/home.nix" 'trajectory' "Home Manager references trajectory plugin"
assert_contains "modules/ai/home.nix" 'mcp = {' "Home Manager configures trajectory MCP server"
assert_file_not_contains "modules/ai/darwin.nix" "CLAUDE_CODE_LOCAL_BINARY" "Claude Desktop binary override is not set for Trajectory"
assert_contains "flake.nix" 'trajectory = pkgs.runCommand "trajectory-tests"' "Trajectory static test is exposed as a flake check"

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
