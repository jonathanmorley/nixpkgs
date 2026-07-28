[![CI](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml)

# Nixpkgs

> Provision a workstation.

## Setup (MacOS)

1. Install [nix](https://nixos.org/):
   - [Graphical Installer](https://install.determinate.systems/nix-installer-pkg/stable/Universal)
   - CLI: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
1. Clone the repository: `git clone https://github.com/jonathanmorley/nixpkgs.git ~/.nixpkgs`
1. Add host config block to [flake.nix](~/.nixpkgs/flake.nix).
1. Run `nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake ~/.nixpkgs` to apply changes.

## Adding a New Host

1. Create a new `darwinConfigurations` entry in `flake.nix` calling `mkDarwinSystem`:

   ```nix
   "my-hostname" = mkDarwinSystem {
     inherit (nixpkgs) pkgs lib;
     specialArgs = {
       inherit stateVersions;
       profiles = [];          # or ["personal"] for non-work apps
       sshProvider = "1password";  # or "bitwarden"
       username = "your-user";
       sshKeys."github.com" = "ssh-ed25519 AAAA...";
     };
   };
   ```

1. Set the right `system` if not on Apple Silicon (e.g., `system = "x86_64-darwin"` for Intel Macs).

1. Apply: `nix run nix-darwin -- switch --flake ~/.nixpkgs#my-hostname`

The modular system picks up shared modules automatically — Darwin config from `modules/darwin.nix`, Home Manager from `modules/home.nix`, AI tooling, Docker, Git, and SSH provider secrets. To add host-specific overrides, use `extraDarwinModules` and `extraHomeModules`.

Available profiles:

- `"personal"` — includes non-work applications (Tailscale, Bambu Studio, etc.)

Available SSH providers:

- `"1password"` — SSH agent and Git signing via 1Password
- `"bitwarden"` — SSH agent and Git signing via Bitwarden

## Binary Caches

This repo uses the official NixOS cache plus Cachix caches, not FlakeHub Cache. The Darwin configuration writes these substituters through Determinate Nix, and CI pins the same cache list in `NIX_CONFIG` so `cache.flakehub.com` is not consulted:

- `https://cache.nixos.org`
- `https://nix-community.cachix.org`
- `https://jonathanmorley.cachix.org`

CI uploads and downloads from the `jonathanmorley` Cachix cache through `cachix/cachix-action` and the `CACHIX_AUTH_TOKEN` repository secret.

The `cachix` CLI is installed by the shared Home Manager configuration. Local reads from the configured public caches do not require authentication. To push paths, or to read a private cache, create a Cachix token and run:

```sh
cachix authtoken <token>
cachix doctor
```

## AI Instrumentation

The shared Darwin AI module installs Trajectory for Claude Code and Codex capture.
After switching a machine, run `trajectory-setup-ai` from a regular shell to let Trajectory install or refresh the agent hooks for those clients.

The Trajectory configuration test runs during `nix flake check` through the `checks.trajectory` derivation.

## Downstream Darwin Configurations

This flake exports `lib.mkDarwinSystem` for downstream configurations that need
the shared personal Darwin and Home Manager setup. The constructor accepts
`extraDarwinModules` and `extraHomeModules` so downstream flakes can layer
their own modules without duplicating the upstream input wiring:

```nix
base.lib.mkDarwinSystem {
  specialArgs = {
    stateVersions = {
      darwin = "7";
      homeManager = "26.05";
    };
    profiles = [];
    username = "example";
    sshKeys."github.com" = "";
  };
  extraDarwinModules = [];
  extraHomeModules = [];
}
```

## Resources

- https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050
- https://github.com/malob/nixpkgs
- https://github.com/the-nix-way/nome
