# Nix system integration

`normalize-shell-init.sh` 用于清理 Nix multi-user installer 留下的重复
Shell 初始化块，同时保留 Bash 作为登录和故障恢复 Shell。

只读检查：

```bash
./system/nix/normalize-shell-init.sh --check --user chris
```

应用修复：

```bash
sudo ./system/nix/normalize-shell-init.sh --user chris
```

完整的系统修复需要 `sudo`。如果系统文件已经规范、只剩当前用户
`.bashrc` 需要更新，也可以由该用户直接运行；此时备份写入
`~/.local/state/nix-config/backups/`。脚本不会允许普通用户修改其他用户
的文件。

脚本只处理以下内容：

- 确保 `/etc/bash.bashrc` 和 `/etc/profile.d/nix.sh` 各有一个标准的
  `nix-daemon.sh` 初始化块。
- 如果 `/etc/bashrc` 或 `/etc/zshrc` 已经包含官方初始化块，将其规范为
  一份。
- 从目标用户 `.bashrc` 移除重复的手工 Nix PATH，只为非登录 Bash
  幂等补充 `~/.local/bin`；登录 Bash 继续使用 Ubuntu 默认 `.profile`。

脚本遇到未知格式时停止，不猜测修改。实际修改前会将原文件按原目录结构
备份到 `/var/backups/nix-config/nix-shell/<UTC 时间>/`；用户范围运行时
则使用上述用户状态目录。脚本不会修改 Nix Store、profile generation
或用户应用配置。
