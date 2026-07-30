#!/usr/bin/env bash

set -Eeuo pipefail

readonly NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
readonly NIX_BLOCK_START="# Nix"
readonly NIX_BLOCK_IF="if [ -e '${NIX_DAEMON_PROFILE}' ]; then"
readonly NIX_BLOCK_SOURCE="  . '${NIX_DAEMON_PROFILE}'"
readonly NIX_BLOCK_FI="fi"
readonly NIX_BLOCK_END="# End Nix"
readonly LEGACY_USER_PATH_MARKER="# nix-config: add user-local commands without duplicating the Nix PATH."
readonly USER_PATH_MARKER="# nix-config: add user-local commands only in non-login Bash."

normalize_check_only=false
normalize_target_user=""
normalize_runtime_dir=""
normalize_pending_target=""
normalize_backup_root=""
normalize_changes_needed=false
normalize_changed=false

normalize_log() {
	printf '\n==> %s\n' "$*"
}

normalize_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

normalize_usage() {
	cat <<'EOF'
用法：
  sudo ./system/nix/normalize-shell-init.sh --user <用户名>
  ./system/nix/normalize-shell-init.sh --user <当前用户名>
  ./system/nix/normalize-shell-init.sh --check --user <用户名>

选项：
  --user USER  要检查或修复 .bashrc 的普通用户。
  --check      只检查，不修改文件；发现需要修改时返回非零状态。
  -h, --help   显示帮助。
EOF
}

