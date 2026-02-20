{config, ...}: {
  homebrew.casks = [
    # https://github.com/NixOS/nixpkgs/issues/254944
    "1password"
    # The GUI is not available in nixpkgs
    "tailscale-app"
    "balenaetcher"
    # Not available in nixpkgs
    "chrome-remote-desktop-host"
  ];

  home-manager.users.${config.system.primaryUser} = {
    programs.git.settings.gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    programs.ssh.matchBlocks."*".extraOptions.IdentityAgent = "\"/Users/${config.system.primaryUser}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  };
}
