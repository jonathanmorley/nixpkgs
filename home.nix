# See https://nix-community.github.io/home-manager/options.html

{ config, pkgs, lib, publicKey, ...  }: {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "jonathan";
  home.homeDirectory = lib.mkForce (if pkgs.stdenv.isDarwin then  "/Users/jonathan" else "/home/jonathan");

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

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
  programs.exa = {
    enable = true;
    enableAliases = true;
  };
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "Jonathan Morley";
    userEmail = "morley.jonathan@gmail.com";
    signing.key = publicKey;
    signing.signByDefault = true;

    ignores = (if pkgs.stdenv.isDarwin then [
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
    ] else [
      ### Linux ###
      "*~"

      # temporary files which can be created if a process still has a handle open of a deleted file
      ".fuse_hidden*"

      # KDE directory preferences
      ".directory"

      # Linux trash folder which might appear on any partition or disk
      ".Trash-*"

      # .nfs files are created when an open file is removed but is still being accessed
      ".nfs*"
    ]) ++ [
      # direnv integration
      ".envrc"
    ];
    extraConfig = {
      fetch.prune = true;
      rebase.autosquash = true;
      pull.rebase = true;
      push.default = "current";
      init.defaultBranch = "main";
      gpg.format = "ssh";
      gpg."ssh".program = if pkgs.stdenv.isDarwin then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" else "";
    };
    includes = [
      {
        condition = "hasconfig:remote.*.url:git@github.com:cvent*/**";
        contents = {
          user = {
            email = "jmorley@cvent.com";
          };
        };
      }
      {
        condition = "hasconfig:remote.*.url:git@github.com:SHOFLO/**";
        contents = {
          user = {
            email = "jmorley@cvent.com";
          };
        };
      }
      {
        condition = "hasconfig:remote.*.url:git@github.com:socialtables/**";
        contents = {
          user = {
            email = "jmorley@cvent.com";
          };
        };
      }
      {
        condition = "hasconfig:remote.*.url:ssh://git@*.cvent.*/**";
        contents = {
          user = {
            email = "jmorley@cvent.com";
          };
        };
      }
    ];
  };
  programs.jq.enable = true;
  programs.neovim = {
    defaultEditor = true;
    enable = true;
    coc = {
      enable = true;
      # Trigger completion on <c-space>
      # Accept suggestions with <cr>
      pluginConfig = ''
        inoremap <silent><expr> <c-space> coc#refresh()
        inoremap <silent><expr> <cr> coc#pum#visible() ? coc#_select_confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
      '';
    };
    plugins = with pkgs.vimPlugins; [
      airline
      coc-docker
      coc-eslint
      coc-git
      coc-java
      coc-jest
      coc-json
      coc-prettier
      coc-pyright
      coc-python
      coc-rust-analyzer
      coc-sh
      coc-toml
      coc-tsserver
      coc-yaml
      {
        plugin = nerdtree;
        # Start NERDTree and put the cursor back in the other window.
        # Close the tab if NERDTree is the only window remaining in it.
        config = ''
          autocmd VimEnter * NERDTree | wincmd p
          autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
        '';
      }
      nerdtree-git-plugin
      sleuth
    ];
    extraConfig = "let NERDTreeShowHidden=1";
    viAlias = true;
    vimAlias = true;
  };
  programs.nix-index.enable = true;
  programs.ssh = {
    enable = true;
    hashKnownHosts = true;
    matchBlocks."*" = {
      extraOptions.IdentityAgent = if pkgs.stdenv.isDarwin then "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"" else "";
      identityFile = "~/.ssh/id.pub";
      identitiesOnly = true;
    };
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
      disable = [
        "rustup"
        "node"
        "pip3"
      ];
    };
  };
  programs.zellij.enable = false;
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
    initExtraBeforeCompInit = ''
      eval "$(${pkgs.rtx}/bin/rtx activate -s zsh)"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "gh"
        "git"
        "ripgrep"
        "rust"
        "vscode"
      ];
    };
  };

  home.packages = [
    pkgs.awscli2
    pkgs.dotnet-sdk_7
    pkgs.fd
    pkgs.ipcalc
    pkgs.nodejs
    pkgs.powershell
    pkgs.python3
    pkgs.ripgrep
    pkgs.rustup
    pkgs.rtx
  ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];

  home.sessionVariables = {
    LESSHISTFILE = "${config.xdg.stateHome}/less/history";
  };

  home.shellAliases = {
    cat = "bat";
    dockerv = "docker run --rm -it -v $(pwd):$(pwd) -w $(pwd)";
    darwin-switch = "(cd /tmp && darwin-rebuild switch --flake ~/.nixpkgs)";
  };

  home.file.".asdfrc" = {
    text = "legacy_version_file = yes";
  };

  home.file.".ssh/id.pub" = {
    text = publicKey;
  };
}
