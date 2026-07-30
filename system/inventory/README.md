# Software inventory

运行：

```bash
./system/inventory/collect.sh
```

默认将软件来源和版本元数据写入 `/tmp/nix-config-inventory-<UTC timestamp>`。

脚本不会采集环境变量、Token、SSH 密钥或数据库内容。需要将 inventory 提交到
Git 前，应先人工检查每个文件。
