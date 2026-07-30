# Nix + Ubuntu WSL 软件管理迁移任务

> 创建日期：2026-07-30
>
> 当前状态：Home Manager 配置入口和 flake 来源已统一
>
> 目标环境：Ubuntu 24.04 LTS / WSL2 / `x86_64-linux` / 用户 `chris`

本文件是可执行任务清单。完整的软件管理原则和现状说明见
[SOFTWARE-MANAGEMENT-PLAN.md](./SOFTWARE-MANAGEMENT-PLAN.md)。

## 1. 最终目标

将现有的两个仓库职责融合为一个可恢复、可验证、可回滚的工作站配置仓库：

```text
~/setup       ─┐
               ├─> ~/nix-config
~/nix-config ─┘
```

最终在一台符合条件的纯净 Ubuntu WSL 中执行：

```bash
git clone <repository-url> ~/nix-config
cd ~/nix-config
./bootstrap.sh --profile wsl --china-mirror
```

即可完成：

- 检查操作系统、架构、用户名和 sudo 权限。
- 可选配置 Ubuntu 国内镜像。
- 安装系统基础软件。
- 安装并配置 Docker，但不删除已有数据。
- 安装或检测 Nix，并启用 `nix-command` 和 `flakes`。
- 构建和激活 Home Manager。
- 恢复通用 CLI、Shell 和用户配置。
- 恢复已声明的 Node CLI。
- 输出不能自动恢复的密钥、数据和手工应用提示。

## 2. 管理分层

迁移完成后，每类软件只能有一个主要负责人。

| 层级 | 管理工具 | 负责内容 |
|---|---|---|
| Windows/WSL 宿主层 | Windows、WSL 配置 | WSL 实例、Windows Terminal、Windows 字体 |
| Ubuntu 系统层 | APT、systemd、bootstrap | Docker、CUDA、NVIDIA、GUI、系统动态库 |
| 用户环境层 | Nix flake、Home Manager | Shell、Git、通用 CLI、用户配置文件 |
| 语言工具层 | FNM、项目 lockfile | Node 版本、npm/pnpm 项目依赖 |
| 项目环境层 | 项目 flake、PDM、Compose | 项目运行时、Python 依赖、数据库和服务 |
| 数据与秘密层 | 备份、密码管理器 | Docker volume、SSH 密钥、Token、登录状态 |

### 2.1 不跨层管理

- Home Manager 不接管 Docker daemon、CUDA 或 NVIDIA 驱动。
- APT 不安装已经由 Home Manager 管理的普通 CLI。
- 全局 Home Manager 不声明具体项目的 npm/Python 依赖。
- Git 不保存未加密密钥、Token、数据库数据和登录状态。
- Docker Compose 负责重建服务，但不等于备份 volume 数据。

## 3. 目标仓库结构

```text
nix-config/
├── flake.nix
├── flake.lock
├── bootstrap.sh
├── home/
│   └── chris.nix
├── modules/
│   ├── packages.nix
│   ├── shell.nix
│   ├── git.nix
│   ├── terminal.nix
│   └── file-managers.nix
├── hosts/
│   └── wsl.nix
├── assets/
│   └── alacritty/
├── system/
│   └── ubuntu/
│       ├── bootstrap.sh
│       ├── packages.txt
│       ├── configure-apt-mirror.sh
│       ├── install-docker.sh
│       ├── configure-docker-proxy.sh
│       └── manual-apps.md
├── node-tools/
│   ├── package.json
│   └── package-lock.json
├── SOFTWARE-MANAGEMENT-PLAN.md
├── MIGRATION-TASKS.md
└── README.md
```

## 4. 当前基线

### 4.1 已完成

- [x] 审计当前 Nix flake 和 Home Manager 配置。
- [x] 验证当前 flake 可以求值和构建。
- [x] 确认当前激活的 Home Manager generation 与仓库构建结果一致。
- [x] 审计 APT、Nix profile、npm、pipx、PDM、手工软件和 Docker。
- [x] 审计 `~/setup` 中的现有脚本。
- [x] 创建总体软件管理方案。
- [x] 创建本迁移任务清单。

