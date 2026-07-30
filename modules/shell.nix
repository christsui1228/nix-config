{ pkgs, ... }:

{
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
      spf = "superfile";
    };

    functions = {
      fef = ''
        set -l file (fd --type f --hidden --follow | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
        if test -n "$file"
          $EDITOR "$file"
        end
      '';

      fcd = ''
        set -l dir (fd --type d --hidden --follow | fzf --preview 'eza --tree --level=1 --icons --color=always {}')
        if test -n "$dir"
          cd "$dir"
        end
      '';

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

    shellInit = ''
      set -g fish_greeting
    '';

    interactiveShellInit = ''
      # fnm 初始化
      fnm env --use-on-cd --shell fish | source

      # 兼容 Homebrew (为了 Neovim)
      if test -d /home/linuxbrew/.linuxbrew/bin
        eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
      end

      # 设置默认编辑器
      set -gx EDITOR nvim
    '';
  };
}
