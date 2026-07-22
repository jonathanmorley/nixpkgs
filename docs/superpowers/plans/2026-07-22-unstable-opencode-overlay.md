# Unstable OpenCode Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Home Manager OpenCode installation and the wrapped Apple Silicon OpenCode Desktop package resolve `opencode` from the locked `nixpkgs-unstable` input.

**Architecture:** Pass the already-locked `nixpkgs-unstable` input into the Darwin-system constructor and import it for the selected target system. Extend the existing primary-package overlay with a single `opencode = unstablePkgs.opencode` override. Because Home Manager uses the global package set and the desktop package obtains its OpenCode dependency from that package set, no duplicate system CLI installation or separate desktop-package override is needed.

**Tech Stack:** Nix flakes, nix-darwin, Home Manager, nixpkgs overlays.

## Global Constraints

- Keep all packages other than `opencode` on the primary pinned `nixpkgs` input.
- Do not add `opencode` to `environment.systemPackages`; `programs.opencode` already owns the CLI installation.
- Preserve the existing `opencode-desktop` fnox wrapper and Intel Homebrew fallback unchanged.
- Import unstable packages with `allowUnfree = true` and `allowUnsupportedSystem = true`, matching the primary package-set policy.
- Do not update `flake.lock` as part of this change.

______________________________________________________________________

### Task 1: Override OpenCode From The Existing Unstable Input

**Files:**

- Modify: `flake.nix:25-36`
- Modify: `lib/mkDarwinSystem.nix:1-38`

**Interfaces:**

- Consumes: the existing `inputs.nixpkgs-unstable` flake input declared at `flake.nix:6`.

- Produces: global `pkgs.opencode` equal to `unstablePkgs.opencode` for each configured Darwin system; Home Manager consumes this through `useGlobalPkgs = true`.

- [ ] **Step 1: Record the current primary and unstable package versions**

Run:

```sh
nix eval --raw .#darwinConfigurations.gha-aarch64-darwin.pkgs.opencode.version
nix eval --raw .#inputs.nixpkgs-unstable.legacyPackages.aarch64-darwin.opencode.version
```

Expected: the primary package-set version is returned by the first command; the second returns the version from the locked unstable input. If both versions currently match, retain the outputs as baseline evidence rather than treating equal versions as a failure.

- [ ] **Step 2: Pass `nixpkgs-unstable` to the Darwin-system constructor**

In `flake.nix`, add `nixpkgs-unstable` to the arguments destructured from `inputs`, then pass it to the `mkDarwinSystem` import:

```nix
  outputs = inputs @ {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    darwin,
    oktaws,
    flake-parts,
    ...
  }: let
    mkDarwinSystem = import ./lib/mkDarwinSystem.nix {
      inherit darwin home-manager nixpkgs nixpkgs-unstable oktaws;
      inherit (inputs) determinate;
    };
```

- [ ] **Step 3: Import the unstable package set and extend the existing overlay**

In `lib/mkDarwinSystem.nix`, accept `nixpkgs-unstable`, create an `unstablePkgs` binding for the active `system`, and add the OpenCode override to the existing custom-package overlay:

```nix
{
  darwin,
  determinate,
  home-manager,
  nixpkgs,
  nixpkgs-unstable,
  oktaws,
}: {
  system ? "aarch64-darwin",
  specialArgs,
  ...
}: let
  unstablePkgs = import nixpkgs-unstable {
    inherit system;
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };
in
darwin.lib.darwinSystem {
```

Add this member to the existing `(_final: prev: { ... })` overlay body:

```nix
opencode = unstablePkgs.opencode;
```

- [ ] **Step 4: Format and evaluate both Darwin architectures**

Run:

```sh
nix fmt
nix eval --raw .#darwinConfigurations.gha-aarch64-darwin.pkgs.opencode.version
nix eval --raw .#darwinConfigurations.smoke.pkgs.opencode.version
nix eval --raw .#darwinConfigurations.gha-aarch64-darwin.pkgs.opencode-desktop.version
```

Expected: all commands exit zero; both CLI evaluations equal the locked unstable `opencode` version; the Apple Silicon desktop evaluation also reports that version.

- [ ] **Step 5: Verify Home Manager and package provenance**

Run:

```sh
nix eval --raw .#darwinConfigurations.gha-aarch64-darwin.config.home-manager.users.runner.programs.opencode.package.version
nix flake check --no-update-lock-file
```

Expected: the Home Manager module reports the locked unstable OpenCode version; `nix flake check` exits zero without changing `flake.lock`.

- [ ] **Step 6: Review the focused diff**

Run:

```sh
git diff --check
git diff -- flake.nix lib/mkDarwinSystem.nix
git status --short
```

Expected: no whitespace errors; only the input plumbing and `opencode` overlay override are added to the implementation files; existing uncommitted fnox-wrapper edits and design documents remain intact.

- [ ] **Step 7: Commit the focused change when explicitly requested**

Run only after the user asks for a commit:

```sh
git add flake.nix lib/mkDarwinSystem.nix
git commit -m "feat: source opencode from unstable"
```
