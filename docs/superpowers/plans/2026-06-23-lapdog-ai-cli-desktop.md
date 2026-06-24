# Lapdog AI CLI Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Datadog Lapdog through nix-darwin and make the normal Claude/Codex CLI paths plus Raycast-launched desktop paths use Lapdog by default.

**Architecture:** Home Manager zsh functions wrap `claude` and `codex` with `lapdog`. A nix-darwin activation helper creates stable wrapper executables and a `Codex Lapdog.app` launcher that uses the supported `lapdog codex app` path. Claude Desktop is instrumented by setting `CLAUDE_CODE_LOCAL_BINARY=/usr/local/bin/claude-lapdog-desktop` in the user launchd environment, so Raycast/Finder launches inherit it without modifying the signed app bundle. The Claude Desktop ASAR/plist patch is retained only behind `ENABLE_CLAUDE_DESKTOP_ASAR_PATCH=1`; it is disabled by default because ad-hoc re-signing Claude Desktop can strip Electron entitlements and crash the app.

**Tech Stack:** nix-darwin, Home Manager, Homebrew, Bash, Python from nixpkgs for ASAR patching, macOS PlistBuddy/plutil.

______________________________________________________________________

### Task 1: Regression Test for Desktop Hook Installer

**Files:**

- Create: `tests/lapdog-desktop-hooks.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/modules/ai/lapdog-desktop-hooks.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/Claude.app/Contents/Resources" "$tmp_dir/Claude.app/Contents/MacOS"
mkdir -p "$tmp_dir/bin"
printf '#!/usr/bin/env bash\n' >"$tmp_dir/lapdog"
chmod +x "$tmp_dir/lapdog"

"$script" install
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/lapdog-desktop-hooks.sh`
Expected: FAIL because `modules/ai/lapdog-desktop-hooks.sh` does not exist.

### Task 2: Activation Helper

**Files:**

- Create: `modules/ai/lapdog-desktop-hooks.sh`

- Modify: `tests/lapdog-desktop-hooks.sh`

- [ ] **Step 1: Implement the helper**

The helper creates `/usr/local/bin/claude-lapdog-desktop`, `/usr/local/bin/codex-lapdog-app`, and `Codex Lapdog.app`. By default it does not modify, re-register, or re-sign `Claude.app`; with `ENABLE_CLAUDE_DESKTOP_ASAR_PATCH=1`, it patches Claude `Info.plist`, patches Claude `app.asar`, updates `ElectronAsarIntegrity`, and re-signs the app for explicit experimentation only. Clean Claude cask builds inspected from Homebrew caches already read `CLAUDE_CODE_LOCAL_BINARY` and route `getBinaryPathIfReady()`/`prepare()` through the override, so ASAR patching is not needed for those builds.

- [ ] **Step 2: Run focused test**

Run: `bash tests/lapdog-desktop-hooks.sh`
Expected: PASS with all assertions.

### Task 3: Nix Wiring

**Files:**

- Modify: `modules/ai/darwin.nix`

- Modify: `modules/ai/home.nix`

- Modify: `cert-check.nix`

- [ ] **Step 1: Add Lapdog Homebrew installation and activation**

Add the Datadog Homebrew tap/formula, install the helper script as a system package, and run it during activation for non-runner machines.

- [ ] **Step 2: Add CLI wrapper functions**

Add zsh functions so `claude` runs `lapdog claude`, `codex` runs `lapdog codex`, and `claude-raw`/`codex-raw` bypass Lapdog.

- [ ] **Step 3: Add Claude Desktop launchd environment**

Set `launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY` to `/usr/local/bin/claude-lapdog-desktop` so GUI launches inherit the local binary override.

- [ ] **Step 4: Add a flake app for the test**

Expose `nix run .#test-lapdog-desktop-hooks`.

### Task 4: Verify Without Mutating the Laptop

**Files:**

- No new files.

- [ ] **Step 1: Run local tests and formatting**

Run: `bash tests/lapdog-desktop-hooks.sh`, `nix run .#test-lapdog-desktop-hooks`, and `nix fmt`.

- [ ] **Step 2: Build the current laptop config without switching**

Run: `sudo darwin-rebuild build --flake .`

- [ ] **Step 3: Defer switch and smoke test**

Do not run `darwin-rebuild switch`, launch the desktop apps, or mutate `/Applications` directly during this implementation pass. Once the repository changes are reviewed, applying them through `darwin-rebuild switch --flake .` will run the activation helper and then desktop verification can be done by launching Claude/Codex from Raycast and checking Lapdog’s local agent/status.