### 4.2 当前未提交或独立状态

- 原 `~/nix-config/home.nix` 的未提交修改已原样吸收到模块化结构，
  并已随提交 `5737eae` 推送。
- `~/setup/set_apt_mirror.sh` 有 executable bit 修改。
- `~/setup/ubuntu-24.04-installation.sh` 有 executable bit 修改。
- `~/.config/nvim/lazy-lock.json` 有未提交修改。
- `~/.tmux/.tmux.conf` 有未提交修改。
- `~/setup` 是独立 Git 仓库，迁移完成前不得删除。

### 4.3 当前高风险点

- `~/setup/install_docker.sh` 会 purge Docker。
- 同一脚本会删除 `/var/lib/docker` 和 `/var/lib/containerd`。
- 当前 Docker 有 8 个容器、9 个镜像和约 4 GB volume。
- `setup_docker_net.sh` 会覆盖整个 `/etc/docker/daemon.json`。
- 当前 `daemon.json` 包含 NVIDIA runtime 配置，不能被覆盖。
- 旧 Home Manager 配置已备份为
  `~/.config/home-manager.backup-20260730`，暂时保留用于回退。
- `/etc/bash.bashrc` 中存在两段重复 Nix 初始化。
- `~/.bashrc` 和 Home Manager 同时追加 PATH。

### 4.4 首个实施批次结果

- [x] 记录迁移前 activation package：
  `/nix/store/vkhppvqidznk3qgrydws818c9m7lr6d8-home-manager-generation`。
- [x] 创建安全的顶层 bootstrap preflight。
- [x] 创建只采集软件元数据的 inventory 工具。
- [x] 创建目标目录骨架和 Ubuntu 最小包清单。
- [x] 将单文件 Home Manager 配置拆为用户、主机和功能模块。
- [x] 拆分后 activation package 与迁移前 store path 完全一致。
- [x] 将 Home Manager activation package 加入 flake checks。
- [x] 创建包含 nixfmt、ShellCheck 和 shfmt 的仓库开发环境。
- [x] 通过 ShellCheck、shfmt、nixfmt、`git diff --check` 和 flake check。

本批已经作为提交 `5737eae` 推送，普通 `nix flake check` 已通过。

### 4.5 Home Manager 来源统一结果

- [x] 将旧 `~/.config/home-manager` 整体移动到
  `~/.config/home-manager.backup-20260730`。
- [x] 创建 `~/.config/home-manager -> ~/nix-config`。
- [x] 显式 flake build 和 switch 成功。
- [x] 从 `/tmp` 使用默认配置入口 build 成功。
- [x] 移除旧 Home Manager channel。
- [x] 移除 channel 后再次使用默认配置入口 build 成功。
- [x] `home-manager-path`、`gh` 和 `mosh` 仍保持可用。
- [x] 统一入口时 generation 保持为已验证的 generation 5。
- [x] 镜像配置激活后生成 generation 6。

### 4.6 中国大陆软件镜像配置

- [x] npm 和 pnpm 使用 `https://registry.npmmirror.com/`。
- [x] pip、pipx 和 PDM 使用清华大学 PyPI 镜像。
- [x] 用户级镜像配置由 Home Manager 声明。
- [x] Ubuntu APT 已从阿里云 HTTP 升级为 HTTPS。
- [x] APT 脚本只管理 `ubuntu.sources`，不修改任何第三方源。
- [x] 在切换前验证三个镜像端点可访问。
- [x] 当前 WSL 已通过 `apt-get update` 验证。
- [x] 后续备份保存在 `/var/backups/nix-config/apt/`，不污染 APT
  源扫描目录。

## 5. 总体完成条件

所有任务完成后应满足：

