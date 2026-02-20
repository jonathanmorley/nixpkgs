{
  pkgs,
  lib,
  config,
  specialArgs,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      email = "jmorley@cvent.com";
      pinentry = pkgs.pinentry-tty;
      lock_timeout = 60 * 60 * 24; # 24 hours
    };
  };

  programs.git = {
    settings = {
      user.email = "jmorley@cvent.com";
      gpg.ssh.allowedSignersFile = lib.mkForce (toString (pkgs.writeText "allowed_signers" (
        lib.strings.concatStringsSep "\n" [
          "morley.jonathan@gmail.com namespaces='git' ${specialArgs.sshKeys."github.com"}"
          "jmorley@cvent.com namespaces='git' ${specialArgs.sshKeys.cvent}"
        ]
      )));
    };
    includes =
      builtins.concatMap (org: [
        # Internal GitHub (SSH)
        {
          condition = "hasconfig:remote.*.url:git@github.com:${org}/**";
          contents = {
            url."git@cvent.github.com".insteadOf = "git@github.com";
            user.signingKey = specialArgs.sshKeys.cvent;
          };
        }
        # Internal GitHub (HTTPS)
        {
          condition = "hasconfig:remote.*.url:https://github.com/${org}/**";
          contents = {
            credential."https://github.com".helper = [
              ""
              # This needs to be an absolute path for the credential helper to work with private homebrew taps, because it removes the PATH env var.
              "!${pkgs.writeShellScript "cvent-credential-helper" ''
                echo username=JMorley_cvent
                echo password=$(${lib.getExe pkgs.gh} auth token --user JMorley_cvent)
              ''}"
            ];
            user.signingKey = specialArgs.sshKeys.cvent;
          };
        }
      ]) [
        "*-internal"
        "enabling-services"
        "JMorley_cvent"
        "jmorley_cvent"
      ];
  };

  programs.ssh = {
    matchBlocks."cvent.github.com" = {
      identitiesOnly = true;
      identityFile = builtins.toFile "cvent.pub" specialArgs.sshKeys.cvent;
      hostname = "github.com";
    };
    matchBlocks."!stash.cvent.net *.cvent.*" = {
      user = "jmorley";
      extraOptions.PreferredAuthentications = "password";
    };
  };

  programs.zsh.initContent = ''
    # Fetch GitHub token from Bitwarden via rbw
    export GITHUB_MCP_TOKEN="$(${config.programs.rbw.package}/bin/rbw get 'GitHub Token')"

    # Fetch Jira token from Bitwarden via rbw
    export JIRA_MCP_TOKEN="$(${config.programs.rbw.package}/bin/rbw get 'Jira Token')"

    # Fetch Confluence token from Bitwarden via rbw
    export CONFLUENCE_MCP_TOKEN="$(${config.programs.rbw.package}/bin/rbw get 'Confluence Token')"
  '';
}
