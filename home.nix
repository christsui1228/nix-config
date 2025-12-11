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

  # Alacritty 配置：启动时自动附着或创建 Zellij 会话
  programs.alacritty = {
    enable = true;
    settings = {
      shell = {
        program = "${pkgs.zellij}/bin/zellij";
        args = [ "attach" "--create" ];
      };
    };
  };

  # 5. FZF 模块 (配色已调整为 Solarized 风格)
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    # 这里的命令不需要手动加 exclude，因为会自动读取 programs.fd 的全局配置
    defaultCommand = "fd --type f --strip-cwd-prefix --hidden --follow";
    changeDirWidgetCommand = "fd --type d --strip-cwd-prefix --hidden --follow";
    fileWidgetCommand = "fd --type f --strip-cwd-prefix --hidden --follow";
    
    # 配色方案：Solarized Dark
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

  # ⬇️ 关键修改：FD 黑名单 (解决搜出一堆乱七八糟文件的问题)
  programs.fd = {
    enable = true;
    hidden = true; 
    ignores = [ 
      ".git/"
      "node_modules/"
      
      # --- 你的截图里出现的捣乱分子 ---
      ".cache/"       # 缓存目录 (大量垃圾)
      ".local/"       # 本地数据 (大量垃圾)
      ".npm/"         # npm 缓存
      ".codeium/"     # AI 插件缓存
      ".windsurf/"    # Windsurf 缓存
      ".cursor/"      # Cursor 缓存
      ".idea/"        # JetBrains 缓存
      ".vscode/"      # VSCode 缓存
      ".pki/"         # 证书数据库
      ".dbus/"        # 系统总线
      ".wget-hsts"    # wget 历史文件
      "snap/"         # Ubuntu Snap 应用目录 (这个特别吵)
      "Downloads/"    # 下载目录通常不放代码，建议忽略，除非你习惯在那写代码
      "__pycache__/"  # Python 编译缓存
      "*.bak"         # 备份文件
      "*.tmp"         # 临时文件
      
      # --- 针对性屏蔽 (根据你的截图) ---
      ".config/Kiro/" # 你的截图里 Kiro 产生了大量垃圾
      ".config/google-chrome/" # 浏览器缓存
      ".config/opera/"         # 浏览器缓存
    ];
  };

  programs.ripgrep = {
    enable = true;
  };

  # 7. Fish Shell 配置
  programs.fish = {
    enable = true;
    
    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      rm = "rm -i";
      zj = "zellij";
      lz = "lazygit";
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

      # frg: 全局搜索内容 (保持不变)
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
      
      # 设置默认编辑器为 nvim (这样 fef/frg 就会调用 Homebrew 的 nvim)
      set -gx EDITOR nvim
      
      # 注意：fastfetch 已移除，启动更清爽
    '';
  };

  programs.home-manager.enable = true;
}
