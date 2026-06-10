[![CI](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanmorley/nixpkgs/actions/workflows/ci.yml)

# Nixpkgs

> Provision a workstation.

## Setup (MacOS)

1. Install [nix](https://nixos.org/):
   - [Graphical Installer](https://install.determinate.systems/nix-installer-pkg/stable/Universal)
   - CLI: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
1. Clone the repository: `git clone https://github.com/jonathanmorley/nixpkgs.git ~/.nixpkgs`
1. Add host config block to [flake.nix](~/.nixpkgs/flake.nix).
1. Authenticate with FlakeHub: `determinate-nixd login`
1. Run `nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake ~/.nixpkgs` to apply changes.

## FlakeHub Authentication

Determinate Nix uses `/nix/var/determinate/netrc` for FlakeHub credentials. Do not edit that file directly; run `determinate-nixd login` when local builds or switches report FlakeHub 401s. You can verify CLI login state with `nix shell "https://flakehub.com/f/DeterminateSystems/fh/*" --command fh status`.

GitHub Actions authenticates to FlakeHub through OIDC. The workflow grants `id-token: write` and runs `DeterminateSystems/flakehub-cache-action`, but FlakeHub still has to authorize this GitHub identity for the selected cache resource. If CI reports `User is not authorized for this resource`, FlakeHub login succeeded but cache authorization failed. For personal repositories, log in to FlakeHub with the repository owner account and make sure the account has FlakeHub Cache access. For organization repositories, create the FlakeHub organization, install the FlakeHub GitHub app for that GitHub organization, grant it access to this repository, and make sure the organization has FlakeHub Cache access.

## Resources

- https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050
- https://github.com/malob/nixpkgs
- https://github.com/the-nix-way/nome
