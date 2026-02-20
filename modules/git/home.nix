{
  pkgs,
  lib,
  specialArgs,
  ...
}: let
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
        email = lib.mkDefault "morley.jonathan@gmail.com";
      };
      # Some from https://blog.gitbutler.com/how-git-core-devs-configure-git/
      branch.sort = "-committerdate";
      column.ui = "auto";
      commit.verbose = true;
      credential."https://github.com".helper = [
        ""
        "!${pkgs.writeShellScript "github-credential-helper" ''
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
        ssh.allowedSignersFile = lib.mkDefault (toString (
          pkgs.writeText "allowed_signers"
          "morley.jonathan@gmail.com namespaces='git' ${specialArgs.sshKeys."github.com"}"
        ));
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
  };
  programs.ssh.matchBlocks."github.com" = {
    identitiesOnly = true;
    identityFile = builtins.toFile "github.com.pub" specialArgs.sshKeys."github.com";
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
