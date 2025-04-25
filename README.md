[![CI](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml)

# Nixpkgs

> Provision a workstation.

## Setup (MacOS)

1. Install [nix](https://nixos.org/):
    * [Graphical Installer](https://install.determinate.systems/nix-installer-pkg/stable/Universal)
    * CLI: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
1. Clone the repository: `git clone https://github.com/jonathanmorley/nixpkgs.git ~/.nixpkgs`
1. Add host config block to [flake.nix](`~/.nixpkgs/flake.nix`).
1. Run `nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake ~/.nixpkgs` to apply changes.

## Resources

- https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050
- https://github.com/malob/nixpkgs
- https://github.com/the-nix-way/nome
