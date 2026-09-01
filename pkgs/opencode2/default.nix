{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  system = stdenvNoCC.hostPlatform.system;
  targets = {
    aarch64-darwin = {
      name = "darwin-arm64";
      hash = "sha256-jb6/b3bCyFFXBPByPAIid+vNE4sXWXRKXlsFXCzkG1w=";
    };
    x86_64-darwin = {
      name = "darwin-x64";
      hash = "sha256-EhbX5B/KbN+F+B4EkVCUOiiTNlpOfAukk7KjVGdTLmc=";
    };
  };
  target = targets.${system} or (throw "Unsupported OpenCode 2 CLI platform: ${system}");
in
  # Repackaging the prebuilt binary: the npm package's postinstall selects and
  # downloads the native binary, so we consume the @opencode-ai/cli-<platform>
  # tarball that already contains it.
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "opencode2";
    version = "0.0.0-beta-18743";

    # TODO: bump the beta by updating `version` and the two `hash`es. The npm
    # dist tag is `@opencode-ai/cli@beta`; regenerate hashes with:
    #   nix-prefetch-url --type sha256 \
    #     "https://registry.npmjs.org/@opencode-ai/cli-darwin-<arm64|x64>/-/cli-darwin-<arm64|x64>-<version>.tgz"
    src = fetchurl {
      url = "https://registry.npmjs.org/@opencode-ai/cli-${target.name}/-/cli-${target.name}-${version}.tgz";
      inherit (target) hash;
    };

    sourceRoot = ".";

    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 package/bin/opencode2 "$out/bin/opencode2"
      runHook postInstall
    '';

    meta = {
      description = "OpenCode 2 (beta) CLI — AI coding agent, runs alongside the opencode v1 CLI";
      homepage = "https://opencode.ai/v2/";
      license = lib.licenses.mit;
      mainProgram = "opencode2";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
  })
