# Ubuntu 系统层

该目录最终负责必须通过 APT、systemd 或 root 权限管理的内容：

- Ubuntu 基础包
- 可选 APT 中国镜像
- Docker Engine 和 Compose plugin
- Docker daemon 代理
- CUDA、NVIDIA 和 GUI 软件的人工恢复说明

当前仅建立目录和包清单。系统安装脚本尚未开放，现阶段不要从这里修改
APT、Docker 或 `/etc`。
