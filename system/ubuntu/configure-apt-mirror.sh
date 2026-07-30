#!/usr/bin/env bash

set -Eeuo pipefail

APT_MIRROR_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly APT_MIRROR_SCRIPT_DIR
readonly APT_MIRROR_SOURCE="${APT_MIRROR_SCRIPT_DIR}/ubuntu.sources.aliyun"
readonly APT_MIRROR_TARGET="/etc/apt/sources.list.d/ubuntu.sources"

apt_mirror_temp_file=""

apt_mirror_log() {
	printf '\n==> %s\n' "$*"
}

apt_mirror_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

apt_mirror_cleanup() {
	if [[ -n "$apt_mirror_temp_file" && -e "$apt_mirror_temp_file" ]]; then
		rm -f -- "$apt_mirror_temp_file"
	fi
}

apt_mirror_validate_source() {
	local source_file="$1"

	[[ -s "$source_file" ]] ||
		apt_mirror_fail "镜像源模板为空：$source_file"

	[[ "$(grep -c '^Types: deb$' "$source_file")" -eq 2 ]] ||
		apt_mirror_fail "镜像源模板必须恰好包含两个 deb 段。"

	[[ "$(grep -c '^URIs: https://mirrors.aliyun.com/ubuntu/$' "$source_file")" -eq 2 ]] ||
		apt_mirror_fail "镜像源模板包含非预期 URI。"

	grep -qx 'Suites: noble noble-updates noble-backports' "$source_file" ||
		apt_mirror_fail "镜像源模板缺少 noble 主更新套件。"

	grep -qx 'Suites: noble-security' "$source_file" ||
		apt_mirror_fail "镜像源模板缺少 noble-security。"

	[[ "$(grep -c '^Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg$' "$source_file")" -eq 2 ]] ||
		apt_mirror_fail "镜像源模板缺少预期 Signed-By。"
}

apt_mirror_check_platform() {
	[[ "$(id -u)" -eq 0 ]] ||
		apt_mirror_fail "请通过 sudo 运行此脚本。"

	[[ -r /etc/os-release ]] ||
		apt_mirror_fail "无法读取 /etc/os-release。"

	# shellcheck disable=SC1091
	source /etc/os-release

	[[ "${ID:-}" == "ubuntu" ]] ||
		apt_mirror_fail "当前只支持 Ubuntu。"

	[[ "${VERSION_ID:-}" == "24.04" && "${VERSION_CODENAME:-}" == "noble" ]] ||
		apt_mirror_fail "当前只支持 Ubuntu 24.04 noble。"

	[[ -f "$APT_MIRROR_TARGET" ]] ||
		apt_mirror_fail "找不到 Ubuntu deb822 源：$APT_MIRROR_TARGET"
}

apt_mirror_restore() {
	local backup_file="$1"

	apt_mirror_log "apt-get update 失败，恢复原 Ubuntu 软件源"
	install -o root -g root -m 0644 -- "$backup_file" "$APT_MIRROR_TARGET"
	apt-get update || printf '警告：恢复后 apt-get update 仍然失败，请检查网络。\n' >&2
}

apt_mirror_main() {
	local backup_file
	local timestamp

	trap apt_mirror_cleanup EXIT

	apt_mirror_check_platform
	apt_mirror_validate_source "$APT_MIRROR_SOURCE"

	if cmp -s -- "$APT_MIRROR_SOURCE" "$APT_MIRROR_TARGET"; then
		apt_mirror_log "Ubuntu APT 已使用阿里云 HTTPS 镜像"
		apt-get update
		return
	fi

	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	backup_file="${APT_MIRROR_TARGET}.backup-${timestamp}"

	apt_mirror_log "备份当前 Ubuntu 软件源"
	cp --archive -- "$APT_MIRROR_TARGET" "$backup_file"
	printf '  %s\n' "$backup_file"

	apt_mirror_temp_file="$(mktemp "${APT_MIRROR_TARGET}.tmp.XXXXXX")"
	install -o root -g root -m 0644 -- "$APT_MIRROR_SOURCE" "$apt_mirror_temp_file"
	apt_mirror_validate_source "$apt_mirror_temp_file"
	mv -- "$apt_mirror_temp_file" "$APT_MIRROR_TARGET"
	apt_mirror_temp_file=""

	apt_mirror_log "验证阿里云 Ubuntu 镜像"
	if ! apt-get update; then
		apt_mirror_restore "$backup_file"
		apt_mirror_fail "阿里云镜像验证失败，已恢复原配置。"
	fi

	apt_mirror_log "Ubuntu APT 镜像切换完成"
}

apt_mirror_main "$@"
