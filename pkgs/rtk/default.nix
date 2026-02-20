{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "rtk";
  version = "0.20.1";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-Aasa77RQdnNJd00qAJk4GZ1nE0i/GKfntj5Gv+4Nf5U=";
  };

  cargoHash = "sha256-EFtbPQEzunZH9BJU7cC9flWp6NC49GCofMTrxve2PDE=";

  # Tests require a mutable filesystem, which is not available in the sandbox.
  doCheck = false;

  meta = {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands. Single Rust binary, zero dependencies";
    mainProgram = "rtk";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.mit;
  };
})
