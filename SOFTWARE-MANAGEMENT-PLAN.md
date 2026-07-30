# WSL 软件管理方案

> 审计日期：2026-07-30
>
> 适用环境：Ubuntu 24.04 LTS / WSL2 / 用户 `chris`

## 1. 目标

本方案的目标不是把所有软件都强行迁入 Nix，而是让每一类软件只有一个明确的管理入口：

- Ubuntu APT：管理 WSL、系统服务、驱动和 GUI 软件。
- Nix + Home Manager：管理用户级 CLI、Shell 和配置文件。
- 项目自身的 lockfile 或 devShell：管理项目依赖。
- Docker Compose：管理容器化服务。
- 少量无法被 Nix 良好管理的软件：保留原安装方式，但在仓库中记录。

推荐的总体组合是：

> Ubuntu LTS 提供稳定系统底座，锁定的 `nixos-unstable` 和 Home Manager 管理较新的用户软件。

## 2. 当前环境摘要

### 2.1 系统

- Ubuntu 24.04.4 LTS
- WSL2，已启用 systemd
- Nix 2.34.6
- Home Manager 26.11-pre
- 当前 Home Manager 配置可以正常求值和构建
- 当前激活的是 Home Manager 第 7 代

### 2.2 已发现的软件来源

| 来源 | 当前用途 | 处理建议 |
|---|---|---|
| APT/dpkg | Docker、CUDA、NVIDIA、GUI、系统库 | 只保留系统级软件 |
| Home Manager | Fish、Git、Zellij、Yazi、常用 CLI | 作为用户软件主要入口 |
| 独立 `nix profile` | `gh`、`mosh` | 迁入 Home Manager |
| Nix channel | 旧 Home Manager master channel | flake 验证后移除 |
| npm/FNM | Claude、Codex、OpenCode、OpenClaw 等 | 用独立清单和 lockfile 管理 |
| pipx/PDM | Copier、PDM | 暂时保留，之后评估迁入 Nix |
| 手工安装 | Neovim、Kiro CLI、cpolar | 作为例外记录来源和版本 |
| Docker Compose | PostgreSQL、Redis、备份服务等 | 继续按项目管理 |

系统安装了约 1004 个 dpkg 包，其中只有 77 个被标记为手工安装；其余主要是系统和应用依赖，不应把它们都视为需要手动管理的应用。

## 3. 推荐的管理边界

### 3.1 APT：系统层

APT 应继续负责：

- `ubuntu-wsl` 和 Ubuntu 基础组件
- Docker CE、containerd、Buildx、Compose 插件
- CUDA、cuDNN、NVIDIA Container Toolkit
- Obsidian、TablePlus 等 Linux GUI 软件
- 系统动态库、WSLg/X11 组件和系统字体
- 需要 systemd 服务或与 Ubuntu 深度集成的软件

不建议在当前 Ubuntu WSL 中使用 Home Manager 接管 Docker daemon、CUDA 或 NVIDIA 组件。

### 3.2 Home Manager：用户层

建议统一交给 Home Manager：

- `gh`
- `mosh`
- Fish
- Git、Lazygit、Delta
- Zellij、Starship
- fzf、fd、ripgrep、bat、eza、zoxide、atuin
- Yazi、lf
- pgcli
- fnm
- lazydocker、fastfetch
- 用户字体和相关配置文件

迁移完成后，不再用下面的方式临时安装普通用户软件：

```bash
nix profile install nixpkgs#<package>
```

所有用户级 Nix 软件都应在仓库里声明，然后通过 Home Manager 激活。

### 3.3 项目层

项目依赖不应全部进入全局 `home.packages`。

建议按项目类型管理：

- Node.js：`.node-version`、`package.json` 和 npm/pnpm lockfile
- Python：`pyproject.toml`、PDM/uv 和对应 lockfile
- 可复现要求较高的项目：`flake.nix`、`nix develop` 和 direnv
- 容器服务：项目自己的 `compose.yaml`

