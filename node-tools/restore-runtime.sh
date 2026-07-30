#!/usr/bin/env bash

set -Eeuo pipefail

NODE_TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly NODE_TOOLS_DIR
readonly NODE_VERSION_FILE="${NODE_TOOLS_DIR}/default-node-version"
readonly NODE_DIST_MIRROR_FILE="${NODE_TOOLS_DIR}/node-dist-mirror"

node_runtime_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

node_runtime_read_single_line() {
	local file_path="$1"
	local label="$2"
	local -a lines=()

	[[ -r "$file_path" ]] ||
		node_runtime_fail "无法读取${label}清单：$file_path"

	mapfile -t lines <"$file_path"
	[[ "${#lines[@]}" -eq 1 && -n "${lines[0]}" ]] ||
		node_runtime_fail "${label}清单必须只包含一个非空行：$file_path"

	printf '%s\n' "${lines[0]}"
}

node_runtime_main() {
	local current_default
	local fnm_bin
	local node_dist_mirror
	local node_version
	local restored_version

	node_version="$(
		node_runtime_read_single_line "$NODE_VERSION_FILE" "Node 版本"
	)"
	node_dist_mirror="$(
		node_runtime_read_single_line "$NODE_DIST_MIRROR_FILE" "Node 镜像"
	)"

	[[ "$node_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
		node_runtime_fail "Node 版本必须是完整的三段式版本：$node_version"

	[[ "$node_dist_mirror" =~ ^https://[^[:space:]]+/$ ]] ||
		node_runtime_fail "Node 镜像必须是以 / 结尾的 HTTPS 地址：$node_dist_mirror"

	fnm_bin="${FNM_BIN:-$(command -v fnm 2>/dev/null || true)}"
	[[ -n "$fnm_bin" && -x "$fnm_bin" ]] ||
		node_runtime_fail "找不到可执行的 fnm；请先激活 Home Manager。"

	export FNM_NODE_DIST_MIRROR="${FNM_NODE_DIST_MIRROR:-$node_dist_mirror}"

	restored_version="$(
		"$fnm_bin" exec --using "$node_version" node --version 2>/dev/null || true
	)"
	if [[ "$restored_version" == "v$node_version" ]]; then
		printf '  Node %s 已安装，跳过下载。\n' "$node_version"
	else
		"$fnm_bin" install --progress never "$node_version"
	fi

	current_default="$("$fnm_bin" default 2>/dev/null || true)"
	if [[ "$current_default" == "v$node_version" ]]; then
		printf '  FNM default 已是 v%s。\n' "$node_version"
	else
		"$fnm_bin" default "$node_version"
	fi

	restored_version="$("$fnm_bin" exec --using "$node_version" node --version)"
	[[ "$restored_version" == "v$node_version" ]] ||
		node_runtime_fail \
			"Node 恢复后版本不匹配：期望 v$node_version，实际 $restored_version"

	[[ "$("$fnm_bin" default)" == "v$node_version" ]] ||
		node_runtime_fail "FNM default 没有指向 v$node_version。"

	printf '  Node runtime 验证完成：%s\n' "$restored_version"
}

node_runtime_main "$@"
