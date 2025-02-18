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
  home.stateVersion = "24.11";

  programs.awscli.enable = true;
  programs.bat.enable = true;
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
    signing.key = sshKeys."github.com";
    signing.signByDefault = true;
    ignores = lib.splitString "\n" (builtins.readFile "${gitignores}/Global/${
      if pkgs.stdenv.isDarwin
      then "macOS"
      else "Linux"
    }.gitignore");
    extraConfig = {
      credential = {
        "https://github.com" = {
          helper = ["" "!${pkgs.writeShellScript "credential-helper" "printf \"username=jonathanmorley\\npassword=$(gh auth token --user jonathanmorley)\\n\""}"];
        };
      };
      core.sshCommand = "ssh -i ${builtins.toFile "github.com.pub" sshKeys."github.com"}";
      fetch.prune = true;
      rebase.autosquash = true;
      pull.rebase = true;
      push.autoSetupRemote = true;
      push.default = "current";
      init.defaultBranch = "main";
      gpg.format = "ssh";
      gpg.ssh.program = lib.mkIf pkgs.stdenv.isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      http.postBuffer = 2097152000;
      https.postBuffer = 2097152000;
    };
    includes =
      lib.mkIf cvent
      (builtins.concatMap (org: [
          # Internal GitHub (SSH)
          {
            condition = "hasconfig:remote.*.url:git@github.com:${org}-internal/**";
            contents = {
              core.sshCommand = "ssh -i ${builtins.toFile "cvent.pub" sshKeys.cvent}";
              user.signingKey = sshKeys.cvent;
            };
          }
          # Internal GitHub (HTTPS)
          {
            condition = "hasconfig:remote.*.url:https://github.com/${org}-internal/**";
            contents = {
              credential = {
                "https://github.com" = {
                  helper = ["" "!${pkgs.writeShellScript "credential-helper" "printf \"username=JMorley_cvent\\npassword=$(gh auth token --user JMorley_cvent)\\n\""}"];
                };
              };
              user.signingKey = sshKeys.cvent;
            };
          }
        ]) ["cvent" "cvent-archive" "cvent-incubator" "cvent-forks" "cvent-test" "icapture" "jifflenow" "SHOFLO" "socialtables" "weddingspot"]
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
      identitiesOnly = true;
      extraOptions.IdentityAgent = lib.mkIf pkgs.stdenv.isDarwin "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
    };
    matchBlocks."*.cvent.*" = lib.mkIf cvent {
      user = "jmorley";
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
    initExtra = ''
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
      coreutils
      dasel
      docker-client
      docker-buildx
      dogdns
      du-dust
      duf
      gnugrep
      gitify
      git-filter-repo
      ipcalc
      mtr
      oktaws
      openssl
      tree
      unixtools.watch
    ]
    # Languages / Package Managers
    ++ [
      nodejs
      nodePackages.pnpm
      python3
      rustup
    ]
    # Libraries
    ++ [
      gettext # For compiling Python
      gnupg # For fetching Java
      groff # Needed by awscli
      pkg-config-unwrapped
    ]
    ++ lib.optional (! pkgs.stdenv.isDarwin) gh
    ++ lib.optional pkgs.stdenv.isDarwin colima
    ++ lib.optional personal tailscale
    ++ lib.optional cvent zoom-us;

  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
    dockerv = "${pkgs.docker-client}/bin/docker run ${lib.cli.toGNUCommandLineShell {} {
      interactive = true;
      tty = true;
      rm = true;
    }} --volume $(pwd):$(pwd) --workdir $(pwd)";
    gls = ''${pkgs.git}/bin/git log --pretty='format:' --name-only | ${pkgs.gnugrep}/bin/grep -oP "^''$(${pkgs.git}/bin/git rev-parse --show-prefix)\K.*" | cut -d/ -f1 | sort -u'';
    nix-clean = "sudo nix-collect-garbage --delete-older-than 30d";
  };

  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.strings.makeSearchPathOutput "dev" "lib/pkgconfig" [
      # For compiling ruby
      pkgs.libyaml
      pkgs.openssl
    ];
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
