#!/usr/bin/env bash

set -Eeuo pipefail

readonly TMUX_CONFIG_REPOSITORY_URL="git@github.com:christsui1228/tmux-config.git"
readonly TMUX_CONFIG_TARGET="${HOME}/tmux-config"
readonly TMUX_CONFIG_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"

tmux_config_mode="restore"
tmux_config_runtime_dir=""

tmux_config_log() {
	printf '\n==> %s\n' "$*"
}

tmux_config_warn() {
	printf '警告：%s\n' "$*" >&2
}

tmux_config_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

tmux_config_cleanup() {
	case "$tmux_config_runtime_dir" in
	"${HOME}"/.tmux-config.restore.*)
		rm -rf -- "$tmux_config_runtime_dir"
		;;
	esac
}

tmux_config_usage() {
	cat <<'EOF'
用法：
  ./external-repos/restore-tmux-config.sh [--check]

选项：
  --check    只检查本地仓库；缺少仓库时只验证 SSH 读取权限
  -h, --help 显示帮助

恢复模式只会在 ~/tmux-config 不存在时通过 SSH 克隆仓库。已有正确仓库
只验证，不会执行 fetch、pull、reset 或 checkout。
EOF
}

tmux_config_parse_args() {
	while (($# > 0)); do
		case "$1" in
		--check)
			tmux_config_mode="check"
			shift
			;;
		-h | --help)
			tmux_config_usage
			exit 0
			;;
		*)
			tmux_config_fail "未知参数：$1"
			;;
		esac
	done
}

tmux_config_check_user() {
	[[ "$(id -u)" -ne 0 ]] ||
		tmux_config_fail "请使用普通用户运行，不要使用 sudo。"

	[[ "${USER:-}" == "chris" ]] ||
		tmux_config_fail "当前配置要求用户 chris，检测到：${USER:-unknown}。"

	[[ "$HOME" == "/home/chris" ]] ||
		tmux_config_fail "当前配置要求 HOME=/home/chris，检测到：$HOME。"
}

tmux_config_check_tools() {
	command -v git >/dev/null ||
		tmux_config_fail "找不到 git。请先安装 Git，再恢复外部配置仓库。"

	command -v ssh >/dev/null ||
		tmux_config_fail "找不到 ssh。请先安装 OpenSSH client。"
}

tmux_config_validate_repository() {
	local actual_remote
	local actual_top_level
	local repository_path="$1"

	[[ ! -L "$repository_path" ]] ||
		tmux_config_fail "仓库路径不能是符号链接：$repository_path"

	[[ -d "$repository_path" ]] ||
		tmux_config_fail "仓库路径不是目录：$repository_path"

	git -C "$repository_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
		tmux_config_fail "目标目录不是 Git 工作树：$repository_path"

	actual_top_level="$(git -C "$repository_path" rev-parse --show-toplevel)"
	[[ "$(readlink -f -- "$actual_top_level")" == "$(readlink -f -- "$repository_path")" ]] ||
		tmux_config_fail "目标目录不是仓库顶层：$repository_path"

	actual_remote="$(git -C "$repository_path" remote get-url origin 2>/dev/null || true)"
	[[ "$actual_remote" == "$TMUX_CONFIG_REPOSITORY_URL" ]] ||
		tmux_config_fail \
			"origin 不匹配：期望 $TMUX_CONFIG_REPOSITORY_URL，实际 ${actual_remote:-未设置}"

	git -C "$repository_path" \
		ls-files --error-unmatch .tmux.conf .tmux.conf.local >/dev/null 2>&1 ||
		tmux_config_fail "仓库没有跟踪 .tmux.conf 和 .tmux.conf.local。"

	[[ -r "$repository_path/.tmux.conf" ]] ||
		tmux_config_fail "无法读取：$repository_path/.tmux.conf"

	[[ -r "$repository_path/.tmux.conf.local" ]] ||
		tmux_config_fail "无法读取：$repository_path/.tmux.conf.local"
}

tmux_config_report_repository() {
	local commit
	local dirty_state

	commit="$(git -C "$TMUX_CONFIG_TARGET" rev-parse --short=12 HEAD)"
	dirty_state="$(git -C "$TMUX_CONFIG_TARGET" status --porcelain)"

	printf '  repository     %s\n' "$TMUX_CONFIG_TARGET"
	printf '  origin         %s\n' "$TMUX_CONFIG_REPOSITORY_URL"
	printf '  commit         %s\n' "$commit"

	if [[ -n "$dirty_state" ]]; then
		tmux_config_warn "仓库有本地修改；已保留，不会自动更新。"
	else
		printf '  worktree       clean\n'
	fi
}

tmux_config_check_remote_access() {
	tmux_config_log "验证 tmux-config SSH 读取权限"

	GIT_TERMINAL_PROMPT=0 \
		GIT_SSH_COMMAND="$TMUX_CONFIG_SSH_COMMAND" \
		git ls-remote \
		--exit-code \
		"$TMUX_CONFIG_REPOSITORY_URL" \
		HEAD >/dev/null ||
		tmux_config_fail \
			"无法通过 SSH 读取 tmux-config；请先恢复 SSH Key、known_hosts 并加载密钥。"

	printf '  SSH 读取权限正常。\n'
}

tmux_config_clone_repository() {
	local clone_path

	tmux_config_runtime_dir="$(mktemp -d "${HOME}/.tmux-config.restore.XXXXXX")"
	clone_path="$tmux_config_runtime_dir/repository"

	tmux_config_log "克隆 tmux-config"
	GIT_TERMINAL_PROMPT=0 \
		GIT_SSH_COMMAND="$TMUX_CONFIG_SSH_COMMAND" \
		git clone \
		--origin origin \
		-- \
		"$TMUX_CONFIG_REPOSITORY_URL" \
		"$clone_path"

	tmux_config_validate_repository "$clone_path"

	[[ ! -e "$TMUX_CONFIG_TARGET" && ! -L "$TMUX_CONFIG_TARGET" ]] ||
		tmux_config_fail "克隆期间目标路径被创建，拒绝覆盖：$TMUX_CONFIG_TARGET"

	mv -T -- "$clone_path" "$TMUX_CONFIG_TARGET"
	rmdir -- "$tmux_config_runtime_dir"
	tmux_config_runtime_dir=""

	tmux_config_validate_repository "$TMUX_CONFIG_TARGET"
	tmux_config_report_repository
}

tmux_config_main() {
	trap tmux_config_cleanup EXIT

	tmux_config_parse_args "$@"
	tmux_config_check_user
	tmux_config_check_tools

	if [[ -e "$TMUX_CONFIG_TARGET" || -L "$TMUX_CONFIG_TARGET" ]]; then
		tmux_config_validate_repository "$TMUX_CONFIG_TARGET"
		tmux_config_log "已有正确的 tmux-config，跳过网络更新"
		tmux_config_report_repository
		return
	fi

	tmux_config_check_remote_access

	if [[ "$tmux_config_mode" == "check" ]]; then
		printf '  本地仓库尚不存在；正式恢复时将完整克隆到 %s。\n' \
			"$TMUX_CONFIG_TARGET"
		return
	fi

	tmux_config_clone_repository
}

tmux_config_main "$@"
