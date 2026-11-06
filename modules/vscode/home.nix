# VS Code runs from the read-only Nix store, so its own updater can never
# install an update and keeps asking macOS to install a helper. Turn it off;
# VS Code is updated with the flake inputs instead.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.vscode;
  profile = cfg.profiles.default or {};
  userSettings = profile.userSettings or {};
  # A file (path or string) rather than settings; programs.vscode links it as is.
  settingsFile = !lib.isAttrs userSettings;
  enableUpdateCheck = profile.enableUpdateCheck or null;
  # Where programs.vscode writes the default profile's settings.json. It uses
  # VS Code's "Code" directory whatever cfg.package is (forks have their own
  # modules); checks.vscode-update-mode-hm fails if that changes.
  settingsPath = "${
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Application Support"
    else config.xdg.configHome
  }/Code/User/settings.json";
  # programs.vscode's own settings, as it merges them (mkVscodeModule.nix).
  hmSettings =
    if settingsFile
    then null
    else
      userSettings
      // lib.optionalAttrs (enableUpdateCheck == false) {"update.mode" = "none";}
      // lib.optionalAttrs ((profile.enableExtensionUpdateCheck or null) == false) {
        "extensions.autoCheckUpdates" = false;
      };
  # programs.vscode makes settings.json a read-only store symlink when it has
  # settings to write, unless mutableUserSettings (newer Home Manager) keeps
  # it a writable file.
  managed =
    cfg.enable
    && !(profile.mutableUserSettings or false)
    && (settingsFile || hmSettings != {});
in {
  # Managed: add the key to what programs.vscode writes, unless the user chose
  # enableUpdateCheck. Setting profiles.default.enableUpdateCheck here instead
  # would recurse (the condition reads profiles), and would create a default
  # profile, which makes programs.vscode manage the extensions directory.
  home.file = lib.mkIf (managed && !settingsFile && enableUpdateCheck == null) {
    ${settingsPath}.source = lib.mkForce ((pkgs.formats.json {}).generate "vscode-user-settings" (hmSettings // {"update.mode" = "none";}));
  };
  warnings = lib.optional (managed && settingsFile && enableUpdateCheck == null) ''
    programs.vscode.userSettings is a file, so VS Code's own updater stays on.
    Set programs.vscode.profiles.default.enableUpdateCheck = false, or add
    "update.mode": "none" to that file.
  '';

  # Not managed: keep settings.json a writable file so settings changed in
  # VS Code still save, and set the key in place.
  home.activation.vscodeUpdateMode = lib.mkIf (!managed) (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.callPackage ../../pkgs/vscode-update-mode {}}/bin/vscode-update-mode ${lib.escapeShellArg settingsPath} \
        || warnEcho "vscode-update-mode failed; VS Code's own updater may still run."
    ''
  );
}
