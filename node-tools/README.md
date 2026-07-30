# Node CLI tools

该目录先负责声明和恢复通用的 FNM Node runtime：

- `default-node-version`：全局默认 Node 的精确版本。
- `node-dist-mirror`：FNM 下载 Node 二进制时使用的清华大学镜像。
- `restore-runtime.sh`：幂等安装声明版本、设置 FNM default 并验证。

可以独立执行：

```bash
./node-tools/restore-runtime.sh
```

脚本已安装目标版本时不会重新下载。项目自己的 `.node-version`、
`.nvmrc` 或 devShell 仍然优先于全局默认版本。

该目录后续还用于锁定更新较快、暂时不适合由当前 nixpkgs 提供的
Node CLI，例如：

- Claude Code
- OpenAI Codex
- OpenCode
- OpenClaw
- Coding Helper

在完成全局 npm 包依赖审查前，不创建 `package.json`，也不删除现有全局包。
