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
home-manager switch --flake ~/nix-config#chris
```

只运行新机初始化的环境检查：

```bash
./bootstrap.sh --profile wsl --preflight-only
```

完整 bootstrap 尚在实现中。在任务明确完成前，不要使用旧
`~/setup/install_docker.sh`，它包含删除 Docker 数据的操作。

## 文档

- [软件管理方案](./SOFTWARE-MANAGEMENT-PLAN.md)
- [迁移任务清单](./MIGRATION-TASKS.md)
