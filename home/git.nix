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
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing = {
      format = "ssh";
      key = specialArgs.sshKeys."github.com";
      signByDefault = true;
    };
    ignores =
      lib.splitString "\n" (builtins.readFile "${gitignores}/Global/${
        if pkgs.stdenv.isDarwin
        then "macOS"
        else "Linux"
      }.gitignore")
      ++ [
        ".claude/settings.local.json"
      ];
    settings = {
      user = {
        name = "Jonathan Morley";
        email =
          if cvent
          then "jmorley@cvent.com"
          else "morley.jonathan@gmail.com";
      };
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
          "*-internal"
          "enabling-services"
          "JMorley_cvent"
          "jmorley_cvent"
        ]
        ++ [
          # Stash
          {
            condition = "hasconfig:remote.*.url:ssh://git@*.cvent.*/**";
            contents.user.signingKey = specialArgs.sshKeys.cvent;
          }
        ]);
  };
  programs.ssh = {
    matchBlocks."stash.cvent.net" = lib.mkIf cvent {
      identitiesOnly = true;
      identityFile = builtins.toFile "cvent.pub" specialArgs.sshKeys.cvent;
    };
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
  programs.zsh.oh-my-zsh.plugins = ["gh" "git"];

  home.packages = with pkgs; [
    gig
    gh
    gitify
    git-filter-repo
  ];
  home.shellAliases.gls = ''${pkgs.git}/bin/git log --pretty='format:' --name-only | ${pkgs.gnugrep}/bin/grep -oP "^''$(${pkgs.git}/bin/git rev-parse --show-prefix)\K.*" | cut -d/ -f1 | sort -u'';
  home.shellAliases.gcl = ''
    f() {
      local url="$1"
      local org repo target
      # Handle SSH URLs: git@github.com:org/repo.git
      if [[ "$url" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        org="''${match[1]}"
        repo="''${match[2]%.git}"
      # Handle HTTPS URLs: https://github.com/org/repo.git
      elif [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
        org="''${match[1]}"
        repo="''${match[2]%.git}"
      else
        echo "Error: Could not parse GitHub URL: $url" >&2
        return 1
      fi
      target="$HOME/Developer/$org/$repo"
      mkdir -p "$HOME/Developer/$org"
      ${pkgs.git}/bin/git clone "$url" "$target" && cd "$target"
    }; f'';
}
