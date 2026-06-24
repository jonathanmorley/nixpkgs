{
  fetchurl,
  lib,
  runtimeShell,
  stdenvNoCC,
}: let
  system = stdenvNoCC.hostPlatform.system;
  assets = {
    aarch64-darwin = "trajectory-darwin-arm64";
    x86_64-darwin = "trajectory-darwin-amd64";
    x86_64-linux = "trajectory-linux-amd64";
    aarch64-linux = "trajectory-linux-arm64";
  };
  hashes = {
    aarch64-darwin = "sha256-uvn8YIGdglolPuE/wRWot/Xnue2V0t8SD5xqVoqm6Uo=";
    x86_64-darwin = "sha256-A8B4i80uxN0+H+JOV34bN0cki3COeAzNXCuTY6ydayA=";
    x86_64-linux = "sha256-RqpI4qJc1fdb+G8aYyZCF96Q7pzNUADZmA76B8koOb0=";
    aarch64-linux = "sha256-pAcEJBSj3JXPu6wj1RQ9MXp65jwpPfDyBhbRYFSm/M8=";
  };
in
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "trajectory";
    version = "0.5.16";

    asset = assets.${system} or (throw "Unsupported Trajectory platform: ${system}");

    src = fetchurl {
      url = "https://github.com/datadog-labs/trajectory/releases/download/v${version}/${asset}";
      hash = hashes.${system};
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/libexec/trajectory"

      mkdir -p "$out/bin"
      cat > "$out/bin/trajectory" <<EOF
      #!${runtimeShell}
      set -euo pipefail

      if [ "\''${1:-}" = "update" ]; then
        echo "trajectory is managed by Nix; update pkgs/trajectory/default.nix instead." >&2
        exit 1
      fi

      export TRAJECTORY_AUTO_UPDATE="\''${TRAJECTORY_AUTO_UPDATE:-0}"
      exec "$out/libexec/trajectory" "\$@"
      EOF
      chmod +x "$out/bin/trajectory"

      runHook postInstall
    '';

    meta = {
      description = "Observe AI coding agents like production systems";
      homepage = "https://github.com/datadog-labs/trajectory";
      license = lib.licenses.asl20;
      mainProgram = "trajectory";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  })
