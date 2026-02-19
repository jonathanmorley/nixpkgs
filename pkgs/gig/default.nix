{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "gig";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "mdaverde";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-XO/TvRxgfOEVJdL+XpwtmoNWFwTZordiiNNoNfdYljg=";
  };

  cargoPatches = [./native-certs.patch];
  cargoHash = "sha256-yyOosNP2sxYy6wEt+GlwL/tuMo7nYWeFHkVbXoIWorM=";

  meta = {
    description = "Simple cli to create a .gitignore based off Github's gitignore repo";
    mainProgram = "gig";
    homepage = "https://github.com/mdaverde/gig";
    license = lib.licenses.mit;
  };
})
