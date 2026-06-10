# See https://nix-community.github.io/home-manager/options.xhtml
{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.awscli.enable = true;
  programs.bat.enable = true;
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
  };
  targets.darwin = lib.mkIf pkgs.stdenv.isDarwin {
    # Home Manager 26.05 defaults to copyApps, which needs macOS App
    # Management permission to mutate copied .app bundles. That permission is
    # flaky for Warp, so keep the older symlink-based behavior.
    copyApps.enable = false;
    linkApps.enable = true;
  };
  home.activation.migrateCopiedDarwinApps = lib.mkIf (pkgs.stdenv.isDarwin && config.targets.darwin.linkApps.enable) (
    lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      target="$HOME/${config.targets.darwin.linkApps.directory}"

      if [[ -d "$target" && ! -L "$target" ]]; then
        backup="$target.copyApps-backup"
        if [[ -e "$backup" ]]; then
          backup="$backup.$(${pkgs.coreutils}/bin/date +%Y%m%d%H%M%S)"
        fi

        run mv "$target" "$backup"
      fi
    ''
  );
  programs.direnv.enable = true;
  programs.eza.enable = true;
  programs.fd.enable = true;
  programs.java.enable = true;
  programs.jq.enable = true;
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.settings = {
      trusted_config_paths = [
        "~/Developer/cvent-internal"
        "~/.codex/worktrees"
      ];
    };
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
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      export PATH="''${PATH}:''${HOME}/.cargo/bin"

      eval "$(fnox activate zsh)"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
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
      disk-inventory-x
      doggo
      dust
      duf
      findutils
      fnox
      gnugrep
      gnutar
      gzip
      hex
      ipcalc
      mitmproxy
      mtr
      obsidian
      oktaws
      openssl
      openconnect
      postgresql
      pkg-config-unwrapped
      raycast
      slack
      tmux
      tree
      unixtools.watch
      vscode
    ]
    ++ [
      # Language Servers
      jdt-language-server
      nixd
      rust-analyzer
      typescript-language-server
    ];

  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
    nix-clean = "sudo nix-collect-garbage --delete-older-than 30d";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
      HashKnownHosts = true;
    };
  };

  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.strings.makeSearchPathOutput "dev" "lib/pkgconfig" (with pkgs; [
      # For compiling ruby
      libyaml
      openssl
      # For building the `canvas` npm package
      pixman
      cairo
      libpng
      pango
      glib
      harfbuzz
      freetype
    ]);
    # Adapted from batman --export-env
    MANPAGER = "env BATMAN_IS_BEING_MANPAGER=yes ${pkgs.bat-extras.batman}/bin/batman";
    MANROFFOPT = "-c";
  };
}
