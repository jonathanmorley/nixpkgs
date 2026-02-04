# See https://nix-community.github.io/home-manager/options.xhtml
{
  pkgs,
  lib,
  config,
  specialArgs,
  ...
}: let
  personal = builtins.elem "personal" specialArgs.profiles;
  cvent = builtins.elem "cvent" specialArgs.profiles;
in {
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
  programs.rbw = {
    enable = true;
    settings = {
      email = "jmorley@cvent.com";
      pinentry = pkgs.pinentry-tty;
    };
  };
  programs.ripgrep.enable = true;
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
      identityFile = lib.mkIf (builtins.hasAttr "ssh" specialArgs.sshKeys) (builtins.toFile "ssh.pub" specialArgs.sshKeys."ssh");
      extraOptions.IdentityAgent = lib.mkIf pkgs.stdenv.isDarwin (
        if cvent
        then "\"${config.home.homeDirectory}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock\""
        else "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
      );
    };
    matchBlocks."!stash.cvent.net *.cvent.*" = lib.mkIf cvent {
      user = "jmorley";
      extraOptions.PreferredAuthentications = "password";
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
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      export PATH="''${PATH}:''${HOME}/.cargo/bin"
       # We want shims so that commands executed without a shell still use mise
      eval "$(${lib.getExe pkgs.mise} activate --shims zsh)"
      ${lib.optionalString cvent ''
        # Fetch GitHub token from Bitwarden via rbw
        export GITHUB_PAT="$(${config.programs.rbw.package}/bin/rbw get 'GitHub Token')"

        # Fetch Jira token from Bitwarden via rbw
        export JIRA_PAT="$(${config.programs.rbw.package}/bin/rbw get 'Jira Token')"

        # Fetch Confluence token from Bitwarden via rbw
        export CONFLUENCE_PAT="$(${config.programs.rbw.package}/bin/rbw get 'Confluence Token')"
      ''}
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
      amazon-ecr-credential-helper
      coreutils
      dasel
      disk-inventory-x
      dogdns
      dust
      duf
      findutils
      gnugrep
      gnutar
      gzip
      hex
      ipcalc
      mitmproxy
      mtr
      nil
      obsidian
      oktaws
      ollama
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
