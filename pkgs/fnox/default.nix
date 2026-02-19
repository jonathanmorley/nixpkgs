{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "fnox";
  version = "1.12.1";

  src = fetchFromGitHub {
    owner = "jdx";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-GSkixhutsdumzm1Vo4Iz99gZbXufgWyvS6WI4RnpsGU=";
  };

  cargoHash = "sha256-NfVUJ09YLpOgjVi8Ie0hZGdZmETa3GfvISM89eRSqFA=";

  doCheck = false;

  meta = {
    description = "encrypted/remote secret manager";
    mainProgram = "fnox";
    homepage = "https://github.com/jdx/fnox";
    license = lib.licenses.mit;
  };
})
