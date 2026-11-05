{
  fetchzip,
  nodejs-slim,
  writeShellApplication,
}: let
  # The JSONC library VS Code uses to edit settings.json; no dependencies.
  jsonc-parser = fetchzip {
    url = "https://registry.npmjs.org/jsonc-parser/-/jsonc-parser-3.3.1.tgz";
    hash = "sha256-eZb4Epz0UsTTaSstqBl46Sy/KRyKaJ+vBUJ92/6wsZY=";
  };
in
  writeShellApplication {
    name = "vscode-update-mode";
    text = ''
      JSONC_PARSER=${jsonc-parser}/lib/umd/main.js exec ${nodejs-slim}/bin/node ${./set-update-mode.js} "$@"
    '';
  }
