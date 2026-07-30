# Ubuntu 系统层

该目录最终负责必须通过 APT、systemd 或 root 权限管理的内容：

- Ubuntu 基础包
- 可选 APT 中国镜像
- Docker Engine 和 Compose plugin
- Docker daemon 代理
- CUDA、NVIDIA 和 GUI 软件的人工恢复说明

APT 镜像脚本已经可以独立使用：

```bash
sudo ./system/ubuntu/configure-apt-mirror.sh
```

该脚本仅支持 Ubuntu 24.04 noble，只替换 deb822 格式的
`/etc/apt/sources.list.d/ubuntu.sources`。它会先创建带时间戳的备份，
备份保存在 `/var/backups/nix-config/apt/`，然后通过 `apt-get update`
验证；验证失败时自动恢复。Docker、CUDA、NVIDIA 和 TablePlus 等
第三方源不会被修改。

基础系统包也可以独立安装：

```bash
sudo ./system/ubuntu/install-packages.sh
```

安装器从 `packages.txt` 读取包名，忽略注释和空行，只安装 dpkg 尚未标记
为 installed 的包。没有缺包时不会运行 `apt-get update` 或
`apt-get install`；它永远不会执行 upgrade、autoremove、purge，或修改
APT 的 manual/auto 标记。

Docker 等其余系统安装脚本尚未开放。