- [x] 仓库只有一个 Home Manager 配置入口。
- [x] 不再依赖 Home Manager channel。
- [ ] 普通用户软件不再通过临时 `nix profile install` 安装。
- [ ] `bootstrap.sh` 可以重复运行。
- [ ] 第二次运行 bootstrap 不产生破坏性变化。
- [ ] bootstrap 不允许以 root 整体运行。
- [ ] Docker 已有数据不会被删除。
- [ ] Docker NVIDIA runtime 配置不会被覆盖。
- [x] `nix flake check` 通过。
- [x] Home Manager activation package 构建通过。
- [ ] Home Manager 可以切换和回滚。
- [ ] 纯净测试 WSL 可以完成一次完整恢复。
- [ ] 系统层、用户层和项目层的软件来源有文档记录。

---

# 阶段 0：冻结现状和建立安全基线

## SAFE-001：处理现有未提交修改

- [x] 检查 `~/nix-config/home.nix` 的未提交内容。
- [x] 将这些修改吸收到模块化结构并提交。
- [ ] 检查 Neovim 的 `lazy-lock.json` 是否需要提交。
- [ ] 检查 tmux 上游配置中的修改是否应该进入个人配置仓库。
- [ ] 保留 `~/setup` 的两个 executable bit 修改，直到迁移时决定。

验收条件：

- 每个仓库的已有修改都有明确归属。
- 迁移操作不会覆盖用户尚未提交的内容。

## SAFE-002：记录当前软件和版本

- [ ] 导出 APT 手工包清单。
- [ ] 导出当前 `nix profile list`。
- [ ] 导出 Home Manager generations。
- [ ] 导出 npm 全局包清单。
- [ ] 导出 pipx/PDM 工具清单。
- [ ] 记录手工安装的 Neovim、Kiro CLI 和 cpolar 版本。
- [ ] 记录 Docker 容器、镜像和 volume 清单。

建议输出目录：

```text
system/inventory/
├── apt-manual.txt
├── nix-profile.txt
├── npm-global.txt
├── python-tools.txt
├── manual-apps.txt
└── docker-summary.txt
```

注意：

- inventory 只能保存软件元数据。
- 不保存环境变量、Token、容器 secret 或数据库内容。

## SAFE-003：确认 Docker 数据恢复路径

- [ ] 确认所有 PostgreSQL 数据使用的 volume 或 bind mount。
- [ ] 确认 `pg_backup_s3` 备份可以成功恢复。
- [ ] 记录 Docker volume 与 Compose 项目的对应关系。
- [ ] 为重要数据库完成至少一次恢复演练。
- [ ] 明确 Ollama 模型是否需要备份或可以重新下载。

验收条件：

- 即使 Docker 安装损坏，也能从 Compose 和备份恢复关键服务。

---

# 阶段 1：建立仓库骨架

## REPO-001：创建目录结构

- [x] 创建 `home/`。
- [x] 创建 `modules/`。
- [x] 创建 `hosts/`。
- [x] 创建 `assets/`。
- [x] 创建 `system/ubuntu/`。
- [x] 创建 `system/inventory/`。
- [x] 创建 `node-tools/`。

验收条件：

- 只创建目录和占位文档，不改变当前 Home Manager 构建结果。

## REPO-002：决定如何保留 `~/setup` 历史

选择一种方式：

- [ ] 使用 `git subtree` 将 `~/setup` 历史导入 `system/legacy-setup/`。
- [ ] 只迁移重写后的文件，并将旧仓库标记为 archived。

建议：

- 如果历史有保留价值，使用 `git subtree`。
- 最终运行路径中不要直接调用 legacy 脚本。

验收条件：

- `~/setup` 的有用历史和脚本不会意外丢失。
- 高风险旧脚本不能被 bootstrap 调用。

## REPO-003：创建根目录 README

- [ ] 写明支持的平台和架构。
- [ ] 写明首次安装命令。
- [ ] 写明日常更新命令。
- [ ] 写明回滚方法。
- [ ] 写明哪些数据不会由仓库恢复。
- [ ] 明确禁止使用 `sudo ./bootstrap.sh`。

