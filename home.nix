# See https://nix-community.github.io/home-manager/options.html

{ config, pkgs, lib, ... }:
{
  home.stateVersion = "22.05";

  programs.alacritty = {
    enable = true;
    settings = {
      window.dimensions = {
        lines = 50;
        columns = 200;
      };
      window.padding = {
        x = 2;
        y = 2;
      };
      window.decorations = "buttonless";
      font.normal.family = "FiraCode Nerd Font";
    };
  };
  programs.bat.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      whitelist.exact = [config.home.homeDirectory];
    };
    stdlib = ''
      use_asdf() {
        source_env "$(asdf direnv envrc "$@")"
      }
    '';
  };
  programs.exa = {
    enable = true;
    enableAliases = true;
  };
  programs.gh.enable = true;
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "Morley, Jonathan";
    userEmail = "jmorley@cvent.com";
    signing.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBkddsoU1owq/A9W4CuaUY+cYA5otZ2ejivt6CbwSyi";
    signing.signByDefault = true;
    ignores = [
      ### macOS ###
      # General
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"

      # Icon must end with two \r
      "Icon"

      # Thumbnails
      "._*"

      # Files that might appear in the root of a volume
      ".DocumentRevisions-V100"
      ".fseventsd"
      ".Spotlight-V100"
      ".TemporaryItems"
      ".Trashes"
      ".VolumeIcon.icns"
      ".com.apple.timemachine.donotpresent"

      # Directories potentially created on remote AFP share
      ".AppleDB"
      ".AppleDesktop"
      "Network Trash Folder"
      "Temporary Items"
      ".apdisk"
    ];
    extraConfig = {
      fetch.prune = true;
      rebase.autosquash = true;
      push.default = "current";
      init.defaultBranch = "main";
      gpg.format = "ssh";
      gpg."ssh".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
  };
  programs.jq.enable = true;
  programs.neovim = {
    enable = true;
    coc = {
      enable = true;
    };
    viAlias = true;
    vimAlias = true;
  };
  programs.nix-index.enable = true;
  programs.ssh = {
    enable = true;
    matchBlocks."*".extraOptions.IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  };
  programs.starship = {
    enable = true;
    settings = {
      aws.symbol = "  ";
      conda.symbol = " ";
      dart.symbol = " ";
      directory.read_only = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      hg_branch.symbol = " ";
      java.symbol = " ";
      julia.symbol = " ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      package.symbol = " ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
      scala.symbol = " ";
      shlvl.symbol = " ";
      swift.symbol = "ﯣ ";
    };
  };
  programs.topgrade = {
    enable = true;
    settings = {
      disable = ["rustup"];
    };
  };
  programs.zellij.enable = true;
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
    plugins = [
      {
        name = "djui/alias-tips";
        file = "alias-tips.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "djui";
          repo = "alias-tips";
          rev = "9dfd313544082b6d7b44298cc0bb181e7ceaa993";
          sha256 = "sha256-46oJvnIzcWsFz7K0jWOf7VeSmGZDgFmqGFQbrrM9KqA";
        };
      }
    ];
    initExtra = ''
      eval "$(${pkgs.zellij}/bin/zellij setup --generate-auto-start zsh)"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "asdf"
        "gh"
        "git"
        "ripgrep"
        "rust"
        "vscode"
      ];
    };
    sessionVariables = {
      LESSHISTFILE = "${config.xdg.stateHome}/less/history";
    };
  };

  home.packages = with pkgs; [
    fd
    ripgrep
  ];

  home.shellAliases = {
    cat = "bat";
    dockerv = "docker run --rm -it -v $(pwd):$(pwd) -w $(pwd)";
    darwin-switch = "(cd /tmp && darwin-rebuild switch --flake ~/.nixpkgs)";
  };

  home.file.".asdfrc" = {
    text = "legacy_version_file = yes";
  };

  home.file.".tool-versions" = {
    text = ''
      python 3.9.1
      poetry 1.1.13
      awscli 2.4.6
    '';
    onChange = ''
      cd ~
      . /opt/homebrew/opt/asdf/libexec/asdf.sh
      asdf install
    '';
  };

  home.file.".envrc" = {
    text = "use asdf";
  };
}
