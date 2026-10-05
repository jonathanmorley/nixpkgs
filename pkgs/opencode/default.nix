{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  system = stdenvNoCC.hostPlatform.system;
  targets = {
    aarch64-darwin = {
      name = "darwin-arm64";
      hash = "sha256-23w/q7PSfnf1JjVa/qlObhhtN2Dt54UaIa8INvl4Mj8=";
    };
  };
  target = targets.${system} or (throw "Unsupported OpenCode CLI platform: ${system}");
in
  # Repackaging the prebuilt binary: the npm package's postinstall selects and
  # downloads the native binary, so we consume the @opencode/cli-<platform>
  # tarball that already contains it.
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "opencode";
    version = "2.0.23";

    # TODO: bump the version by updating `version` and the `hash`. The npm
    # dist tag is `@opencode/cli@latest`; regenerate the hash with:
    #   nix store prefetch-file --json \
    #     "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-<version>.tgz"
    src = fetchurl {
      url = "https://registry.npmjs.org/@opencode/cli-${target.name}/-/cli-${target.name}-${version}.tgz";
      inherit (target) hash;
    };

    sourceRoot = ".";

    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 package/bin/opencode "$out/bin/opencode"
      runHook postInstall
    '';

    meta = {
      description = "OpenCode CLI — AI coding agent";
      homepage = "https://opencode.ai/v2/";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = [
        "aarch64-darwin"
      ];
    };
  })
