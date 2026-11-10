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

1. Apply: `nix run nix-darwin -- switch --flake ~/.nixpkgs#my-hostname`

> Apple Silicon only — this flake no longer supports `x86_64-darwin` (`nixpkgs-unstable` is Nixpkgs 26.11, which dropped Intel macOS, and the Intel `smoke` iMac is retired).

The modular system picks up shared modules automatically — Darwin config from `modules/darwin.nix`, Home Manager from `modules/home.nix`, AI tooling, Docker, Git, and SSH provider secrets. To add host-specific overrides, use `extraDarwinModules` and `extraHomeModules`.

Available profiles:

- `"personal"` — includes non-work applications (Tailscale, Bambu Studio, etc.)

Available SSH providers:

- `"1password"` — SSH agent and Git signing via 1Password
- `"bitwarden"` — SSH agent and Git signing via Bitwarden

Available optional special arguments:

- `opencodeModel` — model name for OpenCode AI agents (default: `"opencode/big-pickle"`)

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

The shared Home Manager configuration enables Trajectory (`services.trajectory`, `modules/ai/trajectory.nix`) with `clients = ["cc"]`.
Every activation runs `trajectory setup --clients cc --non-interactive` to install or refresh the Claude Code plugin, and a launchd agent runs `trajectory serve`; `modules/ai/home.nix` adds the OpenCode plugin, MCP server and skills (`services.trajectory.opencode.enable`).

The shared Home Manager configuration installs the OpenCode v2 CLI (`opencode`, packaged in `pkgs/opencode` from the official `@opencode/cli` release tarballs since nixpkgs still tracks the v1 Go binary; bump the version there to update) and OpenChamber Desktop (`OpenChamber.app`, packaged in `pkgs/openchamber-desktop` from the official GitHub release zips at `https://github.com/openchamber/openchamber/releases`; bump the version there to update). OpenCode Desktop is intentionally not installed.

The Trajectory configuration test runs during `nix flake check` through the `checks.trajectory` derivation.

Beside an install managed outside Nix (the upstream installer or an MDM, which self-update under `~/.trajectory`), set `services.trajectory.configFile.enable = false` so Nix leaves `config.yaml` to it, `clients = []`, `serve.enable = false` and `opencode.enable = false` so nothing is registered or run twice, and `preferInstalled = true` so the `trajectory` on `PATH` runs that install's binary (`$TRAJECTORY_HOME/bin/trajectory`) when it exists and the Nix package otherwise. `checks.trajectory-launcher` tests that launcher (`pkgs/trajectory/launcher.sh`) against fake binaries.

To run the Nix package beside that install and switch between the two at run time, without a rebuild, set `services.trajectory.selector.enable = true`, a `home` of its own under the home directory (for example `~/.local/share/trajectory`) and a `server.port` other than `selector.installedPort` (default 19222):

- The launcher reads `selector.file` (default `~/.config/trajectory/active`), or `TRAJECTORY_ACTIVE` when set. `installed`, no file, or anything else (with a warning) runs the other install as `preferInstalled` does, with the caller's environment untouched.
- `nix` runs the package with `TRAJECTORY_HOME` set to `home`, `TRAJECTORY_PORT` to `server.port` and `TRAJECTORY_CAPTURE_URL` to `http://127.0.0.1:<server.port>`, whatever the caller set. Every other `TRAJECTORY_*` variable from the caller (`TRAJECTORY_BINARY`, for one) is dropped, since it may point at the other install; only the off switches `TRAJECTORY_DISABLED` and `TRAJECTORY_DISABLE_*` pass through. It refuses to run if `home` resolves, through symlinks and ignoring case (APFS is case-insensitive by default), to `~/.trajectory` or inside it, and if `HOME` is unset, since it can't check that then.
- In `nix` mode it also sets `TRAJECTORY_DISABLE_RUNTIME_ASSET_RECONCILE=1`, `TRAJECTORY_DISABLE_STARTUP_RECONCILE=1` and `TRAJECTORY_DISABLE_CLIENT_WATCHERS=1`. Without them a `trajectory serve` or `trajectory mcp` started in a second home rewrites the client integrations the two installs share (Claude Code's installed plugin, OpenCode's config and plugin pointer) to point at itself. These variables are undocumented upstream: `checks.trajectory-reconcile-variables` fails `nix flake check` when the packaged binary stops containing any of them, so a Trajectory bump rechecks them.
- For the same reason `nix` mode refuses `trajectory setup`, `uninstrument` and `uninstall`, unless `TRAJECTORY_SELECTOR_ALLOW_SETUP=1`.
- `trajectory-select nix` or `trajectory-select installed` writes the file atomically; with no argument it prints the selected install, its binary, home and port, and whether its serve is listening. Running OpenCode, Claude Code and Trajectory MCP processes keep the install they started with, so restart them after switching.
- Serve starts on demand for the selected install, so the module refuses the selector with `serve.enable`, `view.enable`, `clients` or `opencode.enable`. Wire clients by pointing their configuration at the `trajectory` launcher on `PATH`, not through `trajectory setup`. Anything that runs `pkgs.trajectory` or `services.trajectory.package` directly bypasses the selector.
- `home` and `selector.file` must be normal paths under the home directory (no empty, `.` or `..` segments, no trailing `/`), and `home` must be neither `~/.trajectory` nor inside it, in any case.
- `configFile.enable` writes `config.yaml` into `home`, and `managedDefaults` writes `config.defaults.yaml` there, Trajectory's managed defaults (required destinations and the other managed keys), so the Nix install can publish like the other one without syncing `org.config_source`. `auth.mode = "managed_keychain"` reads credentials only from the OS keychain accounts each destination names in `api_key_ref`. Neither file holds secrets.

Without `selector.enable` none of this applies and nothing changes.

`checks.trajectory-selector` tests the selector and `trajectory-select` (`pkgs/trajectory/select.sh`) against fake binaries; `checks.trajectory-module` evaluates the module with and without the selector, including every combination it refuses; `checks.trajectory-selector-wiring` checks that, with the selector on, the shared configuration reaches the package only through the launcher.

## VS Code

VS Code runs from the read-only Nix store, so its built-in updater can never install an update; it only keeps asking macOS to install a helper.
`modules/vscode/home.nix` therefore sets `"update.mode": "none"` in `~/Library/Application Support/Code/User/settings.json`, and VS Code updates only when the flake inputs are updated.

- Usually Home Manager activation sets the key (`pkgs/vscode-update-mode`), and the file stays a normal writable file, so settings changed in VS Code still save.
  It is edited as JSONC with `jsonc-parser`, the library VS Code uses, so comments, trailing commas and formatting are kept, and it is not rewritten when the key is already set.
  A file it cannot update (not a valid JSONC object, a symlink, unreadable, or saved by VS Code during the update) is left unchanged with a warning; activation never fails because of it.
- Activation creates the file, and the `~/Library/Application Support/Code/User/` directory, wherever this configuration is activated, including CI hosts.
- If `programs.vscode` writes `settings.json` from `userSettings`, the key is added to those settings instead, unless `programs.vscode.profiles.default.enableUpdateCheck` is set.
  If `userSettings` is a file, a Home Manager warning asks to set `enableUpdateCheck = false`.
  With `mutableUserSettings` (newer Home Manager), `settings.json` stays writable and activation sets the key as above.

The behavior tests run during `nix flake check` through the `checks.vscode-update-mode` and `checks.vscode-update-mode-hm` derivations.

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
