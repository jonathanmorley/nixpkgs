# OpenCode fnox Wrapper Design

## Goal

Launch the Nix-built OpenCode Desktop application with the user-global fnox
environment for every macOS launch path, without placing secret values in the
Nix store or depending on Raycast-specific launcher logic.

## Scope

- Replace the Apple Silicon Homebrew `opencode-desktop` cask with a wrapped
  `opencode-desktop` package from `nixpkgs-unstable` in the shared AI Darwin
  module.
- Make Home Manager's existing `programs.opencode` installation resolve to
  `nixpkgs-unstable`'s `opencode` package.
- Keep the current fnox global configuration at `~/.config/fnox/config.toml`
  as the single secret-definition source.
- Preserve an evaluatable configuration for the Intel Darwin host, where
  `opencode-desktop` is not currently supported by nixpkgs.

## Design

`flake.nix` will pass the existing `nixpkgs-unstable` input into the Darwin
system constructor. `lib/mkDarwinSystem.nix` will import that input for the
active target system with the same unfree-package policy as the primary package
set. The existing package overlay will override only `opencode` with the
unstable package. Home Manager already uses the global package set, so its
existing `programs.opencode` module will install that overridden CLI without a
new system-package entry. The primary pinned `nixpkgs` remains the source for
every other package.

`modules/ai/darwin.nix` will retain the Darwin overlay that overrides
`opencode-desktop`, but its package input will resolve to the overridden
unstable `opencode`. On Apple Silicon, it will rename:

```text
OpenCode.app/Contents/MacOS/OpenCode
```

to a private sibling, then install a `makeBinaryWrapper` executable at the
original location. The wrapper will invoke:

```text
fnox exec -- <private-original-executable>
```

with all arguments forwarded by the generated wrapper. Because LaunchServices,
Finder, Dock, and Raycast start the executable inside the app bundle, every
normal application launch path receives the same environment. The existing
`bin/opencode-desktop` symlink targets that bundle executable, so command-line
launches use the wrapper too.

The wrapper contains only immutable Nix-store paths for fnox and the renamed
OpenCode executable. fnox resolves `SOURCEGRAPH_MCP_TOKEN` and any other
existing global entries at launch time through the configured `rbw` provider;
the derivation does not contain secret values, Bitwarden credentials, or
generated secret files.

The existing Home Manager OpenCode configuration installs unstable `opencode`
on both Darwin architectures. The AI module installs the wrapped unstable
`opencode-desktop` only on `aarch64-darwin` and removes `opencode-desktop` from
the Homebrew casks on Apple Silicon. On
`x86_64-darwin`, it will retain the existing Homebrew cask because nixpkgs does
not support `opencode-desktop` there. This keeps all configured Darwin hosts
evaluatable without silently dropping the application from Intel machines.

## Error Handling

fnox's existing global configuration controls resolution behavior. The wrapper
does not add fallbacks: if rbw is locked or a required secret cannot resolve,
`fnox exec` fails and OpenCode does not start with a partial environment. The
user's existing shell initialization unlocks rbw interactively; GUI launches
therefore require its configured rbw agent session to remain unlocked.

## Verification

1. Format the modified Nix expressions with `nix fmt`.
1. Evaluate `nix flake check` and both Apple Silicon and Intel Darwin
   configurations.
1. Evaluate Home Manager's installed `opencode` and the wrapped
   `opencode-desktop` derivation to confirm their version comes from the locked
   `nixpkgs-unstable` input.
1. Build the wrapped `opencode-desktop` derivation and inspect the app bundle:
   the original executable is private and `Contents/MacOS/OpenCode` is a
   wrapper.
1. With rbw unlocked, launch the built app via the macOS application surface
   and confirm OpenCode starts with the fnox-injected `SOURCEGRAPH_MCP_TOKEN`.
1. Confirm the wrapper contains no secret value by inspecting its generated
   launcher and reviewing the Nix diff.

## Out of Scope

- Altering fnox's existing global provider or secret definitions.
- Adding a Raycast Script Command or changing Raycast settings.
- Adding a duplicate `opencode` entry to `environment.systemPackages`.
- Moving packages other than `opencode` to `nixpkgs-unstable`.
- Supporting the Nix desktop package on Intel Darwin.
- Adding secrets to Nix expressions, the Nix store, launchd, or app metadata.
