{ pkgs, ... }:

{
  imports = [
    ../hosts/wsl.nix
    ../modules/git.nix
    ../modules/terminal.nix
    ../modules/file-managers.nix
    ../modules/shell.nix
  ];

  home.username = "chris";
  home.homeDirectory = "/home/chris";

  targets.genericLinux.enable = true;
  fonts.fontconfig.enable = true;

  # 在直接传给 Home Manager 的用户模块中合并软件列表，保持现有
  # home.packages 与自动生成 completion 的顺序不变。
  home.packages = import ../modules/packages.nix { inherit pkgs; };

  # 该值表示配置兼容起点，不应随着 Home Manager 版本升级而修改。
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
}