Home Manager 只提供通用工具和版本管理器，不负责每个项目的依赖集合。

### 3.4 快速更新的 Node CLI

当前 npm 全局环境中包含：

- Claude Code
- OpenAI Codex
- OpenCode
- OpenClaw
- Coding Helper
- Corepack

这些工具的 npm 版本明显新于当前锁定的 nixpkgs。建议暂时保留 Node 安装方式，但在仓库中建立独立目录：

```text
node-tools/
├── package.json
└── package-lock.json
```

这样可以记录确切版本，同时避免它们随着 FNM 切换 Node 版本而丢失。

当前还有一些没有命令入口的全局 npm 包，例如 Slack、Lark、Google Auth、Nostr 等 SDK。迁移前应确认它们是否为 OpenClaw 或其他工具的运行依赖，不要直接删除。

### 3.5 手工安装例外

当前主要例外包括：

- `/opt/nvim-linux-x86_64`
- `/usr/local/bin/cpolar`
- `~/.local/bin/kiro-cli*`
- PDM 自安装环境
- pipx 的 Copier 环境

处理原则：

1. 能由 Home Manager 提供相同或更新版本时再迁移。
2. 不能可靠迁移的软件继续使用官方安装方式。
3. 在本仓库记录安装地址、版本检查方式和升级步骤。
4. 不允许出现“只记得装过，但不知道从哪里装的”软件。

### 3.6 中国大陆镜像

镜像配置也按管理边界拆分：

- Ubuntu 官方 APT 源由 `system/ubuntu/configure-apt-mirror.sh` 管理，
  使用阿里云 HTTPS 镜像；Docker、CUDA、NVIDIA 和 TablePlus 等第三方
  APT 源保持各自官方地址。
- npm 和 pnpm 共用 Home Manager 声明的 `~/.npmrc`，使用 npmmirror。
- pip 和 pipx 共用 `~/.config/pip/pip.conf`，PDM 使用自己的
  `~/.config/pdm/config.toml`；两者都指向清华大学 PyPI 镜像。

项目仍可在项目级 `.npmrc`、`pyproject.toml` 或命令行中覆盖默认镜像。
镜像只改变包的下载位置，不代替 `package-lock.json`、`pnpm-lock.yaml`
或 Python lockfile，也不改变项目依赖的版本选择。

## 4. 推荐的仓库结构

当前只有一个主要用户和一台 WSL 主机，不需要拆成大量细碎模块。建议使用下面的结构：

```text
nix-config/
├── flake.nix
├── flake.lock
├── home/
│   └── chris.nix
├── modules/
│   ├── packages.nix
│   ├── china-mirrors.nix
│   ├── shell.nix
│   ├── git.nix
│   ├── terminal.nix
│   └── file-managers.nix
├── hosts/
│   └── wsl.nix
├── assets/
│   └── alacritty/
├── node-tools/
│   ├── package.json
│   └── package-lock.json
├── system/
│   ├── apt-packages.txt
│   └── README.md
└── README.md
```

各文件职责：

- `home/chris.nix`：用户名、Home 目录、state version 和模块导入。
- `modules/packages.nix`：通用用户软件列表。
- `modules/china-mirrors.nix`：npm、pnpm、pip、pipx 和 PDM 的用户级镜像。
- `modules/shell.nix`：Fish、Starship、fzf、fnm、别名和环境变量。
- `modules/git.nix`：Git、Delta、Lazygit。
- `modules/terminal.nix`：Zellij 和可选的 Alacritty 配置。
- `modules/file-managers.nix`：Yazi、lf、bat、eza。
- `hosts/wsl.nix`：WSL 专用 PATH、代理和 Linuxbrew 兼容设置。
- `assets/`：必须随配置存在的静态配置文件。
- `node-tools/`：快速更新的 Node CLI 版本清单。
- `system/apt-packages.txt`：需要在新 WSL 中通过 APT 恢复的顶层包。
- `system/README.md`：Docker、CUDA、Kiro、cpolar 等安装说明。

