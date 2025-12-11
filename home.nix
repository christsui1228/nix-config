{ config, pkgs, ... }:

{
  home.username = "chris";
  home.homeDirectory = "/home/chris";
  home.stateVersion = "24.05";

  # 1. 开启通用 Linux 支持
  targets.genericLinux.enable = true;

  # 2. 纯命令行工具包
  home.packages = with pkgs; [
    fastfetch
    nerd-fonts.jetbrains-mono 
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
    enableFishIntegration = false;
    settings = {
      theme = "solarized-dark";
      show_startup_tips = false;
      default_layout = "compact";
      default_shell = "fish"; # 强制新面板使用 Fish
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

  # 7. FD 黑名单 (解决搜出一堆乱七八糟文件的问题)
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

  # 8. LF 文件管理器 (新增模块)
  programs.lf = {
    enable = true;
    settings = {
      hidden = true;      # 显示隐藏文件
      drawbox = true;     # 显示边框
      icons = true;       # 显示图标
      ignorecase = true;  # 忽略大小写
    };
    
    keybindings = {
      # 基础操作: y=复制, d=剪切/移动, p=粘贴
      # 🗑️ 新增：按 D 删除文件 (带确认)
      D = "delete"; 
      # 快捷操作
      gh = "cd ~";       # gh 回首页
      "." = "set hidden!"; # . 切换隐藏文件
    };
  };

  # 9. Fish Shell 配置
  programs.fish = {
    enable = true;
    
    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      rm = "rm -i";
      zj = "zellij";
      lz = "lazygit";
      lf = "lfcd"; # ⚡ 输入 lf 自动调用下面的 lfcd 函数
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
      
      # ⚡ lfcd: 退出 lf 时自动跳转目录 (核心功能)
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
