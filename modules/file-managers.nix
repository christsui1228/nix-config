{ ... }:

{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --strip-cwd-prefix --hidden --follow";
    changeDirWidget.command = "fd --type d --strip-cwd-prefix --hidden --follow";
    fileWidget.command = "fd --type f --strip-cwd-prefix --hidden --follow";

    # Atuin 在 Fish 中继续负责 Ctrl-R；避免两个集成重复绑定。
    historyWidget.fish.command = "";

    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--color=bg+:#073642,bg:#002b36,spinner:#719e07,hl:#719e07"
      "--color=fg:#839496,header:#586e75,info:#cb4b16,pointer:#719e07"
      "--color=marker:#719e07,fg+:#839496,prompt:#719e07,hl+:#719e07"
    ];
  };

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.bat = {
    enable = true;
    config.theme = "Solarized (dark)";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fd = {
    enable = true;
    hidden = true;
    ignores = [
      ".git/"
      "node_modules/"

      ".cache/"
      ".local/"
      ".npm/"
      ".pki/"
      ".dbus/"
      ".wget-hsts"
      "snap/"
      "__pycache__/"
      "*.bak"
      "*.tmp"
      "Downloads/"

      ".codeium/"
      ".windsurf/"
      ".cursor/"
      ".idea/"
      ".vscode/"
      ".cargo/"
      ".rustup/"

      ".config/Kiro/"
      ".config/google-chrome/"
      ".config/opera/"
    ];
  };

  programs.ripgrep.enable = true;

  programs.lf = {
    enable = true;
    settings = {
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };

    keybindings = {
      D = "delete";
      gh = "cd ~";
      "." = "set hidden!";
    };
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "yy";
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
      };
      opener = {
        edit = [
          {
            run = ''nvim "$@"'';
            block = true;
          }
        ];
        play = [
          {
            run = ''mpv "$@"'';
            orphan = true;
            for = "unix";
          }
        ];
      };
      open = {
        rules = [
          {
            mime = "inode/directory";
            use = [
              "open"
              "reveal"
            ];
          }
          {
            mime = "text/*";
            use = [
              "edit"
              "open"
              "reveal"
            ];
          }
          {
            mime = "video/*";
            use = [
              "play"
              "reveal"
            ];
          }
        ];
      };
    };
  };
}