---

# 阶段 2：设计顶层 bootstrap

## BOOT-001：创建普通用户入口 `bootstrap.sh`

- [x] 使用 `#!/usr/bin/env bash`。
- [x] 启用 `set -Eeuo pipefail`。
- [x] 使用 `trap` 输出失败行号和阶段。
- [x] 检测脚本是否以 root 运行；root 运行时拒绝继续。
- [x] 解析 `--profile`。
- [x] 解析 `--china-mirror`。
- [x] 解析 `--skip-docker`。
- [x] 提供 `--help`。
- [x] 对未知参数立即报错。

禁止：

- 顶层脚本整体使用 sudo。
- 自动执行不可恢复的删除。
- 把秘密写入日志。

## BOOT-002：加入平台检测

- [x] 检测 `/etc/os-release`。
- [x] 当前只允许 Ubuntu 24.04。
- [x] 检测 WSL。
- [x] 检测 `x86_64`。
- [x] 检测当前用户名是否为 `chris`。
- [x] 检测 Home 目录是否为 `/home/chris`。
- [x] 检测 systemd 是否可用。
- [ ] 检测网络和 DNS 是否基本可用。

验收条件：

- 在不受支持的平台上只输出说明，不执行系统修改。

## BOOT-003：实现阶段化执行

- [ ] `preflight`
- [ ] `configure_apt`
- [ ] `install_system_packages`
- [ ] `install_docker`
- [ ] `install_nix`
- [ ] `build_home_manager`
- [ ] `activate_home_manager`
- [ ] `restore_node_tools`
- [ ] `postflight`

每个阶段必须：

- 有开始和完成日志。
- 失败时立即停止。
- 可以通过状态检测跳过已完成工作。

## BOOT-004：实现幂等性

- [ ] 已配置的软件源不重复添加。
- [ ] 已安装软件不先卸载再安装。
- [ ] 已存在配置先比较内容。
- [ ] 配置变化前创建带时间戳的备份。
- [ ] 用户组已包含用户时不重复添加。
- [ ] 已安装 Nix 时不重新运行安装器。
- [ ] Home Manager 构建失败时不执行 switch。

验收条件：

- 连续运行两次 bootstrap，第二次无破坏性操作。

---

# 阶段 3：Ubuntu 和 APT 系统层

## APT-001：合并 APT 镜像脚本

来源：

- `~/setup/set_apt_mirror.sh`
- `~/setup/ubuntu-24.04-installation.sh`

任务：

- [x] 只管理 Ubuntu 24.04 的 deb822 `ubuntu.sources`。
- [x] 检测发行版 codename 为 `noble`。
- [x] 使用 HTTPS 镜像。
- [x] 修改前备份原 `ubuntu.sources`。
- [x] 使用临时文件验证后再替换正式文件。
- [x] 保留 `Signed-By`。
- [x] 执行 `apt-get update` 验证。
- [x] 失败时自动恢复备份。
- [ ] 只有传入 `--china-mirror` 时才执行。

禁止：

- 使用 `find /etc/apt` 批量替换未知文件。
- 修改 CUDA、Docker、TablePlus、NVIDIA 等第三方软件源。

## APT-002：整理系统包清单

从旧 `install_tools.sh` 中移除默认安装：

- [x] `vim`
- [x] `tilix`
- [x] `zsh`

建议系统基础包：

```text
ca-certificates
curl
git
unzip
xz-utils
build-essential
python3-venv
```

任务：

- [x] 将包名放入 `system/ubuntu/packages.txt`。
- [ ] 安装器忽略空行和注释。
- [ ] 使用 `apt-get` 而不是交互式 `apt`。
- [ ] 安装后检查关键命令。

## APT-003：记录而不是盲目清理

- [ ] 不自动执行 `apt autoremove`。
- [ ] 不自动修改 apt manual/auto 标记。
- [ ] 不批量删除当前 1004 个 dpkg 包。
- [ ] 后续单独审查 77 个 manual packages。

