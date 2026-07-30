#!/usr/bin/env bash

set -Eeuo pipefail

SYSTEM_PACKAGES_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_PACKAGES_SCRIPT_DIR
readonly SYSTEM_PACKAGES_FILE="${SYSTEM_PACKAGES_SCRIPT_DIR}/packages.txt"

system_packages_log() {
	printf '\n==> %s\n' "$*"
}

system_packages_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

system_packages_check_platform() {
	[[ "$(id -u)" -eq 0 ]] ||
		system_packages_fail "请通过 sudo 运行此脚本。"

	[[ -r /etc/os-release ]] ||
		system_packages_fail "无法读取 /etc/os-release。"

	# shellcheck disable=SC1091
	source /etc/os-release

	[[ "${ID:-}" == "ubuntu" ]] ||
		system_packages_fail "当前只支持 Ubuntu。"

	[[ "${VERSION_ID:-}" == "24.04" && "${VERSION_CODENAME:-}" == "noble" ]] ||
		system_packages_fail "当前只支持 Ubuntu 24.04 noble。"
}

system_packages_read_list() {
	local line

	[[ -r "$SYSTEM_PACKAGES_FILE" ]] ||
		system_packages_fail "无法读取包清单：$SYSTEM_PACKAGES_FILE"

	SYSTEM_PACKAGES=()

	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"

		[[ -n "$line" ]] || continue

		[[ "$line" =~ ^[a-z0-9][a-z0-9+.-]*(:[a-z0-9]+)?$ ]] ||
			system_packages_fail "包清单包含无效名称：$line"

		SYSTEM_PACKAGES+=("$line")
	done <"$SYSTEM_PACKAGES_FILE"

	((${#SYSTEM_PACKAGES[@]} > 0)) ||
		system_packages_fail "包清单中没有有效包名。"
}

system_package_is_installed() {
	local package_name="$1"

	[[ "$(dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null || true)" == "installed" ]]
}

system_packages_collect_missing() {
	local package_name

	SYSTEM_PACKAGES_MISSING=()

	for package_name in "${SYSTEM_PACKAGES[@]}"; do
		if ! system_package_is_installed "$package_name"; then
			SYSTEM_PACKAGES_MISSING+=("$package_name")
		fi
	done
}

system_packages_install_missing() {
	if ((${#SYSTEM_PACKAGES_MISSING[@]} == 0)); then
		system_packages_log "系统基础包均已安装，跳过 apt-get install"
		return
	fi

	system_packages_log "更新 APT 索引"
	apt-get update

	system_packages_log "安装缺少的系统基础包"
	printf '  %s\n' "${SYSTEM_PACKAGES_MISSING[@]}"
	DEBIAN_FRONTEND=noninteractive apt-get install \
		--yes \
		--no-install-recommends \
		-- "${SYSTEM_PACKAGES_MISSING[@]}"
}

system_packages_verify() {
	local command_name
	local package_name

	for package_name in "${SYSTEM_PACKAGES[@]}"; do
		system_package_is_installed "$package_name" ||
			system_packages_fail "安装后仍未检测到包：$package_name"
	done

	for command_name in curl git unzip xz make python3; do
		command -v "$command_name" >/dev/null ||
			system_packages_fail "安装后找不到关键命令：$command_name"
	done

	system_packages_log "系统基础包验证通过"
}

system_packages_main() {
	system_packages_check_platform
	system_packages_read_list
	system_packages_collect_missing
	system_packages_install_missing
	system_packages_verify
}

system_packages_main "$@"
