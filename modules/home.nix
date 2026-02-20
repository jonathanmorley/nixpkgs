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
  programs.direnv.enable = true;
  programs.eza.enable = true;
  programs.fd.enable = true;
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
       # We want shims so that commands executed without a shell still use mise
      eval "$(${lib.getExe pkgs.mise} activate --shims zsh)"
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
      dogdns
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
      nixd
      obsidian
      oktaws
      openssl
      openconnect
      postgresql
      pkg-config-unwrapped
      raycast
      slack
      tree
      unixtools.watch
    ];

  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
    nix-clean = "sudo nix-collect-garbage --delete-older-than 30d";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
      hashKnownHosts = true;
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