---

# 阶段 4：Docker 系统层

## DOCKER-001：重写 Docker 安装脚本

来源：

- `~/setup/install_docker.sh`

任务：

- [ ] 检测 Ubuntu 和架构。
- [ ] 检测 Docker 是否已通过官方仓库安装。
- [ ] Docker 已存在且可用时只验证版本。
- [ ] 只移除真正冲突的发行版包。
- [ ] 不 purge 已安装的 Docker CE。
- [ ] 不删除 Docker 数据目录。
- [ ] 使用 Docker 官方 keyring 和 APT 源。
- [ ] 安装 Engine、CLI、containerd、Buildx、Compose plugin。
- [ ] 将调用 bootstrap 的普通用户加入 docker group。
- [ ] 提示重新登录以刷新组权限。
- [ ] 用 `docker version` 和 `docker info` 验证。

永久禁止出现在正常安装路径：

```bash
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
apt-get purge docker-ce
```

如果将来需要重置，必须创建独立的显式维护命令，并要求二次确认。

## DOCKER-002：安全管理 `daemon.json`

来源：

- `~/setup/setup_docker_net.sh`

当前必须保留：

```json
{
  "runtimes": {
    "nvidia": {
      "args": [],
      "path": "nvidia-container-runtime"
    }
  }
}
```

任务：

- [ ] 读取并验证现有 `/etc/docker/daemon.json`。
- [ ] 不覆盖未知键。
- [ ] 保留 NVIDIA runtime。
- [ ] 只在用户明确启用时添加 registry mirror。
- [ ] 修改后使用 JSON 工具验证语法。
- [ ] 重启 Docker 前保存备份。
- [ ] Docker 重启失败时恢复原文件。

## DOCKER-003：代理配置

- [ ] 将代理地址作为参数或交互输入。
- [ ] 默认值可以是 `http://127.0.0.1:7890`。
- [ ] 明确 WSL 网络模式可能影响 localhost 代理。
- [ ] 配置 systemd drop-in 或 Docker daemon `proxies`，只选择一种主方式。
- [ ] 设置合理的 `NO_PROXY`。
- [ ] `systemctl daemon-reload` 后重启 Docker。
- [ ] 使用 `systemctl show --property=Environment docker` 验证。
- [ ] 使用 `docker pull hello-world` 作为可选网络测试。

## DOCKER-004：镜像源审查

- [ ] 不默认信任未经确认的第三方 Docker Hub mirror。
- [ ] 验证每个镜像服务的当前可用性和所有者。
- [ ] 默认优先使用代理访问官方 registry。
- [ ] 镜像源不可用时不阻止 Docker 正常启动。

---

# 阶段 5：Nix 基础层

## NIX-001：安装或检测 Nix

- [ ] `command -v nix` 成功时跳过安装。
- [ ] 记录选择官方 Nix installer 或其他 installer 的理由。
- [ ] 不使用不明来源的安装脚本。
- [ ] 安装后加载 `nix-daemon.sh`。
- [ ] 验证当前普通用户可以访问 Nix daemon。
- [ ] 验证 `nix --version`。

## NIX-002：统一 Nix 配置

- [ ] 确保只存在一处有效的：

```text
experimental-features = nix-command flakes
```

- [ ] 清理 `/etc/bash.bashrc` 中重复的 Nix 初始化块。
- [ ] 清理 `~/.bashrc` 中重复 PATH。
- [ ] 保留 Bash 登录和恢复能力。
- [ ] Fish 作为主要交互 Shell。
- [ ] 确认 Bash 与 Fish 都能找到 Nix 和 Home Manager 软件。

## NIX-003：移除旧 channel

- [x] 确认 flake build 和 switch 连续成功。
- [x] 记录原 Home Manager master channel。
- [x] 移除旧 Home Manager channel。
- [x] 确认默认 flake build 不再依赖 `<home-manager>` 或 `<nixpkgs>`。

