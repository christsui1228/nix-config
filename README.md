# nix-config

Chris 的 Ubuntu WSL2 用户环境和工作站恢复配置。

当前 bootstrap 只支持以下目标环境：

- Ubuntu 24.04 WSL2
- x86_64
- 已启用 systemd
- 用户名 `chris`，Home 目录 `/home/chris`

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

在纯净 WSL 中克隆仓库后，运行当前已实现的恢复阶段：

```bash
git clone https://github.com/christsui1228/nix-config.git ~/nix-config
cd ~/nix-config
./bootstrap.sh --profile wsl --china-mirror --skip-docker
```

顶层脚本必须由普通用户运行，禁止使用 `sudo ./bootstrap.sh`。脚本只在
需要系统权限的阶段调用 `sudo`。

当前恢复流程会依次：

1. 检查 WSL、Ubuntu、架构、用户、systemd、DNS 和网络。
2. 可选切换 Ubuntu APT 中国镜像并安装基础系统包。
3. 已有 Nix 时验证并跳过安装；否则从 `https://nixos.org/nix/install`
   下载官方 installer，以 multi-user daemon 模式安装且不添加 channel。
4. 使用 `flake.lock` 构建 Home Manager generation。
5. 只有构建成功后才更新 Home Manager profile 并激活；已有相同
   generation 时不会创建重复 generation。
6. 验证 Nix daemon、generation 和 `home-manager` 命令。

Docker 和 Node CLI 自动恢复尚未接入，因此建议当前显式使用
`--skip-docker`。首次安装流程仍需在一次性纯净 WSL 中完成端到端验证，
目前不能视为正式切换完成。

不要使用旧 `~/setup/install_docker.sh`，它包含删除 Docker 数据的操作。

本仓库不会恢复 SSH 私钥、Token、密码、浏览器或 CLI 登录状态、Docker
volume、数据库数据，以及 Windows Terminal、Windows 字体等宿主机内容。
这些数据必须通过独立备份或密码管理器恢复。

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
