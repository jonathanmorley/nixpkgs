{
  stdenvNoCC,
  fetchurl,
  lib,
}: let
  dmg = fetchurl {
    url = "https://deploy.totallyacdn.com/desktop-apps/2.23.11/Windscribe_2.23.11_universal.dmg";
    sha256 = "393a9c0650a66b4fea87716f9a47369a20cb70681cb2cc6ee0cef157f693d116";
  };
in
  stdenvNoCC.mkDerivation (_finalAttrs: rec {
    pname = "windscribe";
    version = "2.23.11";

    src = dmg;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm444 "$src" "$out/Windscribe_${version}_universal.dmg"
      runHook postInstall
    '';

    meta = {
      description = "Windscribe VPN installer disk image (dmg)";
      homepage = "https://windscribe.com/";
      license = lib.licenses.unfreeRedistributable;
      platforms = lib.platforms.darwin;
    };
  })