验收条件：

```bash
nix-channel --list
```

不再显示旧 Home Manager channel，且 flake 工作正常。

## NIX-004：统一 Home Manager 配置入口

- [x] 备份 `~/.config/home-manager`。
- [x] 比较旧 `home.nix` 与仓库配置。
- [x] 确认旧配置没有需要迁移的唯一内容。
- [x] 将 `~/.config/home-manager` 指向 `~/nix-config`。
- [x] 验证显式和默认 Home Manager 配置入口。

标准命令：

```bash
home-manager switch --flake ~/nix-config#chris
```

---

# 阶段 6：Home Manager 模块化

## HM-001：拆分最小用户入口

- [x] 将用户基础信息迁入 `home/chris.nix`。
- [x] 保持 `home.stateVersion = "24.05"`。
- [x] 导入各功能模块。
- [x] 不在拆分过程中升级软件。

验收条件：

- 拆分前后 activation package 的行为保持一致。

## HM-002：创建 `modules/packages.nix`

- [x] 迁移现有 `home.packages`。
- [ ] 将 `gh` 加入 Home Manager。
- [ ] 将 `mosh` 加入 Home Manager。
- [ ] 评估加入 PostgreSQL 18 客户端。
- [ ] 评估加入 `mpv`。
- [ ] 不加入 Docker daemon、CUDA 或系统 GUI。

迁移 `gh`、`mosh` 时：

1. 先加入 Home Manager。
2. 构建和切换。
3. 验证命令。
4. 最后从独立 `nix profile` 移除。

## HM-003：创建 `modules/shell.nix`

- [x] 迁移 Fish。
- [x] 迁移 Starship。
- [x] 迁移 fzf、zoxide、atuin。
- [x] 迁移 Shell alias 和 functions。
- [ ] 清理 `spf=superfile`。
- [ ] 决定 pnpm 是由 Nix 还是 Corepack 提供。
- [ ] 处理 FNM 与 Nix devShell 的 PATH 优先级。
- [ ] 将 WSL 代理设置移到 host 模块或可选配置。

## HM-004：创建其他模块

- [x] `modules/git.nix`
- [x] `modules/terminal.nix`
- [x] `modules/file-managers.nix`
- [x] `hosts/wsl.nix`

每个模块已完成构建验证，最终 activation package 与迁移前完全一致。

## HM-005：处理 Alacritty

二选一：

- [ ] 如果实际使用 Windows Terminal，移除 Linux Alacritty 配置和无效空包。
- [ ] 如果使用 WSLg Alacritty，由 Home Manager 安装真正的 Alacritty。

如果保留：

- [ ] 将 `solarized_dark.toml` 放入 `assets/alacritty/`。
- [ ] 由 Home Manager 创建正确链接。
- [ ] 验证 Alacritty 可以启动。

## HM-006：处理 tmux 与 Zellij

选择一种：

- [ ] 只保留 Zellij。
- [ ] 同时保留 tmux，并由 Home Manager 管理 tmux 软件与插件。

无论选择哪种：

- [ ] 处理 `~/.tmux` 的未提交修改。
- [ ] 保留 `~/tmux-config` 的个人配置历史。
- [ ] 消除两个仓库对同一最终配置文件的竞争。

---

# 阶段 7：Node 和项目依赖

## NODE-001：退役 NVM 安装脚本

- [ ] 停止调用 `~/setup/npm_install.sh`。
- [ ] 不再安装 NVM。
- [ ] FNM 作为唯一全局 Node 版本管理器。
- [ ] 不再通过该脚本全局安装 pnpm。

## NODE-002：建立 Node CLI 清单

- [ ] 创建 `node-tools/package.json`。
- [ ] 将实际需要的 CLI 加入 dependencies。
- [ ] 创建并提交 lockfile。
- [ ] 将 CLI 安装在仓库或专用数据目录，不绑定某个 FNM Node 版本的 global 目录。
- [ ] 为 CLI bin 提供稳定 PATH 或 Home Manager wrapper。

