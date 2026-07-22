# OpenCode Bun CA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build OpenCode successfully on Cvent Darwin hosts by making Bun trust the repository's store-backed Netskope CA bundle during dependency installation.

**Architecture:** Pass the pinned `opencode` flake input to Darwin modules through `specialArgs`. In the Cvent module, override the upstream fixed-output node-modules derivation's build phase. The replacement is identical to upstream except that `bun install` receives `--cafile "${certBundle}"`; overridden upstream OpenCode and desktop packages consume that dependency.

**Tech Stack:** Nix flakes, nix-darwin overlays, Bun 1.3.13, OpenCode v1.18.4.

## Global Constraints

- Apply the override only when `profiles` contains `cvent`.
- Use `certBundle`, which is a `/nix/store` path containing Mozilla roots and the pinned Netskope root.
- Preserve TLS verification; do not use TLS-bypass environment variables or flags.
- Preserve upstream Bun filters, platform arguments, lockfile behavior, ignored scripts, canonicalization, normalization, and fixed-output hash.
- Do not change personal, CI, or Intel fallback OpenCode packages.
- Do not commit unless explicitly requested.

______________________________________________________________________

### Task 1: Expose The Pinned OpenCode Input To Darwin Modules

**Files:**

- Modify: `lib/mkDarwinSystem.nix:13-15`
- Test: Nix evaluation of the Cvent Darwin configuration

**Interfaces:**

- Consumes: the `opencode` flake input already passed to `mkDarwinSystem`.

- Produces: an `opencode` module argument equal to the pinned flake input.

- [ ] **Step 1: Add the input to module special arguments**

Change the `darwin.lib.darwinSystem` argument from:

```nix
  inherit specialArgs system;
```

to:

```nix
  inherit system;
  specialArgs = specialArgs // {inherit opencode;};
```

- [ ] **Step 2: Evaluate the target configuration**

Run:

```sh
nix eval --raw .#darwinConfigurations.D3W27G1QW9.pkgs.opencode.version
```

Expected: exits zero and prints `1.18.4+49c69c5`.

### Task 2: Rebuild Cvent OpenCode Dependencies With The CA Bundle

**Files:**

- Modify: `modules/cvent/darwin.nix:2-76`
- Test: Nix evaluation of the Cvent node-modules derivation

**Interfaces:**

- Consumes: `opencode` from module arguments and the existing `certBundle` local binding.

- Produces: `cventNodeModules`, an overridden fixed-output derivation matching the upstream node-modules result while running Bun with `--cafile "${certBundle}"`.

- [ ] **Step 1: Add `opencode` to the module argument set**

Change the module header to include the input:

```nix
{
  pkgs,
  lib,
  config,
  opencode,
  ...
}:
```

- [ ] **Step 2: Override the Cvent node-modules build phase**

After `certBundle`, add:

```nix
  upstreamOpencode = opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  cventNodeModules = upstreamOpencode.node_modules.overrideAttrs (old: {
    buildPhase = lib.replaceStrings
      [ "bun install \\\n+" ]
      [ "bun install \\\n+          --cafile \"${certBundle}\" \\\n+" ]
      old.buildPhase;
  });
```

Keep every other upstream attribute, including the default `hash`, unchanged. The trusted CA affects only network verification, not the expected normalized dependency output. This transformation retains the upstream canonicalization and binary-normalization script paths already embedded in `old.buildPhase`.

- [ ] **Step 3: Evaluate the replacement derivation**

Run:

```sh
nix eval --raw .#darwinConfigurations.D3W27G1QW9.pkgs.opencode.node_modules.drvPath
```

Expected: exits zero and prints an `opencode-node_modules-1.18.4+49c69c5.drv` path distinct from the unmodified upstream derivation.

### Task 3: Replace Only Cvent OpenCode Packages

**Files:**

- Modify: `modules/cvent/darwin.nix:39-53`
- Test: Cvent and non-Cvent package evaluation

**Interfaces:**

- Consumes: `cventNodeModules` from Task 2 and the pinned `opencode` source.

- Produces: Cvent-only `pkgs.opencode` and `pkgs.opencode-desktop` based on the CA-aware dependency derivation.

- [ ] **Step 1: Define reconstructed packages**

After `cventNodeModules`, add:

```nix
  cventOpencode = upstreamOpencode.override {
    node_modules = cventNodeModules;
  };
  cventOpencodeDesktop = opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop.override {
    opencode = cventOpencode;
  };
```

- [ ] **Step 2: Add a Cvent-only package overlay**

Add this overlay after the existing `fnox`, `gig`, and `rtk` override overlay:

```nix
    (_final: _prev: {
      opencode = cventOpencode;
      opencode-desktop = cventOpencodeDesktop;
    })
```

This overlay must remain in `modules/cvent/darwin.nix`; that module is imported only for Cvent profiles.

- [ ] **Step 3: Verify Cvent and CI derivations differ only by intended scope**

Run:

```sh
nix eval --raw .#darwinConfigurations.D3W27G1QW9.pkgs.opencode.node_modules.drvPath
nix eval --raw .#darwinConfigurations.gha-aarch64-darwin.pkgs.opencode.node_modules.drvPath
```

Expected: both commands exit zero; the Cvent result is the CA-aware derivation and the CI result remains the upstream derivation.

### Task 4: Build And Verify The Package Graph

**Files:**

- Modify: none
- Test: Cvent node-modules build, Cvent OpenCode evaluation, formatting, and flake checks

**Interfaces:**

- Consumes: the Task 3 overlay.

- Produces: a validated Cvent OpenCode package that can install the GitHub dependency through the Netskope trust chain.

- [ ] **Step 1: Build the Cvent node-modules derivation**

Run:

```sh
nix build .#darwinConfigurations.D3W27G1QW9.pkgs.opencode.node_modules --no-link --print-build-logs
```

Expected: Bun resolves `ghostty-web` without `SELF_SIGNED_CERT_IN_CHAIN`, and Nix reports a successful build.

- [ ] **Step 2: Confirm the build phase contains only the CA addition**

Run:

```sh
nix derivation show "$(nix eval --raw .#darwinConfigurations.D3W27G1QW9.pkgs.opencode.node_modules.drvPath)" | rg -- '--cafile|--filter|--frozen-lockfile|--ignore-scripts'
```

Expected: output contains `--cafile` with the `cacert-with-netskope` store path and all three upstream filters plus frozen-lockfile and ignore-scripts flags.

- [ ] **Step 3: Run repository checks**

Run:

```sh
nix fmt
nix flake check --no-update-lock-file
```

Expected: both commands exit zero without changing `flake.lock`.

- [ ] **Step 4: Inspect the final patch**

Run:

```sh
git diff --check
```

Expected: no whitespace errors; changes are limited to exposing the pinned flake input and the Cvent-only CA-aware OpenCode overlay.
