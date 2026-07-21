# Global Worktrees Ignore Design

## Goal

Prevent Git from showing Superpowers-created root-level `.worktrees`
directories as untracked content in every repository managed by this user
configuration.

## Design

Append `/.worktrees/` to `programs.git.ignores` in `modules/git/home.nix`.
Home Manager will combine this local rule with the existing platform-specific
global ignore patterns fetched from GitHub.

The leading slash restricts the pattern to a repository-root `.worktrees`
directory. Nested directories with that name remain visible to Git, avoiding a
broader global exclusion than needed.

## Verification

Run `nix fmt` and `nix flake check`. Confirm the evaluated source list contains
both the fetched platform ignore rules and `/.worktrees/`, then review the diff
for a single added ignore pattern.

## Out of Scope

- Adding a `.worktrees` rule to repository `.gitignore` files.
- Ignoring nested `.worktrees` directories.
- Creating or applying a Nix Darwin switch.
