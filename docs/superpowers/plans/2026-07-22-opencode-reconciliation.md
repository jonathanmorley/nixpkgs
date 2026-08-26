# OpenCode Staging Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconcile generic OpenCode v1.18.4 integration into the sanitized fresh-root staging tree at `/tmp/personal-nixpkgs.staging`.

**Architecture:** Use a disposable local worktree/clone from the staging fresh root for all reconciliation steps, preserving the existing staging as a rollback candidate. All code and test changes occur in a dedicated candidate workspace.

**Tech Stack:** Nix (Flakes), git, nix-darwin.

## Global Constraints

- Target staging root: `/tmp/personal-nixpkgs.staging`
- Disposable reconciliation workspace: `/tmp/personal-nixpkgs.reconciliation`
- No push to preview remote or personal origin
- Target candidate paths: `flake.nix`, `flake.lock`, `lib/mkDarwinSystem.nix`, `modules/ai/darwin.nix`, `opencode-check.nix`, `tests/opencode.sh`
- Generic overlay with `opencode ? null` for public builder compatibility
- No Cvent CA, Sourcegraph/MCP, credentials, certs, or `modules/cvent/**`
- No host switches or full desktop builds
- Cvent pin in staging remains unchanged (preview `f8ca881`)
- Nixpkgs-unstable pin remains unchanged
- No committed intentionally failing tests
- No unresolved conflict marker syntax (`<<<<`, `====`, `>>>>`) in documentation or examples
- Plan itself is a private migration artifact excluded from sanitized candidate

______________________________________________________________________

### Task 1: Workspace Initialization

**Files:**

- Create: `/tmp/personal-nixpkgs.reconciliation` (via git clone)

**Interfaces:**

- Produces: Candidate workspace at `/tmp/personal-nixpkgs.reconciliation`

- [ ] **Step 1: Create disposable reconciliation workspace**

Run:

```bash
git clone /tmp/personal-nixpkgs.staging /tmp/personal-nixpkgs.reconciliation
cd /tmp/personal-nixpkgs.reconciliation
```

- [ ] **Step 2: Verify baseline staging state**

Run:

```bash
nix flake check --no-build --no-write-lock-file
./docs/migration/scan-leaks.sh --dir .
```

Expected: exit 0 and `hits=0`

- [ ] **Step 3: Commit baseline check**

```bash
GIT_MASTER=1 git commit --allow-empty -m "chore: baseline verification in reconciliation candidate"
```

______________________________________________________________________

### Task 2: Discovery and Interface Definition

**Files:**

- Create: `opencode-check.nix`
- Modify: `flake.nix`

**Interfaces:**

- Produces: `checks.opencode` in the candidate flake

- [ ] **Step 1: Discover OpenCode attributes**

Run:

```bash
nix flake metadata github:anomalyco/opencode/v1.18.4 --no-write-lock-file
```

Expected: Confirmation of `opencode` and `opencode-desktop` packages.

- [ ] **Step 2: Create opencode-check.nix**

Create `opencode-check.nix` in the candidate root:

```nix
{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    checks.opencode = lib.optionalAttrs (system == "aarch64-darwin") (
      pkgs.runCommand "opencode-package-tests" {} ''
        # Verify packages are evaluatable
        echo "Testing opencode-desktop: ${self.darwinConfigurations.gha-aarch64-darwin.pkgs.opencode-desktop.name}"
        echo "Testing opencode: ${self.darwinConfigurations.gha-aarch64-darwin.pkgs.opencode.name}"
        touch "$out"
      ''
    );
  };
}
```

- [ ] **Step 3: Register check in flake.nix**

Add `./opencode-check.nix` to the `imports` list in the `flake-parts.lib.mkFlake` call within `flake.nix`.

- [ ] **Step 4: Commit**

```bash
GIT_MASTER=1 git add opencode-check.nix flake.nix
GIT_MASTER=1 git commit -m "feat: add opencode behavior check interface"
```

______________________________________________________________________

### Task 3: Flake Input and API Reconciliation

**Files:**

- Modify: `flake.nix`
- Modify: `flake.lock`
- Modify: `lib/mkDarwinSystem.nix`

**Interfaces:**

- Consumes: `opencode` flake input

- Produces: Overlaid `opencode` and `opencode-desktop` in candidate `pkgs`

- [ ] **Step 1: Add opencode input to flake.nix**

Update the `inputs` block in `flake.nix`:

```nix
    opencode.url = "github:anomalyco/opencode/v1.18.4";
```

- [ ] **Step 2: Update mkDarwinSystem in lib/mkDarwinSystem.nix**

