{ config, pkgs, ... }:

{
  home.username = "chris";
  home.homeDirectory = "/home/chris";
  home.stateVersion = "24.05";

  # 1. 开启通用 Linux 支持
  targets.genericLinux.enable = true;

  # ⚠️ 关键设置：让 Home Manager 管理字体，否则 Alacritty 找不到 Nerd Font
  fonts.fontconfig.enable = true;

  # 2. 纯命令行工具包
  home.packages = with pkgs; [
    fastfetch
    nerd-fonts.jetbrains-mono 
    pgcli
    # 注意：不安装 neovim，继续使用 Homebrew 版以保留你的配置
  ];

  # 3. Git 模块
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "christsui1228";
        email = "christsui1228@gmail.com";
      };
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --graph --oneline --decorate";
      };
    };
  };

  # Lazygit 配置
  programs.lazygit = {
    enable = true;
    settings = {
      gui.theme = {
        activeBorderColor = [ "green" "bold" ];
        inactiveBorderColor = [ "white" ];
        selectedLineBgColor = [ "reverse" ];
      };
    };
  };

  # Delta 美化
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true; 
    };
  };

  # 4. 终端复用 Zellij
  programs.zellij = {
    enable = true;
    enableFishIntegration = false; # 我们通过 Alacritty 启动参数或别名来调用
    settings = {
      # ✅ 这里设置缓存行数为 10万
      scroll_buffer_size = 100000;
      
      theme = "solarized-dark";
      show_startup_tips = false;
      default_layout = "compact";
      default_shell = "fish"; # 强制新面板使用 Fish
      
      keybinds = {
        normal = {
          # 1. 解绑 Ctrl+h/j/k/l (把控制权还给 Neovim/Blink)
          "unbind \"Ctrl h\" \"Ctrl j\" \"Ctrl k\" \"Ctrl l\"" = [];

          # 2. 绑定 Alt+h/j/k/l (用来切换 Zellij 面板)
          "bind \"Alt h\"" = { MoveFocus = "Left"; };
          "bind \"Alt l\"" = { MoveFocus = "Right"; };
          "bind \"Alt j\"" = { MoveFocus = "Down"; };
          "bind \"Alt k\"" = { MoveFocus = "Up"; };
        };
      };
    };
  };

  # 5. FZF 模块 (配色已调整为 Solarized 风格)
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --strip-cwd-prefix --hidden --follow";
    changeDirWidgetCommand = "fd --type d --strip-cwd-prefix --hidden --follow";
    fileWidgetCommand = "fd --type f --strip-cwd-prefix --hidden --follow";
    
    defaultOptions = [ 
      "--height 40%" 
      "--layout=reverse" 
      "--border" 
      "--color=bg+:#073642,bg:#002b36,spinner:#719e07,hl:#719e07"
      "--color=fg:#839496,header:#586e75,info:#cb4b16,pointer:#719e07"
      "--color=marker:#719e07,fg+:#839496,prompt:#719e07,hl+:#719e07"
    ];
  };

  # 6. 现代化替代工具
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.bat = {
    enable = true;
    config.theme = "Solarized (dark)"; # 与 Zellij 统一
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
  
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
  };

  # 7. FD 黑名单
  programs.fd = {
    enable = true;
    hidden = true; 
    ignores = [ 
      ".git/"
      "node_modules/"
      
      # --- 系统垃圾 ---
      ".cache/" ".local/" ".npm/" ".pki/" ".dbus/" ".wget-hsts" "snap/"
      "__pycache__/" "*.bak" "*.tmp" "Downloads/"
      
      # --- 开发工具缓存 ---
      ".codeium/" ".windsurf/" ".cursor/" ".idea/" ".vscode/"
      ".cargo/" ".rustup/" 
      
      # --- 浏览器/软件配置 ---
      ".config/Kiro/" ".config/google-chrome/" ".config/opera/"
    ];
  };

  programs.ripgrep = {
    enable = true;
  };

  # 8. LF 文件管理器
  programs.lf = {
    enable = true;
    settings = {
      hidden = true;      # 显示隐藏文件
      drawbox = true;     # 显示边框
      icons = true;       # 显示图标
      ignorecase = true;  # 忽略大小写
    };
    
    keybindings = {
      # 基础操作
      D = "delete"; 
      gh = "cd ~";       
      "." = "set hidden!";
    };
  };

  # 9. Starship 提示符 (新增)
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      # 1. 保持紧凑（命令之间不空行），但提示符本身依然是两行结构
      add_newline = false;

      # 2. 路径配置：显示完整路径
      directory = {
        truncation_length = 0;    # 0 = 永不缩写，显示全路径 ~/coding/sugars
        truncate_to_repo = false; # 在 git 仓库里也不要缩写
        style = "bold blue";
      };

      # 3. 彻底隐藏你不需要的版本号信息
      package.disabled = true; # 隐藏 v0.1.0
      python.disabled = true;  # 隐藏 via v3.12.3
      nodejs.disabled = true;
      rust.disabled = true;
      golang.disabled = true;
      
      # 4. (可选) 如果你想显式确保两行模式，可以写上这一段，虽然默认就是开启的
      line_break = {
        disabled = false;
      };

      # 5. Git 分支依然保留，这很有用
      git_branch = {
        style = "bold purple";
      };
    };
  };
  # 10. Alacritty 终端配置 (✅ 修复：使用 Nix 语法替代 TOML)
  programs.alacritty = {
    enable = true;
    package = pkgs.runCommand "ignore-alacritty" {} "mkdir -p $out";
    settings = {
      general = {
        # 注意：你需要确保这个配色文件存在，或者你可以直接在这里写 colors 配置
        import = [ "~/.config/alacritty/solarized_dark.toml" ];
      };
      
      terminal.shell = {
        program = "fish";
        # 启动时直接进入 Zellij
        args = [ "-l" "-c" "zellij" ];
      };

      window = {
        padding = { x = 1; y = 1; };
        opacity = 0.98;
        decorations = "Full";
        dynamic_padding = true;
      };

      font = {
        size = 19.0;
        # ✅ 关键修复：指定 Nerd Font 家族名称，防止乱码
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
      };
    };
  };

  # 11. Fish Shell 配置
  programs.fish = {
    enable = true;
    
    shellAliases = {
      gst = "git status";
      gaa = "git add --all";
      gc = "git commit -m";
      gp = "git push";
      rm = "rm -i";
      zj = "zellij";
      lz = "lazygit";
      lf = "lfcd"; 
    };

    functions = {
      # fef: 模糊搜索并编辑
      fef = ''
        set -l file (fd --type f --hidden --follow | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
        if test -n "$file"
          $EDITOR "$file"
        end
      '';

      # fcd: 模糊搜索并跳转
      fcd = ''
        set -l dir (fd --type d --hidden --follow | fzf --preview 'eza --tree --level=1 --icons --color=always {}')
        if test -n "$dir"
          cd "$dir"
        end
      '';
      
      # lfcd: 退出 lf 时自动跳转目录
      lfcd = ''
        set tmp (mktemp)
        ${pkgs.lf}/bin/lf -last-dir-path=$tmp $argv
        if test -f "$tmp"
            set dir (cat "$tmp")
            rm -f "$tmp"
            if test -d "$dir"
                if test "$dir" != (pwd)
                    cd "$dir"
                end
            end
        end
      '';

      # frg: 全局搜索内容
      frg = ''
        if test (count $argv) -eq 0
          echo "Usage: frg <search_term>"
          return 1
        end
        rg --line-number --no-heading --color=always --smart-case $argv | \
        fzf --ansi --delimiter : --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' | \
        read -l result
        if test -n "$result"
          set file (echo $result | cut -d: -f1)
          set line (echo $result | cut -d: -f2)
          $EDITOR "+$line" "$file"
        end
      '';
    };

    interactiveShellInit = ''
      # 兼容 Homebrew (为了 Neovim)
      if test -d /home/linuxbrew/.linuxbrew/bin
        eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
      end
      
      # 设置默认编辑器
      set -gx EDITOR nvim
    '';
  };

  programs.home-manager.enable = true;
}