normalize_cleanup() {
	if [[ -n "$normalize_pending_target" ]]; then
		case "$normalize_pending_target" in
		/etc/*.nix-config.* | /home/*/.bashrc.nix-config.*)
			rm -f -- "$normalize_pending_target"
			;;
		esac
	fi

	case "$normalize_runtime_dir" in
	/tmp/nix-config-nix-shell.*)
		rm -f -- "$normalize_runtime_dir"/*
		rmdir -- "$normalize_runtime_dir" 2>/dev/null || true
		;;
	esac
}

normalize_parse_args() {
	while (($# > 0)); do
		case "$1" in
		--user)
			(($# >= 2)) || normalize_fail "--user 缺少参数。"
			normalize_target_user="$2"
			shift 2
			;;
		--check)
			normalize_check_only=true
			shift
			;;
		-h | --help)
			normalize_usage
			exit 0
			;;
		*)
			normalize_fail "未知参数：$1"
			;;
		esac
	done

	[[ "$normalize_target_user" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] ||
		normalize_fail "请通过 --user 指定有效的普通用户名。"
}

normalize_prepare() {
	[[ -r "$NIX_DAEMON_PROFILE" ]] ||
		normalize_fail "找不到 Nix daemon 初始化脚本：$NIX_DAEMON_PROFILE"

	normalize_runtime_dir="$(mktemp -d /tmp/nix-config-nix-shell.XXXXXX)"
}

normalize_resolve_user_home() {
	local passwd_entry
	local passwd_name
	local passwd_uid
	local passwd_home

	passwd_entry="$(getent passwd "$normalize_target_user" || true)"
	[[ -n "$passwd_entry" ]] ||
		normalize_fail "找不到用户：$normalize_target_user"

	IFS=: read -r passwd_name _ passwd_uid _ _ passwd_home _ <<<"$passwd_entry"

	[[ "$passwd_name" == "$normalize_target_user" && "$passwd_uid" -ne 0 ]] ||
		normalize_fail "--user 必须指定现有普通用户。"
	[[ "$passwd_home" == /home/* && -d "$passwd_home" ]] ||
		normalize_fail "用户 Home 目录不符合预期：$passwd_home"
	if [[ "$(id -u)" -ne 0 && "$(id -u)" -ne "$passwd_uid" ]]; then
		normalize_fail "非 root 运行时，--user 只能指定当前用户。"
	fi

	NORMALIZE_USER_HOME="$passwd_home"
	readonly NORMALIZE_USER_HOME
}

normalize_ensure_backup_root() {
	if [[ -n "$normalize_backup_root" ]]; then
		return
	fi

	if [[ "$(id -u)" -eq 0 ]]; then
		normalize_backup_root="/var/backups/nix-config/nix-shell/$(date -u +%Y%m%dT%H%M%SZ)"
	else
		normalize_backup_root="${NORMALIZE_USER_HOME}/.local/state/nix-config/backups/nix-shell/$(date -u +%Y%m%dT%H%M%SZ)"
	fi
	mkdir -p -- "$normalize_backup_root"
}

normalize_apply_candidate() {
	local backup_path
	local candidate="$1"
	local target="$2"

	if cmp -s -- "$candidate" "$target"; then
		printf '  已规范：%s\n' "$target"
		return
	fi

	normalize_changes_needed=true
	if [[ "$normalize_check_only" == true ]]; then
		printf '  需要规范：%s\n' "$target"
		return
	fi

	[[ -w "$target" ]] ||
		normalize_fail "没有权限修改 $target；系统文件需要使用 sudo。"

	normalize_ensure_backup_root
	backup_path="${normalize_backup_root}${target}"
	mkdir -p -- "$(dirname -- "$backup_path")"
	cp --archive -- "$target" "$backup_path"

	normalize_pending_target="$(mktemp "${target}.nix-config.XXXXXX")"
	cp -- "$candidate" "$normalize_pending_target"
	chown --reference="$target" "$normalize_pending_target"
	chmod --reference="$target" "$normalize_pending_target"
	mv -- "$normalize_pending_target" "$target"
	normalize_pending_target=""
	normalize_changed=true

	printf '  已规范：%s\n' "$target"
}

normalize_validate_nix_blocks() {
	local block_count="$1"
	local extracted_file="$2"
	local expected_line_count
	local line
	local line_count
	local matching_count

	line_count="$(wc -l <"$extracted_file")"
	expected_line_count=$((block_count * 5))
	[[ "$line_count" -eq "$expected_line_count" ]] ||
		normalize_fail "检测到非标准的 # Nix / # End Nix 内容，拒绝自动修改。"

	for line in \
		"$NIX_BLOCK_START" \
		"$NIX_BLOCK_IF" \
		"$NIX_BLOCK_SOURCE" \
		"$NIX_BLOCK_FI" \
		"$NIX_BLOCK_END"; do
		matching_count="$(grep -Fxc -- "$line" "$extracted_file" || true)"
		[[ "$matching_count" -eq "$block_count" ]] ||
			normalize_fail "检测到未知的 Nix 初始化块，拒绝自动修改。"
	done
}

normalize_system_file() {
	local candidate_file
	local end_count
	local extracted_file
	local require_block="$1"
	local start_count
	local target="$2"

	[[ -f "$target" && ! -L "$target" ]] ||
		normalize_fail "目标必须是普通文件且不能是软链接：$target"

	start_count="$(grep -Fxc -- "$NIX_BLOCK_START" "$target" || true)"
	end_count="$(grep -Fxc -- "$NIX_BLOCK_END" "$target" || true)"
	[[ "$start_count" -eq "$end_count" ]] ||
		normalize_fail "Nix 初始化块起止数量不一致：$target"

	if [[ "$start_count" -eq 0 && "$require_block" != true ]]; then
		printf '  未包含 Nix 初始化块，跳过：%s\n' "$target"
		return
	fi

	if [[ "$start_count" -gt 0 ]]; then
		extracted_file="$(mktemp "${normalize_runtime_dir}/blocks.XXXXXX")"
		sed -n '/^# Nix$/,/^# End Nix$/p' "$target" >"$extracted_file"
		normalize_validate_nix_blocks "$start_count" "$extracted_file"
	fi

	candidate_file="$(mktemp "${normalize_runtime_dir}/system.XXXXXX")"
	{
		printf '%s\n' \
			"$NIX_BLOCK_START" \
			"$NIX_BLOCK_IF" \
			"$NIX_BLOCK_SOURCE" \
			"$NIX_BLOCK_FI" \
			"$NIX_BLOCK_END"
		printf '\n'
		sed '/^# Nix$/,/^# End Nix$/d' "$target" |
			awk 'started || NF { started = 1; print }'
	} >"$candidate_file"

	bash -n "$candidate_file"
	normalize_apply_candidate "$candidate_file" "$target"
}

normalize_user_bashrc() {
	local bashrc_path="${NORMALIZE_USER_HOME}/.bashrc"
	local candidate_file
	local legacy_marker_count
	local marker_count
	local old_line
	local old_line_count

	[[ -f "$bashrc_path" && ! -L "$bashrc_path" ]] ||
		normalize_fail "用户 .bashrc 必须是普通文件且不能是软链接：$bashrc_path"

	old_line="export PATH=\"${NORMALIZE_USER_HOME}/.local/bin:${NORMALIZE_USER_HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH\""
	old_line_count="$(grep -Fxc -- "$old_line" "$bashrc_path" || true)"
	legacy_marker_count="$(grep -Fxc -- "$LEGACY_USER_PATH_MARKER" "$bashrc_path" || true)"
	marker_count="$(grep -Fxc -- "$USER_PATH_MARKER" "$bashrc_path" || true)"

	[[ "$old_line_count" -le 1 && "$legacy_marker_count" -le 1 && "$marker_count" -le 1 ]] ||
		normalize_fail "用户 .bashrc 中存在重复或未知的 PATH 管理块。"
	[[ "$((old_line_count + legacy_marker_count + marker_count))" -le 1 ]] ||
		normalize_fail "用户 .bashrc 同时包含多个 PATH 管理块。"

	candidate_file="$(mktemp "${normalize_runtime_dir}/bashrc.XXXXXX")"
	if ! awk \
		-v legacy_marker="$LEGACY_USER_PATH_MARKER" \
		-v marker="$USER_PATH_MARKER" \
		-v marker_exists="$marker_count" \
		-v old_line="$old_line" '
		function print_path_block() {
			print marker
			print "if ! shopt -q login_shell; then"
			print "  case \":$PATH:\" in"
			print "    *\":$HOME/.local/bin:\"*) ;;"
			print "    *) export PATH=\"$HOME/.local/bin:$PATH\" ;;"
			print "  esac"
			print "fi"
		}
		$0 == old_line {
			print_path_block()
			replaced = 1
			next
		}
		$0 == legacy_marker {
			if ((getline legacy_line_1) <= 0 || legacy_line_1 != "case \":$PATH:\" in") exit 42
			if ((getline legacy_line_2) <= 0 || legacy_line_2 != "  *\":$HOME/.local/bin:\"*) ;;") exit 42
			if ((getline legacy_line_3) <= 0 || legacy_line_3 != "  *) export PATH=\"$HOME/.local/bin:$PATH\" ;;") exit 42
			if ((getline legacy_line_4) <= 0 || legacy_line_4 != "esac") exit 42
			print_path_block()
			replaced = 1
			next
		}
		{ print }
		END {
			if (!marker_exists && !replaced) {
				if (NR > 0) print ""
				print_path_block()
			}
		}
	' "$bashrc_path" >"$candidate_file"; then
		normalize_fail "用户 .bashrc 中的旧 PATH 管理块不符合预期。"
	fi

	bash -n "$candidate_file"
	normalize_apply_candidate "$candidate_file" "$bashrc_path"
}

normalize_verify() {
	local block_count
	local manual_nix_path
	local target

	for target in /etc/bash.bashrc /etc/profile.d/nix.sh; do
		block_count="$(grep -Fxc -- "$NIX_BLOCK_START" "$target" || true)"
		[[ "$block_count" -eq 1 ]] ||
			normalize_fail "规范后 Nix 初始化块数量不是 1：$target"
		bash -n "$target"
	done

	for target in /etc/bashrc /etc/zshrc; do
		[[ -f "$target" ]] || continue
		block_count="$(grep -Fxc -- "$NIX_BLOCK_START" "$target" || true)"
		[[ "$block_count" -eq 0 ]] && continue
		[[ "$block_count" -eq 1 ]] ||
			normalize_fail "规范后 Nix 初始化块数量不是 1：$target"
		bash -n "$target"
	done

	[[ "$(grep -Fxc -- "$USER_PATH_MARKER" "${NORMALIZE_USER_HOME}/.bashrc" || true)" -eq 1 ]] ||
		normalize_fail "用户 .bashrc 的 PATH 管理块验证失败。"
	manual_nix_path="${NORMALIZE_USER_HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
	[[ "$(grep -Fc -- "$manual_nix_path" "${NORMALIZE_USER_HOME}/.bashrc" || true)" -eq 0 ]] ||
		normalize_fail "用户 .bashrc 仍包含手工 Nix PATH。"
}

normalize_main() {
	trap normalize_cleanup EXIT
	normalize_parse_args "$@"
	normalize_prepare
	normalize_resolve_user_home

	normalize_log "规范系统 Nix 初始化块"
	normalize_system_file true /etc/bash.bashrc
	normalize_system_file true /etc/profile.d/nix.sh

	for optional_file in /etc/bashrc /etc/zshrc; do
		[[ -f "$optional_file" ]] || continue
		normalize_system_file false "$optional_file"
	done

	normalize_log "规范用户 Bash PATH"
	normalize_user_bashrc

	if [[ "$normalize_check_only" == true ]]; then
		if [[ "$normalize_changes_needed" == true ]]; then
			normalize_fail "检查发现需要规范的 Shell 初始化文件。"
		fi
		normalize_log "Shell 初始化检查通过"
		return
	fi

	normalize_verify
	normalize_log "Shell 初始化规范完成"
	if [[ "$normalize_changed" == true ]]; then
		printf '  备份目录：%s\n' "$normalize_backup_root"
	else
		printf '  没有需要修改的文件。\n'
	fi
}

normalize_main "$@"
