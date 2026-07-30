{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      scroll_buffer_size = 100000;

      theme = "solarized-dark";
      show_startup_tips = false;
      default_layout = "compact";
      default_shell = "fish";

      keybinds = {
        normal = {
          "unbind \"Ctrl h\" \"Ctrl j\" \"Ctrl k\" \"Ctrl l\"" = [ ];

          "bind \"Alt h\"" = {
            MoveFocus = "Left";
          };
          "bind \"Alt l\"" = {
            MoveFocus = "Right";
          };
          "bind \"Alt j\"" = {
            MoveFocus = "Down";
          };
          "bind \"Alt k\"" = {
            MoveFocus = "Up";
          };
        };
      };
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;

      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        style = "bold blue";
      };

      package.disabled = true;
      python.disabled = true;
      nodejs.disabled = true;
      rust.disabled = true;
      golang.disabled = true;

      line_break.disabled = false;

      git_branch.style = "bold purple";
    };
  };

  # 目前只管理 Alacritty 配置，不安装 Linux Alacritty 本体。
  # 后续任务会根据实际终端选择移除该配置或安装真实软件包。
  programs.alacritty = {
    enable = true;
    package = pkgs.runCommand "ignore-alacritty" { } "mkdir -p $out";
    settings = {
      general.import = [ "~/.config/alacritty/solarized_dark.toml" ];

      terminal.shell = {
        program = "fish";
        args = [
          "-l"
          "-c"
          "zellij"
        ];
      };

      window = {
        padding = {
          x = 1;
          y = 1;
        };
        opacity = 0.98;
        decorations = "Full";
        dynamic_padding = true;
      };

      font = {
        size = 16.0;
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
}
