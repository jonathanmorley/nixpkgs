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

    interceptShared = fetchurl {
      url = "https://raw.githubusercontent.com/datadog-labs/trajectory/v${version}/intercepts/intercept-shared.mjs";
      hash = "sha256-jWZPXBqisMxKptqInz9TRgta3C25ua754oG5YiF2Z+w=";
    };

    bunLlmIntercept = fetchurl {
      url = "https://raw.githubusercontent.com/datadog-labs/trajectory/v${version}/intercepts/bun-llm-intercept.mjs";
      hash = "sha256-gt63ohuoZfeccTuaM7CmQFNzxsCKoB/76hSxenGEo8E=";
    };

    nodeLlmSpy = fetchurl {
      url = "https://raw.githubusercontent.com/datadog-labs/trajectory/v${version}/intercepts/node-llm-spy.cjs";
      hash = "sha256-LqEK5lQ+ZI5rNNUzi81xduA9bW7N5wC7EHE5xs1SLkc=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/libexec/trajectory"
      install -Dm644 "$interceptShared" "$out/share/trajectory/intercepts/intercept-shared.mjs"
      install -Dm644 "$bunLlmIntercept" "$out/share/trajectory/intercepts/bun-llm-intercept.mjs"
      install -Dm644 "$nodeLlmSpy" "$out/share/trajectory/intercepts/node-llm-spy.cjs"

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
