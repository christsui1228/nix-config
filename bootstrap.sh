#!/usr/bin/env bash

set -Eeuo pipefail

BOOTSTRAP_REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_REPO_DIR
readonly BOOTSTRAP_SUPPORTED_PROFILE="wsl"

bootstrap_profile="wsl"
bootstrap_use_china_mirror=false
bootstrap_skip_docker=false
bootstrap_preflight_only=false

bootstrap_log() {
	printf '\n==> %s\n' "$*"
}

bootstrap_warn() {
	printf '警告：%s\n' "$*" >&2
}

bootstrap_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

# 该函数由 ERR trap 间接调用。
# shellcheck disable=SC2329
bootstrap_on_error() {
	local exit_code="$?"
	local line_number="$1"

	printf '初始化在第 %s 行失败，退出码：%s。\n' \
		"$line_number" "$exit_code" >&2
	exit "$exit_code"
}

bootstrap_usage() {
	cat <<'EOF'
用法：
  ./bootstrap.sh [选项]

选项：
  --profile wsl       使用 WSL 配置（当前唯一支持的配置）
  --china-mirror      后续系统阶段使用中国大陆镜像
  --skip-docker       后续系统阶段跳过 Docker
  --preflight-only    只检查环境，不修改系统
  -h, --help          显示帮助

当前实施状态：
  目前只启用只读 preflight。系统安装、Nix 安装和 Home Manager
  激活阶段完成并经过一次性 WSL 验证后，才会开放完整执行。
EOF
}

bootstrap_parse_args() {
	while (($# > 0)); do
		case "$1" in
		--profile)
			(($# >= 2)) || bootstrap_fail "--profile 缺少参数。"
			bootstrap_profile="$2"
			shift 2
			;;
		--china-mirror)
			bootstrap_use_china_mirror=true
			shift
			;;
		--skip-docker)
			bootstrap_skip_docker=true
			shift
			;;
		--preflight-only)
			bootstrap_preflight_only=true
			shift
			;;
		-h | --help)
			bootstrap_usage
			exit 0
			;;
		*)
			bootstrap_fail "未知参数：$1"
			;;
		esac
	done
}

bootstrap_check_not_root() {
	if [[ "$(id -u)" -eq 0 ]]; then
		bootstrap_fail "请使用普通用户运行，不要执行 sudo ./bootstrap.sh。"
	fi
}

bootstrap_load_os_release() {
	[[ -r /etc/os-release ]] ||
		bootstrap_fail "无法读取 /etc/os-release。"

	# shellcheck disable=SC1091
	source /etc/os-release

	[[ "${ID:-}" == "ubuntu" ]] ||
		bootstrap_fail "当前只支持 Ubuntu，检测到：${ID:-unknown}。"

	[[ "${VERSION_ID:-}" == "24.04" ]] ||
		bootstrap_fail "当前只支持 Ubuntu 24.04，检测到：${VERSION_ID:-unknown}。"
}

bootstrap_check_profile() {
	[[ "$bootstrap_profile" == "$BOOTSTRAP_SUPPORTED_PROFILE" ]] ||
		bootstrap_fail "不支持 profile：$bootstrap_profile。"
}

bootstrap_check_wsl() {
	if ! grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease /proc/version 2>/dev/null; then
		bootstrap_fail "没有检测到 WSL。"
	fi
}

bootstrap_check_architecture() {
	[[ "$(uname -m)" == "x86_64" ]] ||
		bootstrap_fail "当前只支持 x86_64，检测到：$(uname -m)。"
}

bootstrap_check_user() {
	[[ "${USER:-}" == "chris" ]] ||
		bootstrap_fail "当前配置要求用户 chris，检测到：${USER:-unknown}。"

	[[ "${HOME:-}" == "/home/chris" ]] ||
		bootstrap_fail "当前配置要求 HOME=/home/chris，检测到：${HOME:-unknown}。"
}

bootstrap_check_systemd() {
	[[ -d /run/systemd/system ]] ||
		bootstrap_fail "systemd 未运行；请检查 /etc/wsl.conf 并重启 WSL。"
}

bootstrap_check_repository() {
	[[ -f "$BOOTSTRAP_REPO_DIR/flake.nix" ]] ||
		bootstrap_fail "仓库中缺少 flake.nix。"

	[[ -f "$BOOTSTRAP_REPO_DIR/flake.lock" ]] ||
		bootstrap_fail "仓库中缺少 flake.lock。"
}

bootstrap_report_tools() {
	local tool_name
	local tool_path

	for tool_name in git curl nix home-manager docker; do
		tool_path="$(command -v "$tool_name" 2>/dev/null || true)"
		if [[ -n "$tool_path" ]]; then
			printf '  %-14s %s\n' "$tool_name" "$tool_path"
		else
			printf '  %-14s %s\n' "$tool_name" "未安装"
		fi
	done
}

bootstrap_preflight() {
	bootstrap_log "执行只读环境检查"

	bootstrap_check_not_root
	bootstrap_check_profile
	bootstrap_load_os_release
	bootstrap_check_wsl
	bootstrap_check_architecture
	bootstrap_check_user
	bootstrap_check_systemd
	bootstrap_check_repository

	printf '  profile        %s\n' "$bootstrap_profile"
	printf '  os             %s %s\n' "${PRETTY_NAME:-Ubuntu}" "${VERSION_CODENAME:-}"
	printf '  architecture   %s\n' "$(uname -m)"
	printf '  user           %s\n' "$USER"
	printf '  repository     %s\n' "$BOOTSTRAP_REPO_DIR"
	printf '  china mirror   %s\n' "$bootstrap_use_china_mirror"
	printf '  skip docker    %s\n' "$bootstrap_skip_docker"
	bootstrap_report_tools

	bootstrap_log "Preflight 通过"
}

bootstrap_main() {
	trap 'bootstrap_on_error "$LINENO"' ERR

	bootstrap_parse_args "$@"
	bootstrap_preflight

	if [[ "$bootstrap_preflight_only" == true ]]; then
		exit 0
	fi

	bootstrap_warn "完整 bootstrap 尚未开放；本次只完成了 preflight。"
	bootstrap_warn "请使用 --preflight-only，或继续完成 MIGRATION-TASKS.md 中的系统阶段。"
	exit 2
}

bootstrap_main "$@"
