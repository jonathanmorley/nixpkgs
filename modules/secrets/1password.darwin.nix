{
  config,
  lib,
  ...
}: {
  programs._1password-gui.enable = true;

  home-manager.users.${config.system.primaryUser} = lib.mkIf (config.jm.sshProvider == "1password") {
    # SSH Authentication
    programs.ssh.settings."*".IdentityAgent = "\"/Users/${config.system.primaryUser}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
    # Git Commit Signing
    programs.git.settings.gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  };
}
