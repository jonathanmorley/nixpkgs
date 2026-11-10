{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}: let
  system = stdenvNoCC.hostPlatform.system;
  targets = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-te/slE3wFz91HrguKVZ9c7Kf12spS5DpaFfLw8nLnC0=";
    };
  };
  target = targets.${system} or (throw "Unsupported OpenChamber Desktop platform: ${system}");
in
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "openchamber-desktop";
    version = "2.7.0";

    # TODO: bump the version by updating `version` and the `hash`es.
    # Regenerate the hashes with:
    #   nix store prefetch-file --json \
    #     "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-mac-<arch>.zip"
    # (see https://github.com/openchamber/openchamber/releases for the
    # versioned download links).
    src = fetchurl {
      url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-mac-${target.arch}.zip";
      hash = target.hash;
    };

    sourceRoot = ".";

    nativeBuildInputs = [unzip];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -r OpenChamber.app "$out/Applications/"
      runHook postInstall
    '';

    meta = {
      description = "OpenChamber Desktop — workspace for OpenCode AI agent";
      homepage = "https://openchamber.dev/";
      license = lib.licenses.mit;
      platforms = [
        "aarch64-darwin"
      ];
    };
  })
