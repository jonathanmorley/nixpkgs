{
  pkgs,
  lib,
  specialArgs,
  ...
}: let
  personal = builtins.elem "personal" specialArgs.profiles;
  cvent = builtins.elem "cvent" specialArgs.profiles;
  gitignores = builtins.fetchGit {
    url = "https://github.com/github/gitignore";
    rev = "8779ee73af62c669e7ca371aaab8399d87127693";
  };
in {
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "Jonathan Morley";
    userEmail =
      if cvent
      then "jmorley@cvent.com"
      else "morley.jonathan@gmail.com";
    signing = {
      format = "ssh";
      key = specialArgs.sshKeys."github.com";
      signByDefault = true;
    };
    ignores = lib.splitString "\n" (builtins.readFile "${gitignores}/Global/${
      if pkgs.stdenv.isDarwin
      then "macOS"
      else "Linux"
    }.gitignore");
    extraConfig = {
      # Some from https://blog.gitbutler.com/how-git-core-devs-configure-git/
      branch.sort = "-committerdate";
      column.ui = "auto";
      commit.verbose = true;
      credential."https://github.com".helper = [
        ""
        "!${pkgs.writeShellScript "credential-helper" ''
          echo username=jonathanmorley
          echo password=$(${lib.getExe pkgs.gh} auth token --user jonathanmorley)
        ''}"
      ];
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = toString (pkgs.writeText "allowed_signers" (
          lib.strings.concatStringsSep "\n" (
            [
              "morley.jonathan@gmail.com namespaces='git' ${specialArgs.sshKeys."github.com"}"
            ]
            ++ lib.optional cvent "jmorley@cvent.com namespaces='git' ${specialArgs.sshKeys.cvent}"
          )
        ));
        ssh.program = lib.mkIf (personal && pkgs.stdenv.isDarwin) "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };
      help.autocorrect = "prompt";
      http.postBuffer = 2097152000;
      https.postBuffer = 2097152000;
      init.defaultBranch = "main";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      rebase = {
        autoSquash = true;
        updateRefs = true;
      };
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      tag.sort = "version:refname";
    };
    includes =
      lib.mkIf cvent
      (builtins.concatMap (org: [
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
                "!${pkgs.writeShellScript "credential-helper" ''
                  echo username=JMorley_cvent
                  echo password=$(${lib.getExe pkgs.gh} auth token --user JMorley_cvent)
                ''}"
              ];
              user.signingKey = specialArgs.sshKeys.cvent;
            };
          }
        ]) [
          "cvent-internal"
          "cvent-archive-internal"
          "cvent-incubator-internal"
          "cvent-forks-internal"
          "cvent-test-internal"
          "enabling-services"
          "icapture-internal"
          "jifflenow-internal"
          "SHOFLO-internal"
          "socialtables-internal"
          "weddingspot-internal"
        ]
        ++ [
          # Stash
          {
            condition = "hasconfig:remote.*.url:ssh://git@*.cvent.*/**";
            contents = {
              core.sshCommand = "ssh -i ${builtins.toFile "cvent.pub" specialArgs.sshKeys.cvent}";
              user.signingKey = specialArgs.sshKeys.cvent;
            };
          }
        ]);
  };
  programs.ssh = {
    matchBlocks."github.com" = {
      identitiesOnly = true;
      identityFile = builtins.toFile "github.com.pub" specialArgs.sshKeys."github.com";
    };
    matchBlocks."cvent.github.com" = lib.mkIf cvent {
      identitiesOnly = true;
      identityFile = builtins.toFile "cvent.pub" specialArgs.sshKeys.cvent;
      hostname = "github.com";
    };
  };
  programs.zsh.oh-my-zsh.plugins = [ "gh" "git" ];

  home.packages = with pkgs; [ gh gitify git-filter-repo ];
  home.shellAliases.gls = ''${pkgs.git}/bin/git log --pretty='format:' --name-only | ${pkgs.gnugrep}/bin/grep -oP "^''$(${pkgs.git}/bin/git rev-parse --show-prefix)\K.*" | cut -d/ -f1 | sort -u'';
}
