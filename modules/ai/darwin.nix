{
  config,
  lib,
  pkgs,
  ...
}: let
  aiToolPath = "/etc/profiles/per-user/${config.system.primaryUser}/bin:${config.homebrew.prefix}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  trajectorySetupAi = pkgs.writeShellScriptBin "trajectory-setup-ai" ''
    set -euo pipefail

    export PATH="${aiToolPath}:''${PATH:-}"

    ${pkgs.trajectory}/bin/trajectory setup --clients cc --non-interactive
    ${pkgs.trajectory}/bin/trajectory setup --clients codex --non-interactive
  '';

  opencodeDesktopOverlay = final: prev:
    lib.optionalAttrs prev.stdenv.hostPlatform.isAarch64 {
      opencode-desktop = prev.opencode-desktop.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            app="$out/Applications/OpenCode.app/Contents/MacOS/OpenCode"
            original="$out/Applications/OpenCode.app/Contents/MacOS/.OpenCode-unwrapped"

            mv "$app" "$original"

            makeBinaryWrapper ${lib.getExe final.fnox} "$app" \
              --inherit-argv0 \
              --add-flags "exec" \
              --add-flags "--" \
              --add-flags "$original"
          '';
      });
    };
in {
  nixpkgs.overlays = [opencodeDesktopOverlay];

  environment.systemPackages =
    [
      pkgs.mempalace
      pkgs.trajectory
      trajectorySetupAi
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isAarch64 pkgs.opencode-desktop;

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    brews = [
      # ollama's launchd service integration is only available via Homebrew on macOS.
      "ollama"
    ];
    casks =
      [
        # Codex Desktop is distributed as a Homebrew cask.
        "codex-app"
        # GitHub Copilot desktop app is distributed as Homebrew casks.
        "github-copilot-app"
      ]
      ++ lib.optional (!pkgs.stdenv.hostPlatform.isAarch64) "opencode-desktop";
  };
}
