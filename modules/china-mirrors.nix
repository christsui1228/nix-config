{ ... }:

let
  nodeDistMirror = builtins.replaceStrings [ "\n" ] [ "" ] (
    builtins.readFile ../node-tools/node-dist-mirror
  );
in
{
  home.sessionVariables.FNM_NODE_DIST_MIRROR = nodeDistMirror;

  # npm 和 pnpm 都读取用户级 .npmrc。
  home.file.".npmrc".text = ''
    registry=https://registry.npmmirror.com/
  '';

  # pipx 创建环境时同样遵循 pip 的全局用户配置。
  xdg.configFile."pip/pip.conf".text = ''
    [global]
    index-url = https://pypi.tuna.tsinghua.edu.cn/simple
  '';

  xdg.configFile."pdm/config.toml".text = ''
    [pypi]
    url = "https://pypi.tuna.tsinghua.edu.cn/simple"
  '';
}
