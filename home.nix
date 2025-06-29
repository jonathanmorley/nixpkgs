# See https://nix-community.github.io/home-manager/options.xhtml
{
  config,
  pkgs,
  lib,
  profiles,
  username,
  sshKeys,
  ...
}: let
  personal = builtins.elem "personal" profiles;
  cvent = builtins.elem "cvent" profiles;

  gitignores = builtins.fetchGit {
    url = "https://github.com/github/gitignore";
    rev = "8779ee73af62c669e7ca371aaab8399d87127693";
  };
in {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = username;
  home.homeDirectory = lib.mkForce (
    if pkgs.stdenv.isDarwin
    then "/Users/${username}"
    else "/home/${username}"
  );

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  nix.settings = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://jonathanmorley.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "jonathanmorley.cachix.org-1:5P5EOY4b+AC2G1XIzjluXmoWBSK6GiMg4UHV4+gCgwI="
    ];
    extra-experimental-features = ["nix-command" "flakes"];
  };

  programs.awscli.enable = true;
  programs.bat = {
    enable = true;
  };
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
  };
  programs.direnv.enable = true;
  programs.eza.enable = true;
  programs.fd.enable = true;
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
      key = sshKeys."github.com";
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
              "morley.jonathan@gmail.com namespaces='git' ${sshKeys."github.com"}"
            ]
            ++ lib.optional cvent "jmorley@cvent.com namespaces='git' ${sshKeys.cvent}"
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
              user.signingKey = sshKeys.cvent;
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
              user.signingKey = sshKeys.cvent;
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
              core.sshCommand = "ssh -i ${builtins.toFile "cvent.pub" sshKeys.cvent}";
              user.signingKey = sshKeys.cvent;
            };
          }
        ]);
  };
  programs.java.enable = true;
  programs.jq.enable = true;
  programs.mise = {
    enable = true;
    enableZshIntegration = false;
  };
  programs.neovim = {
    defaultEditor = true;
    enable = true;
    viAlias = true;
    vimAlias = true;
  };
  programs.nix-index = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
  programs.ripgrep.enable = true;
  programs.ssh = {
    enable = true;
    hashKnownHosts = true;
    matchBlocks."*" = {
      identityFile = lib.mkIf (builtins.hasAttr "ssh" sshKeys) (builtins.toFile "ssh.pub" sshKeys."ssh");
      extraOptions.IdentityAgent = lib.mkIf pkgs.stdenv.isDarwin (
        if cvent
        then "\"${config.home.homeDirectory}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock\""
        else "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
      );
    };
    matchBlocks."*.cvent.*" = lib.mkIf cvent {
      user = "jmorley";
      extraOptions.PreferredAuthentications = "password";
    };
    matchBlocks."github.com" = {
      identitiesOnly = true;
      identityFile = builtins.toFile "github.com.pub" sshKeys."github.com";
    };
    matchBlocks."cvent.github.com" = lib.mkIf cvent {
      identitiesOnly = true;
      identityFile = builtins.toFile "cvent.pub" sshKeys.cvent;
      hostname = "github.com";
    };
  };
  programs.starship.enable = true;
  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        assume_yes = true;
        pre_sudo = true;
        cleanup = true;
        disable = [
          "bun"
          "cargo"
          "containers"
          "dotnet"
          "helm"
          "node"
          "nix"
          "pip3"
          "pnpm"
          "rustup"
          "yarn"
        ];
      };
      commands = lib.optionalAttrs pkgs.stdenv.isDarwin {
        Nix = "darwin-rebuild switch ${lib.cli.toGNUCommandLineShell {} {
          refresh = true;
          flake = "github:jonathanmorley/nixpkgs";
        }}";
      };
    };
  };
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      export PATH="''${PATH}:''${HOME}/.cargo/bin"
       # We want shims so that commands executed without a shell still use mise
      eval "$(${lib.getExe pkgs.mise} activate --shims zsh)"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "gh"
        "git"
        "rust"
        "vscode"
      ];
    };
  };

  home.packages = with pkgs;
  # Tools
    [
      amazon-ecr-credential-helper
      coreutils
      dasel
      disk-inventory-x
      docker-buildx
      docker-client
      (writeShellScriptBin "docker-credential-gh" ''
        echo "{\"Username\":\"JMorley_cvent\",\"Secret\":\"$(${lib.getExe pkgs.gh} auth token --user JMorley_cvent)\"}"
      '')
      dogdns
      du-dust
      duf
      gh
      gitify
      git-filter-repo
      gnugrep
      ipcalc
      mtr
      nil
      oktaws
      openssl
      pkg-config-unwrapped
      raycast
      slack
      tree
      unixtools.watch
      vscode
    ]
    # Languages / Package Managers
    ++ [
      nodejs
      python3
      rustup
    ]
    ++ lib.optional pkgs.stdenv.isDarwin colima
    ++ lib.optional personal tailscale
    ++ lib.optional cvent zoom-us;

  home.activation = {
    # Copy the docker config so that docker login can write to it.
    # We can't use `mkOutOfStoreSymlink` because it may contain secrets we don't want to accidentally commit.
    writeDockerConfig = let
      dockerConfig = (pkgs.formats.json {}).generate "config.json" {
        credHelpers = {
          "ghcr.io" = "gh";
        };
        # CDK has a hardcoded `docker login` that _still_ doesn't play nice with the ECR docker credential helper,
        # even when using AWS_ECR_IGNORE_CREDS_STORAGE, so we can't use it as a catch-all until that is addressed.
        # See https://github.com/aws/aws-cdk/issues/32925.
        # credsStore = "ecr-login";
        currentContext = "colima";
      };
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p ${config.home.homeDirectory}/.docker
        run cp -f ${dockerConfig} ${config.home.homeDirectory}/.docker/config.json
        run chmod a+w ${config.home.homeDirectory}/.docker/config.json
      '';
  };

  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
    dockerv = "${pkgs.docker-client}/bin/docker run ${lib.cli.toGNUCommandLineShell {} {
      interactive = true;
      tty = true;
      rm = true;
      volume = "$(pwd):$(pwd)";
      workdir = "$(pwd)";
    }}";
    gls = ''${pkgs.git}/bin/git log --pretty='format:' --name-only | ${pkgs.gnugrep}/bin/grep -oP "^''$(${pkgs.git}/bin/git rev-parse --show-prefix)\K.*" | cut -d/ -f1 | sort -u'';
    nix-clean = "sudo nix-collect-garbage --delete-older-than 30d";
  };

  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.strings.makeSearchPathOutput "dev" "lib/pkgconfig" [
      # For compiling ruby
      pkgs.libyaml
      pkgs.openssl
    ];
    # Adapted from batman --export-env
    MANPAGER = "env BATMAN_IS_BEING_MANPAGER=yes ${pkgs.bat-extras.batman}/bin/batman";
    MANROFFOPT = "-c";
    # Allow `docker login` to succeed
    AWS_ECR_IGNORE_CREDS_STORAGE = "true";
  };

  home.file."colima template" = lib.mkIf pkgs.stdenv.isDarwin {
    target = ".colima/_templates/default.yaml";
    source = (pkgs.formats.yaml {}).generate "default.yaml" {
      runtime = "docker";
      vmType = "vz";
      rosetta = true;
      network.address = true;
      mounts = [
        {
          location = "/tmp/colima";
          mountPoint = "/tmp/colima";
          writable = true;
        }
        {
          location = "/private/var/folders";
          mountPoint = "/private/var/folders";
          writable = true;
        }
        {
          location = "/Users/${username}";
          mountPoint = "/Users/${username}";
          writable = true;
        }
      ];
    };
  };
}
