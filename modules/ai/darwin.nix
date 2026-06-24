{
  config,
  pkgs,
  ...
}: let
  lapdogWrapperPath = "/etc/profiles/per-user/${config.system.primaryUser}/bin:${config.homebrew.prefix}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  mkLapdogWrapper = name: command:
    pkgs.writeShellScriptBin name ''
      export PATH="${lapdogWrapperPath}:''${PATH:-}"
      exec "${config.homebrew.prefix}/bin/lapdog" ${command} "$@"
    '';
  claudeLapdog = mkLapdogWrapper "claude-lapdog" "claude";
  codexLapdog = mkLapdogWrapper "codex-lapdog" "codex";
in {
  environment.systemPackages = [
    claudeLapdog
    codexLapdog
  ];

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    taps = [
      {
        name = "datadog/lapdog";
        # Homebrew 6 requires explicitly trusting non-official taps before
        # loading their formulae during `brew bundle`.
        trusted = true;
      }
    ];
    brews = [
      # Datadog distributes Lapdog from its own Homebrew tap.
      "lapdog"
      # Lapdog's generated entry points use this Homebrew Python in their shebangs.
      "python@3.13"
    ];
    casks = [
      # Codex Desktop is distributed as a Homebrew cask.
      "codex-app"
    ];
  };

  launchd.user.envVariables.CLAUDE_CODE_LOCAL_BINARY = "${claudeLapdog}/bin/claude-lapdog";
}
