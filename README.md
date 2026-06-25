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

## Resources

- https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050
- https://github.com/malob/nixpkgs
- https://github.com/the-nix-way/nome
