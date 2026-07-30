#!/usr/bin/env bash

set -Eeuo pipefail

INVENTORY_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly INVENTORY_TIMESTAMP
inventory_output_dir="/tmp/nix-config-inventory-${INVENTORY_TIMESTAMP}"

inventory_usage() {
	cat <<'EOF'
用法：
  ./system/inventory/collect.sh [--output-dir PATH]

只采集软件管理元数据，不采集环境变量、Token、密钥或数据库内容。
默认写入 /tmp 下带时间戳的目录。
EOF
}

inventory_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

inventory_parse_args() {
	while (($# > 0)); do
		case "$1" in
		--output-dir)
			(($# >= 2)) || inventory_fail "--output-dir 缺少参数。"
			inventory_output_dir="$2"
			shift 2
			;;
		-h | --help)
			inventory_usage
			exit 0
			;;
		*)
			inventory_fail "未知参数：$1"
			;;
		esac
	done
}

inventory_validate_output_dir() {
	[[ -n "$inventory_output_dir" ]] ||
		inventory_fail "输出目录不能为空。"

	case "$inventory_output_dir" in
	/ | /home | /home/chris)
		inventory_fail "拒绝使用过于宽泛的输出目录：$inventory_output_dir"
		;;
	esac
}

inventory_write_system() {
	{
		uname -a
		printf '\n'
		cat /etc/os-release
	} >"$inventory_output_dir/system.txt"
}

inventory_write_apt() {
	if command -v apt-mark >/dev/null 2>&1; then
		apt-mark showmanual | sort >"$inventory_output_dir/apt-manual.txt"
	fi
}

inventory_write_nix() {
	if command -v nix >/dev/null 2>&1; then
		nix --version >"$inventory_output_dir/nix-version.txt"
		nix profile list >"$inventory_output_dir/nix-profile.txt" 2>&1 || true
	fi

	if command -v home-manager >/dev/null 2>&1; then
		home-manager generations >"$inventory_output_dir/home-manager-generations.txt" 2>&1 || true
	fi
}

inventory_write_node() {
	if command -v node >/dev/null 2>&1; then
		node --version >"$inventory_output_dir/node-version.txt"
	fi

	if command -v npm >/dev/null 2>&1; then
		npm ls -g --depth=0 >"$inventory_output_dir/npm-global.txt" 2>&1 || true
	fi
}

inventory_write_python_tools() {
	{
		if command -v pipx >/dev/null 2>&1; then
			find /home/chris/.local/share/pipx/venvs \
				-mindepth 1 -maxdepth 1 -type d -printf 'pipx %f\n' 2>/dev/null || true
		fi

		if command -v pdm >/dev/null 2>&1; then
			printf 'pdm '
			pdm --version 2>/dev/null || true
		fi
	} >"$inventory_output_dir/python-tools.txt"
}

inventory_write_manual_apps() {
	local app_name
	local app_path

	for app_name in nvim cpolar kiro-cli tableplus obsidian; do
		app_path="$(command -v "$app_name" 2>/dev/null || true)"
		printf '%-14s %s\n' "$app_name" "${app_path:-not-found}"
	done >"$inventory_output_dir/manual-apps.txt"
}

inventory_write_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		return
	fi

	{
		docker version --format 'client={{.Client.Version}} server={{.Server.Version}}'
		printf '\ncontainers:\n'
		docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
		printf '\nimages:\n'
		docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.Size}}'
		printf '\nspace:\n'
		docker system df
	} >"$inventory_output_dir/docker-summary.txt" 2>&1 || true
}

inventory_main() {
	inventory_parse_args "$@"
	inventory_validate_output_dir
	mkdir -p "$inventory_output_dir"

	inventory_write_system
	inventory_write_apt
	inventory_write_nix
	inventory_write_node
	inventory_write_python_tools
	inventory_write_manual_apps
	inventory_write_docker

	printf 'Inventory 已写入：%s\n' "$inventory_output_dir"
}

inventory_main "$@"
