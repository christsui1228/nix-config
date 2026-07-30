# nix-config

Chris 的 Ubuntu WSL2 用户环境和工作站恢复配置。

当前仓库正在从单文件 Home Manager 配置迁移为分层结构：

- Ubuntu/APT/systemd 管理系统软件、Docker、CUDA 和 NVIDIA。
- Nix flake 与 Home Manager 管理用户 CLI、Shell 和配置文件。
- FNM、项目 lockfile 或项目 devShell 管理项目运行时和依赖。
- Docker Compose 管理容器服务，独立备份负责持久化数据。

## 当前可用命令

验证配置：

```bash
nix flake check
nix build .#homeConfigurations.chris.activationPackage --no-link
```

激活配置：

```bash
home-manager switch
```

`~/.config/home-manager` 已指向本仓库；需要显式指定时仍可使用：

```bash
home-manager switch --flake ~/nix-config#chris
```

Home Manager 同时管理 npm、pnpm、pip、pipx 和 PDM 的中国大陆镜像配置。
Ubuntu APT 的 HTTPS 阿里云镜像需要系统权限，可独立执行：

```bash
sudo ./system/ubuntu/configure-apt-mirror.sh
```

该脚本会备份并只修改 Ubuntu 官方 `ubuntu.sources`，不会修改 Docker、
CUDA、NVIDIA 或 TablePlus 等第三方 APT 源。备份保存在
`/var/backups/nix-config/apt/`，不会放进 APT 的源扫描目录。

迁移前的旧配置保存在
`~/.config/home-manager.backup-20260730`，确认后续迁移稳定前暂不删除。

只运行新机初始化的只读环境检查：

```bash
./bootstrap.sh --profile wsl --preflight-only
```

运行当前已开放的安全系统阶段：

```bash
./bootstrap.sh --profile wsl --china-mirror
```

当前该命令只执行环境与网络检查、可选 APT 镜像配置和基础系统包安装。
它会明确停在 Docker、Nix 安装和 Home Manager 自动激活之前。完整
bootstrap 仍在实现中。

不要使用旧 `~/setup/install_docker.sh`，它包含删除 Docker 数据的操作。

## 日常更新与回滚

更新前先记录当前 generation，再更新锁文件、构建和激活：

```bash
home-manager generations
nix flake update
nix flake check
nix build .#homeConfigurations.chris.activationPackage --no-link
home-manager switch --flake .#chris
```

激活后验证主要命令；如果出现问题，可以立即回到上一个 generation：

```bash
home-manager switch --rollback
```

确认更新稳定后，将 `flake.lock` 和必要的兼容配置一起提交。当前不启用
无人值守的自动 flake 更新。

## 文档

- [软件管理方案](./SOFTWARE-MANAGEMENT-PLAN.md)
- [迁移任务清单](./MIGRATION-TASKS.md)
