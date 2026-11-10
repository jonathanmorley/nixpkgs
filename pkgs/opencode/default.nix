{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  system = stdenvNoCC.hostPlatform.system;
  targets = {
    aarch64-darwin = {
      name = "darwin-arm64";
      # npm's dist.integrity for this tarball, so it can be checked against the registry.
      hash = "sha512-KH45DjiTcsHcnVLDrAEP3kdG57olO2BndtpYi+iGc7/cBrZfUs6YYrVpsZ40lr4izTupSIxwTbvSwKHutuq5uw==";
    };
  };
  target = targets.${system} or (throw "Unsupported OpenCode CLI platform: ${system}");
in
  # Repackaging the prebuilt binary: the npm package's postinstall selects and
  # downloads the native binary, so we consume the @opencode/cli-<platform>
  # tarball that already contains it.
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "opencode";
    version = "2.2.7";

    # TODO: bump the version by updating `version` and the `hash`. The npm
    # dist tag is `@opencode/cli@latest`; the hash is npm's integrity value:
    #   npm view @opencode/cli-darwin-arm64@<version> dist.integrity
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