当前需要评估：

- `@anthropic-ai/claude-code`
- `@openai/codex`
- `opencode-ai`
- `openclaw`
- `@x-all-in-one/coding-helper`

## NODE-003：审查无命令入口的全局包

- [ ] `@buape/carbon`
- [ ] `@larksuiteoapi/node-sdk`
- [ ] `@slack/web-api`
- [ ] `google-auth-library`
- [ ] `nostr-tools`
- [ ] `zca-js`

对每个包确认：

- 是项目依赖。
- 是 OpenClaw/plugin 的运行依赖。
- 或者是可以移除的误装全局包。

未确认前不删除。

## NODE-004：定义项目 Node 策略

普通项目：

- [ ] 使用 `.node-version`。
- [ ] 使用 FNM 自动切换。
- [ ] 提交 `packageManager` 字段。
- [ ] 提交 npm/pnpm lockfile。

高可复现项目：

- [ ] 使用项目自己的 `flake.nix`。
- [ ] 在 devShell 中声明一个 Node 版本。
- [ ] 使用 `direnv` 自动进入环境。
- [ ] 同一项目不同时使用 FNM 和 Nix 管理 Node。

---

# 阶段 8：Python、数据库和手工软件

## PY-001：统一 Python CLI 策略

- [ ] 确认 PDM 保留官方安装方式还是迁入 Nix。
- [ ] 确认 Copier 保留 pipx 还是迁入 Nix。
- [ ] 不同时为同一个工具保留两个安装来源。
- [ ] Python 项目依赖继续使用项目虚拟环境和 lockfile。

## DB-001：数据库客户端版本

- [ ] 确认宿主机 `psql/pg_dump/pg_restore` 的使用场景。
- [ ] 确认备份脚本实际调用的 PostgreSQL 客户端位置。
- [ ] 测试 PostgreSQL 18 客户端连接现有容器。
- [ ] 测试备份和恢复。
- [ ] 验证后再决定是否移除 APT PostgreSQL 16 客户端。

## APP-001：Neovim

- [ ] 保留当前手工安装的 Neovim 0.12.1。
- [ ] 等 nixpkgs 提供相同或更新版本后再迁移。
- [ ] 处理 Neovim 配置仓库未提交修改。
- [ ] 记录迁移前后的插件兼容情况。

## APP-002：无法直接由 Nix 管理的软件

在 `system/ubuntu/manual-apps.md` 中记录：

- [ ] Kiro CLI
- [ ] cpolar
- [ ] Obsidian
- [ ] TablePlus
- [ ] 其他 `/opt` 或 `/usr/local/bin` 软件

每项至少记录：

- 官方来源。
- 当前版本检查命令。
- 安装位置。
- 更新方法。
- 卸载方法。
- 是否包含用户数据。

---

# 阶段 9：验证和自动化测试

## TEST-001：静态检查

- [x] 所有本批 Shell 脚本通过 `bash -n`。
- [x] 引入 ShellCheck。
- [x] 引入 shfmt 和 nixfmt。
- [x] `git diff --check` 通过。
- [x] 本批 executable bit 符合预期。
- [x] 本批文件未检出常见私钥和 Token 模式。

## TEST-002：Nix 构建检查

每次迁移执行：

```bash
git diff --check
nix flake check
nix build .#homeConfigurations.chris.activationPackage --no-link
home-manager build --flake .#chris
```

- [x] `nix flake check path:.` 通过。
- [x] activation package 构建通过。
- [x] Home Manager 配置构建通过。
- [ ] switch 后 Fish 可以启动。
- [ ] generation 可以回滚。

## TEST-003：命令来源检查

检查：

```bash
which -a git fish gh mosh nvim node npm pnpm
```