Adjust the argument set to accept `opencode ? null` and implement the overlay logic:

```nix
{
  # ...
  opencode ? null,
}: {
  # ...
  nixpkgs.overlays = [
    (final: prev: {
      opencode = if opencode != null then opencode.packages.${prev.stdenv.hostPlatform.system}.opencode else null;
      opencode-desktop = if opencode != null then opencode.packages.${prev.stdenv.hostPlatform.system}.opencode-desktop else null;
    })
  ];
}
```

- [ ] **Step 3: Update flake.nix output to pass input**

Ensure `opencode` is passed to the `mkDarwinSystem` call in `outputs`:

```nix
    mkDarwinSystem = import ./lib/mkDarwinSystem.nix {
      inherit darwin home-manager nixpkgs opencode oktaws;
      inherit (inputs) determinate;
    };
```

- [ ] **Step 4: Lock opencode input**

Run: `nix flake lock --update-input opencode --no-write-lock-file`
Expected: `flake.lock` updated with `opencode` v1.18.4.

- [ ] **Step 5: Verify evaluation**

Run: `nix flake check --no-build --no-write-lock-file`
Expected: exit 0

- [ ] **Step 6: Commit**

```bash
GIT_MASTER=1 git add flake.nix lib/mkDarwinSystem.nix flake.lock
GIT_MASTER=1 git commit -m "feat: integrate generic opencode flake input and overlay"
```

______________________________________________________________________

### Task 4: AI Module and Test Implementation

**Files:**

- Modify: `modules/ai/darwin.nix`
- Create: `tests/opencode.sh`

**Interfaces:**

- Produces: Wrapped `opencode-desktop` and behavior test in candidate

- [ ] **Step 1: Update modules/ai/darwin.nix**

Implement conditional package installation:

```nix
  environment.systemPackages =
    [
      pkgs.mempalace
      pkgs.trajectory
      trajectorySetupAi
    ]
    ++ lib.optional (pkgs.stdenv.hostPlatform.isAarch64 && pkgs.opencode-desktop != null) pkgs.opencode-desktop;
```

- [ ] **Step 2: Create tests/opencode.sh**

Create the behavior test script:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify aarch64 desktop package and x86 cask fallback
if [[ $(uname -m) == "arm64" ]]; then
  nix eval .#darwinConfigurations.gha-aarch64-darwin.pkgs.opencode-desktop.name --raw | grep "opencode-desktop"
else
  grep "opencode-desktop" modules/ai/darwin.nix | grep "casks"
fi
```

- [ ] **Step 3: Run behavior test locally (uncommitted)**

Run: `chmod +x tests/opencode.sh && ./tests/opencode.sh`
Expected: PASS

- [ ] **Step 4: Verify full candidate evaluation**

Run: `nix flake check --no-build --no-write-lock-file`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
GIT_MASTER=1 git add modules/ai/darwin.nix tests/opencode.sh
GIT_MASTER=1 git commit -m "feat: add opencode desktop wrapper and behavior test"
```

______________________________________________________________________

### Task 5: Final Validation and Handover

**Files:**

- Create: `/tmp/personal-nixpkgs.staging.reconciled` (Sanitized Handover)

- [ ] **Step 1: Final validation suite in candidate**

Run:

```bash
nix fmt -- --ci
nix flake check --no-build --no-write-lock-file
./docs/migration/scan-leaks.sh --dir .
./docs/migration/compare-public-projection.sh .
```

Expected: exit 0, `hits=0`, no unexpected drift.

- [ ] **Step 2: Verify zero stale objects**

Run: `git gc --prune=now`

- [ ] **Step 3: Create fresh local staging candidate**

Run:

```bash
mkdir -p /tmp/personal-nixpkgs.staging.reconciled
cp -a . /tmp/personal-nixpkgs.staging.reconciled
cd /tmp/personal-nixpkgs.staging.reconciled
rm -rf .git
git init
git add .
git commit -m "chore: fresh staging candidate with reconciled opencode"
```

- [ ] **Step 4: Final boundary check**

Confirm:

- No remote push to preview

- No preview update

- No Cvent repin

- No personal origin force update

- No host switch

- No local path inputs in flake.nix

- [ ] **Step 5: Commit plan update (Migration Artifact Only)**

In the mixed source tree:

```bash
GIT_MASTER=1 git add docs/superpowers/plans/2026-07-22-opencode-reconciliation.md
GIT_MASTER=1 git commit -m "docs(plans): replace unsafe reconciliation plan with staging-only candidate"
```
