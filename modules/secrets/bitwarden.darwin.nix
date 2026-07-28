{
  config,
  lib,
  pkgs,
  ...
}: let
  bitwardenSocket = "/Users/${config.system.primaryUser}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
  bitwarden-ssh-sign = pkgs.writeShellScript "bitwarden-ssh-sign" ''
    export SSH_AUTH_SOCK="${bitwardenSocket}"
    exec ${pkgs.openssh}/bin/ssh-keygen "$@"
  '';
in {
  # The firefox extension doesnt unlock with biometrics if bitwarden is installed any other way
  homebrew.masApps.bitwarden = 1352778147;

  home-manager.users.${config.system.primaryUser} = lib.mkIf (config.jm.sshProvider == "bitwarden") {
    # SSH Authentication
    programs.ssh.settings."*".IdentityAgent = "\"${bitwardenSocket}\"";
    # Git Commit Signing
    programs.git.settings.gpg.ssh.program = toString bitwarden-ssh-sign;
  };
}
