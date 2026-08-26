{
  fetchFromGitHub,
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
    aarch64-darwin = "sha256-wcXzg+C1w/5NMIhW4xriYu580gYvmDEqINcsoZHYR3w=";
    x86_64-darwin = "sha256-aBNCrqpLvr/m4whi3IB8Nuqpq5Cep5ulaN8rZyXRM68=";
    x86_64-linux = "sha256-kCo3S7WHg3748Oq3JPUA5fjbID86aJDuyX9ZnxraRf0=";
    aarch64-linux = "sha256-yGyhtW/g6WRIQBKckMlr6QAEStNrUD7NZrNloUJRXvg=";
  };
in
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "trajectory";
    version = "0.5.38";

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

    pluginSource = fetchFromGitHub {
      owner = "datadog-labs";
      repo = "trajectory";
      rev = "v${version}";
      hash = "sha256-rKox+GSpAR067LjG2ifnt1QYWy8jnlOkLn5pH+Ya/70=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      # Complete .trajectory/ directory layout
      install -Dm755 "$src" "$out/.trajectory/bin/trajectory"
      install -Dm644 "$interceptShared" "$out/.trajectory/intercepts/intercept-shared.mjs"
      install -Dm644 "$bunLlmIntercept" "$out/.trajectory/intercepts/bun-llm-intercept.mjs"
      install -Dm644 "$nodeLlmSpy" "$out/.trajectory/intercepts/node-llm-spy.cjs"

      cat > "$out/.trajectory/selfupdate.conf" <<EOF
      TRAJECTORY_INSTALL_OWNER=nix
      TRAJECTORY_SELF_UPDATE=disabled
      EOF

      cat > "$out/.trajectory/config.defaults.yaml" <<EOF
      capture:
        include_headless_agents: true
      EOF

      # Client plugin sources (loaded directly by each agent's plugin runtime)
      mkdir -p "$out/.trajectory/plugin"
      cp -r ${pluginSource}/plugin/trajectory-opencode "$out/.trajectory/plugin/trajectory-opencode"
      cp -r ${pluginSource}/plugin/trajectory "$out/.trajectory/claude-marketplace"

      # Signed Nix binary for direct invocation
      install -Dm755 "$src" "$out/libexec/trajectory"

      # Wrapper: blocks self-updates, disables auto-update, delegates to signed binary
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
