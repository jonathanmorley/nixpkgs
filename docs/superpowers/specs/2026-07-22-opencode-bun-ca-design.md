# OpenCode Bun CA Design

## Goal

Allow the Cvent Darwin configuration to build the pinned OpenCode package when
Netskope intercepts GitHub HTTPS traffic, without disabling TLS verification or
changing non-Cvent configurations.

## Scope

The change applies only when `profiles` contains `cvent`. It does not alter the
OpenCode source revision, dependency lockfile, package selection, proxy
configuration, macOS keychain setup, or system-wide certificate environment
variables.

## Architecture

`modules/cvent/darwin.nix` already creates `certBundle`, a `/nix/store` CA
bundle containing the Mozilla roots and the pinned Netskope root certificate.
The Cvent overlay will use `overrideAttrs` to replace the upstream OpenCode
package's fixed-output `node_modules` build phase.

The replacement preserves the upstream Bun version, source, package filters,
target CPU and OS, frozen lockfile, ignored lifecycle scripts, normalization
steps, and expected output hash. Its only behavioral difference is the
additional Bun `--cafile "${certBundle}"` argument. The explicit store path is
available in the Nix sandbox and is included in the derivation inputs.

The Cvent overlay then builds OpenCode against that replacement dependency.
Other Darwin configurations retain the OpenCode package exposed by the
OpenCode flake unchanged.

## Security

TLS peer verification remains enabled. The CA file contains the existing
Mozilla trust bundle plus the repository-pinned Netskope root; the design must
not use `NODE_TLS_REJECT_UNAUTHORIZED=0`, an insecure Bun option, or a host
certificate path unavailable to the sandbox.

## Verification

Evaluation tests must confirm that only the Cvent OpenCode package depends on
the replacement node-modules derivation and that its Bun build command contains
the store-backed `--cafile` path. Build the replacement derivation to verify
the GitHub dependency resolves through the trusted CA chain. Existing
certificate checks and non-Cvent OpenCode evaluations must continue to pass.