- [ ] 每个主要命令都有预期来源。
- [ ] `gh` 和 `mosh` 来自 Home Manager。
- [ ] 不存在 NVM 与 FNM 冲突。
- [ ] 不存在多个 pnpm 来源竞争。
- [ ] PATH 不包含重复的 Nix 初始化结果。

## TEST-004：Docker 验证

- [ ] `docker version`
- [ ] `docker info`
- [ ] `docker compose version`
- [ ] NVIDIA runtime 仍存在。
- [ ] 原有容器仍可启动。
- [ ] 原有 volume 仍存在。
- [ ] PostgreSQL 和 Redis 服务健康。
- [ ] 代理配置按预期工作。

## TEST-005：纯净 WSL 演练

- [ ] 创建一次性 Ubuntu 24.04 WSL 实例。
- [ ] 只安装 Git 或使用临时 Nix Git。
- [ ] 克隆 `nix-config`。
- [ ] 运行 bootstrap。
- [ ] 关闭并重新打开终端。
- [ ] 验证 Home Manager 软件。
- [ ] 再运行一次 bootstrap 验证幂等性。
- [ ] 销毁测试 WSL，不影响主环境。

验收条件：

- 新环境首次执行成功。
- 第二次执行不卸载、不覆盖、不重复追加。
- 所有未自动恢复项目都有明确提示。

---

# 阶段 10：切换和收尾

## CUTOVER-001：正式启用新入口

- [ ] 更新 README 中的唯一安装命令。
- [ ] 正式使用根目录 `bootstrap.sh`。
- [ ] 停止使用 `~/setup` 中的旧脚本。
- [ ] 为旧脚本增加醒目的 deprecated 说明。

## CUTOVER-002：归档旧 setup 仓库

只有满足以下条件后才能归档：

- [ ] 系统层功能全部迁移。
- [ ] Docker 安装和代理配置已在测试 WSL 验证。
- [x] APT HTTPS 镜像配置已在当前 WSL 通过 `apt-get update` 验证。
- [ ] Node NVM 脚本已经完全不再使用。
- [ ] Git 历史或必要内容已经保留。

归档不等于立即删除本地目录。

## CUTOVER-003：建立日常维护流程

每月或按需：

```bash
cd ~/nix-config
nix flake update
nix flake check
home-manager build --flake .#chris
home-manager switch --flake .#chris
```

- [ ] 更新前记录当前 generation。
- [ ] 更新后检查主要命令。
- [ ] 将 `flake.lock` 和配置变更一起提交。
- [ ] 不启用无人值守的自动 flake 更新。

---

# 6. 永久安全规则

以下规则适用于所有后续实现：

- [ ] 不运行 `rm -rf /var/lib/docker`。
- [ ] 不运行 `rm -rf /var/lib/containerd`。
- [ ] 不覆盖未知的 `/etc/docker/daemon.json` 键。
- [ ] 不自动执行 `apt autoremove`。
- [ ] 不未经确认删除 npm 全局包。
- [ ] 不删除旧 Home Manager 配置而不先备份。
- [ ] 不修改 `home.stateVersion` 来追随软件版本。
- [ ] 不在同一次迁移中升级所有系统和语言工具。
- [ ] 不把 secrets、SSH 私钥、Token 或数据库备份提交到 Git。
- [ ] 不在主 WSL 上首次测试高风险系统脚本。

## 7. 建议的首个实施批次

第一批只做低风险结构工作：

1. [ ] 处理并提交当前 `home.nix` 修改。
2. [x] 创建目标目录结构。
3. [x] 创建顶层 `bootstrap.sh` 的参数解析和 preflight。
4. [x] 创建只读 inventory 导出功能。
5. [x] 拆分 Home Manager 模块，并保持构建结果不变。
6. [ ] 在一次性 WSL 中验证 preflight。

第一批明确不做：

- 不安装或卸载 Docker。
- 不修改 `/etc/docker/daemon.json`。
- 不修改 APT 软件源。
- 不删除 channel。
- 不迁移 Node CLI。
- 不删除旧 `~/setup`。