## 5. Nix 版本策略

当前输入组合可以继续使用：

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

原因：

- Home Manager master 针对 `nixos-unstable` 开发。
- 当前用户使用的 Neovim 和 AI CLI 更新较快。
- `flake.lock` 会固定实际提交，因此 unstable 不等于每次构建都自动变化。

更新原则：

1. 必须提交 `flake.lock`。
2. 每月或有明确需求时执行更新。
3. 更新后先构建，再切换。
4. 构建和使用验证通过后再提交。
5. 出现问题时使用 Home Manager generation 回滚。

建议工作流：

```bash
cd ~/nix-config
nix flake update
nix flake check
home-manager build --flake .#chris
home-manager switch --flake .#chris
git add flake.lock
git commit
```

`home.stateVersion = "24.05"` 应保持不变。它表示配置兼容起点，不是当前 Home Manager 软件版本。

官方参考：

- [Home Manager Flake 使用方式](https://nix-community.github.io/home-manager/nix-flakes.html)
- [Home Manager 更新说明](https://nix-community.github.io/home-manager/usage/updating.html)
- [Home Manager 项目与 release 分支说明](https://github.com/nix-community/home-manager)

## 6. 当前已确认的问题

### 6.1 存在两份 Home Manager 配置

当前配置仓库：

```text
~/nix-config/home.nix
```

旧配置：

```text
~/.config/home-manager/home.nix
```

当前生效的是 `~/nix-config`，但直接运行不带 flake 参数的 `home-manager switch` 可能使用旧配置。

目标状态：

```text
~/.config/home-manager -> ~/nix-config
```

迁移时应先备份旧目录，不应直接删除。

### 6.2 同时使用 flake 和 channel

当前仍存在旧 channel：

```text
home-manager https://github.com/nix-community/home-manager/archive/master.tar.gz
```

flake 已经提供 Home Manager input，因此该 channel 属于重复来源。确认 flake 可以正常切换后，应移除旧 channel。

### 6.3 `gh` 和 `mosh` 独立安装

`gh` 和 `mosh` 当前通过独立 `nix profile` 安装，应先加入 Home Manager，再从独立 profile 移除。

### 6.4 PATH 和 Nix 初始化重复

已发现：

- `/etc/bash.bashrc` 中 Nix 初始化代码重复两遍。
- `~/.bashrc` 又手工追加 `.local/bin`、`.nix-profile/bin` 和 Nix daemon profile。
- Home Manager 同时设置了 `home.sessionPath`。

应在确认 Bash 和 Fish 都可以加载 Home Manager 环境后，删除重复初始化，只保留一个入口。

### 6.5 Bash 与 Fish 边界不清晰

当前默认登录 shell 是 Bash，但主要交互配置写在 Fish。

建议：

- 保留 Bash 作为 WSL 登录和故障恢复 shell。
- Fish 作为主要交互 shell。
- 由 Windows Terminal 配置直接启动 Fish，或者明确记录进入 Fish 的方式。
- 不要在多个 shell 文件中重复维护 PATH 和环境变量。

### 6.6 失效或不完整的配置

- Home Manager 生成了 Alacritty 配置，但系统找不到 `alacritty`。
- Alacritty 引用了不存在的 `solarized_dark.toml`。
- Fish 别名 `spf` 指向已删除的 Superfile。
- Yazi 的播放配置依赖 `mpv`，但当前没有安装 `mpv`。

如果实际使用 Windows Terminal，应考虑移除 Linux Alacritty 配置；如果需要 WSLg Alacritty，则应真正安装 Alacritty 并纳管主题文件。

### 6.7 tmux 和 Zellij 重叠

当前同时存在：

- APT 安装的 tmux
- Zellij
- `~/.tmux` 上游配置仓库
- `~/tmux-config` 个人配置仓库

两个 tmux 仓库都有不同职责，其中上游仓库还有未提交修改。应决定：

- 只保留 Zellij；或
- 同时保留 tmux，但由 Home Manager 管理 tmux 软件和最终配置。

### 6.8 数据库客户端版本不一致

当前 Docker 中主要运行 PostgreSQL 18.4，但 WSL 中：

```text
psql      16.14
pg_dump   16.14
pg_restore 16.14
```

建议以后由 Home Manager 提供 PostgreSQL 18 客户端。迁移前必须验证现有备份脚本调用的是容器内工具还是宿主机工具。

### 6.9 Neovim 暂时不适合直接迁移

当前手工安装：

```text
Neovim 0.12.1
```

当前锁定的 nixpkgs：

```text
Neovim 0.11.5
```

直接迁入 Home Manager 会降级，因此应暂时保留手工版本。等更新后的 nixpkgs 提供相同或更新版本后再迁移。

当前 `~/.config/nvim` 是独立 Git 仓库，`lazy-lock.json` 有未提交修改，也应在迁移前处理。

## 7. 推荐迁移顺序

### 阶段一：统一 Home Manager 入口

1. 保存当前仓库修改。
2. 验证 `nix flake check` 和 Home Manager build。
3. 备份 `~/.config/home-manager`。
4. 让 `~/.config/home-manager` 指向 `~/nix-config`。
5. 固定使用 `home-manager switch --flake ~/nix-config#chris`。
6. 移除旧 Home Manager channel。

### 阶段二：重构仓库但不改变软件集合

1. 创建 `home/`、`modules/`、`hosts/`。
2. 按职责拆分现有 `home.nix`。
3. 每拆一个模块就执行一次构建验证。
4. 保证生成的 Home Manager generation 与拆分前等价。

### 阶段三：消除 Nix 重复入口

1. 将 `gh` 和 `mosh` 加入 `packages.nix`。
2. Home Manager 构建并切换。
3. 验证命令版本和配置。
4. 从独立 `nix profile` 移除对应软件。

### 阶段四：清理配置漂移

1. 清理重复 PATH 和 Nix 初始化。
2. 修复或移除 Alacritty 配置。
3. 移除失效的 Superfile 别名。
4. 决定是否安装 `mpv`。
5. 决定 tmux 与 Zellij 的关系。

### 阶段五：整理语言工具

1. 为 Node CLI 建立 `node-tools/package.json`。
2. 记录并锁定当前可执行工具版本。
3. 检查没有命令入口的 npm 全局库。
4. 决定 Copier 和 PDM 是继续使用 pipx/官方安装器，还是迁入 Nix。
5. 保证项目依赖仍由项目 lockfile 管理。

### 阶段六：系统软件清单

1. 整理真正需要恢复的 APT 顶层包。
2. 记录 Docker、CUDA、NVIDIA 软件源。
3. 记录 Kiro、cpolar、Neovim 的安装和升级方式。
4. 不直接清理 1004 个 dpkg 包，也不盲目执行 autoremove。

## 8. 每次迁移的验证清单

每次变更至少执行：

```bash
git diff --check
nix flake check
nix build .#homeConfigurations.chris.activationPackage --no-link
home-manager build --flake .#chris
```

切换后检查：

```bash
home-manager generations
which -a git fish gh mosh nvim node npm pnpm
fish --version
git --version
zellij --version
yazi --version
```

数据库相关变更还应检查：

```bash
psql --version
pg_dump --version
pg_restore --version
docker ps
```

## 9. 暂不执行的操作

在完成验证前，不应：

- 删除旧 Home Manager 目录。
- 批量执行 `apt autoremove`。
- 删除 Docker volume 或镜像。
- 删除 Node 全局 SDK。
- 将 Neovim 降级到当前 nixpkgs 版本。
- 修改 `home.stateVersion`。
- 同时升级 Nix、Home Manager、Node、Python 和所有项目依赖。

迁移应保持小步、可构建、可回滚。
