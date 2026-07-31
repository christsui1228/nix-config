#!/usr/bin/env bash

set -Eeuo pipefail

readonly TMUX_MIGRATION_BIN="${HOME}/.nix-profile/bin/tmux"
readonly TMUX_MIGRATION_PLUGIN_CONFIG="${HOME}/.config/tmux/nix-plugins.conf"
readonly TMUX_MIGRATION_PLACEHOLDER_SESSION="nix-config-restore"
readonly TMUX_MIGRATION_MAX_SNAPSHOT_AGE=86400

tmux_migration_mode="check"
tmux_migration_snapshot=""
tmux_migration_snapshot_session=""
tmux_migration_server_version=""
tmux_migration_client_version=""
tmux_migration_blockers=()

tmux_migration_log() {
	printf '\n==> %s\n' "$*"
}

tmux_migration_fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

tmux_migration_usage() {
	cat <<'EOF'
用法：
  ./tmux-tools/finish-server-migration.sh --check
  ./tmux-tools/finish-server-migration.sh --switch

选项：
  --check   只检查旧 server、前台任务和 Resurrect 快照
  --switch  从 tmux 外停止旧 server，启动新 server 并恢复快照
  -h, --help

--switch 检测到 node、nvim 等非交互 Shell 命令时会拒绝停止旧 server。
EOF
}

tmux_migration_parse_args() {
	while (($# > 0)); do
		case "$1" in
		--check)
			tmux_migration_mode="check"
			shift
			;;
		--switch)
			tmux_migration_mode="switch"
			shift
			;;
		-h | --help)
			tmux_migration_usage
			exit 0
			;;
		*)
			tmux_migration_fail "未知参数：$1"
			;;
		esac
	done
}

tmux_migration_check_user() {
	[[ "$(id -u)" -ne 0 ]] ||
		tmux_migration_fail "请使用普通用户运行，不要使用 sudo。"

	[[ "${USER:-}" == "chris" && "$HOME" == "/home/chris" ]] ||
		tmux_migration_fail "当前脚本只支持用户 chris。"
}

tmux_migration_check_client() {
	local resolved_bin

	[[ -x "$TMUX_MIGRATION_BIN" ]] ||
		tmux_migration_fail "找不到 Home Manager 安装的 tmux：$TMUX_MIGRATION_BIN"

	resolved_bin="$(readlink -f -- "$TMUX_MIGRATION_BIN")"
	[[ "$resolved_bin" == /nix/store/*-tmux-*/bin/tmux ]] ||
		tmux_migration_fail "tmux 没有解析到 Nix store：$resolved_bin"

	tmux_migration_client_version="$("$TMUX_MIGRATION_BIN" -V | awk '{print $2}')"
	printf '  client         tmux %s\n' "$tmux_migration_client_version"
	printf '  client path    %s\n' "$resolved_bin"
}

tmux_migration_find_snapshot() {
	local now
	local snapshot_age
	local snapshot_dir

	if [[ -d "$HOME/.tmux/resurrect" ]]; then
		snapshot_dir="$HOME/.tmux/resurrect"
	else
		snapshot_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
	fi

	tmux_migration_snapshot="$(readlink -f -- "$snapshot_dir/last" 2>/dev/null || true)"
	[[ -n "$tmux_migration_snapshot" && -s "$tmux_migration_snapshot" ]] ||
		tmux_migration_fail "找不到有效的 Resurrect last 快照：$snapshot_dir/last"

	tmux_migration_snapshot_session="$(
		awk -F '\t' '
			$1 == "state" && $2 != "" { print $2; exit }
			$1 == "window" && fallback == "" { fallback = $2 }
			END { if (NR > 0 && fallback != "") print fallback }
		' "$tmux_migration_snapshot" |
			head -1
	)"
	[[ -n "$tmux_migration_snapshot_session" ]] ||
		tmux_migration_fail "快照中找不到可恢复的 session。"

	now="$(date +%s)"
	snapshot_age="$((now - $(stat -c %Y "$tmux_migration_snapshot")))"
	((snapshot_age >= 0 && snapshot_age <= TMUX_MIGRATION_MAX_SNAPSHOT_AGE)) ||
		tmux_migration_fail "Resurrect 快照超过 24 小时，请重新审查后再切换。"

	printf '  snapshot       %s\n' "$tmux_migration_snapshot"
	printf '  restore target %s\n' "$tmux_migration_snapshot_session"
	printf '  snapshot age   %s seconds\n' "$snapshot_age"
}

tmux_migration_check_server() {
	tmux_migration_server_version="$(
		"$TMUX_MIGRATION_BIN" display-message -p '#{version}' 2>/dev/null || true
	)"

	if [[ -z "$tmux_migration_server_version" ]]; then
		printf '  server         not running\n'
		return
	fi

	printf '  server         tmux %s\n' "$tmux_migration_server_version"
	printf '  sessions:\n'
	"$TMUX_MIGRATION_BIN" list-sessions
}

tmux_migration_collect_blockers() {
	local pane_command
	local pane_description

	tmux_migration_blockers=()
	[[ -n "$tmux_migration_server_version" ]] || return

	while IFS=$'\t' read -r pane_command pane_description; do
		case "$pane_command" in
		bash | dash | fish | nu | sh | zsh)
			;;
		*)
			tmux_migration_blockers+=("$pane_description")
			;;
		esac
	done < <(
		"$TMUX_MIGRATION_BIN" list-panes -a -F \
			'#{pane_current_command}	#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path}'
	)

	if ((${#tmux_migration_blockers[@]} > 0)); then
		printf '  blocking panes:\n'
		printf '    %s\n' "${tmux_migration_blockers[@]}"
	else
		printf '  blocking panes none\n'
	fi
}

tmux_migration_wait_for_session() {
	local attempt=0
	local session_name="$1"

	while ((attempt < 20)); do
		if "$TMUX_MIGRATION_BIN" has-session -t "$session_name" 2>/dev/null; then
			return 0
		fi
		sleep 0.25
		attempt=$((attempt + 1))
	done

	return 1
}

tmux_migration_restore_snapshot() {
	local resurrect_entry
	local restore_script

	[[ -r "$TMUX_MIGRATION_PLUGIN_CONFIG" ]] ||
		tmux_migration_fail "找不到 Nix 插件配置：$TMUX_MIGRATION_PLUGIN_CONFIG"

	resurrect_entry="$(
		awk '$1 == "run-shell" && $2 ~ /resurrect\.tmux$/ { print $2; exit }' \
			"$TMUX_MIGRATION_PLUGIN_CONFIG"
	)"
	restore_script="${resurrect_entry%/resurrect.tmux}/scripts/restore.sh"
	[[ -x "$restore_script" ]] ||
		tmux_migration_fail "找不到锁定的 Resurrect restore.sh。"

	if tmux_migration_wait_for_session "$tmux_migration_snapshot_session"; then
		printf '  Continuum 已自动恢复 session。\n'
		return
	fi

	PATH="$HOME/.nix-profile/bin:$PATH" "$restore_script" quiet || true
	tmux_migration_wait_for_session "$tmux_migration_snapshot_session" ||
		tmux_migration_fail \
			"新 server 已启动，但 Resurrect 没有恢复 session；保留占位 session 供人工检查。"
}

tmux_migration_switch_server() {
	local new_server_version

	[[ -z "${TMUX:-}" ]] ||
		tmux_migration_fail "--switch 必须从 tmux 外的新终端运行。"

	((${#tmux_migration_blockers[@]} == 0)) ||
		tmux_migration_fail "仍有前台任务，拒绝停止 tmux server。"

	if [[ "$tmux_migration_server_version" == "$tmux_migration_client_version" ]]; then
		printf '  server 已是 tmux %s，无需切换。\n' "$tmux_migration_client_version"
		return
	fi

	if [[ -n "$tmux_migration_server_version" ]]; then
		tmux_migration_log "停止 tmux $tmux_migration_server_version server"
		"$TMUX_MIGRATION_BIN" kill-server
	fi

	tmux_migration_log "启动 tmux $tmux_migration_client_version server"
	env \
		-u TMUX \
		-u TMUX_PANE \
		-u TMUX_PROGRAM \
		-u TMUX_SOCKET \
		"$TMUX_MIGRATION_BIN" \
		new-session \
		-d \
		-s "$TMUX_MIGRATION_PLACEHOLDER_SESSION" \
		-c "$HOME"

	new_server_version="$("$TMUX_MIGRATION_BIN" display-message -p '#{version}')"
	[[ "$new_server_version" == "$tmux_migration_client_version" ]] ||
		tmux_migration_fail \
			"新 server 版本不匹配：期望 $tmux_migration_client_version，实际 $new_server_version"

	tmux_migration_restore_snapshot

	if [[ "$tmux_migration_snapshot_session" != "$TMUX_MIGRATION_PLACEHOLDER_SESSION" ]] &&
		"$TMUX_MIGRATION_BIN" has-session -t "$TMUX_MIGRATION_PLACEHOLDER_SESSION" 2>/dev/null; then
		"$TMUX_MIGRATION_BIN" kill-session -t "$TMUX_MIGRATION_PLACEHOLDER_SESSION"
	fi

	printf '\n切换完成：tmux %s\n' "$new_server_version"
	printf '连接恢复会话：tmux attach-session -t %q\n' "$tmux_migration_snapshot_session"
}

tmux_migration_main() {
	tmux_migration_parse_args "$@"
	tmux_migration_check_user

	tmux_migration_log "检查 tmux server 迁移条件"
	tmux_migration_check_client
	tmux_migration_find_snapshot
	tmux_migration_check_server
	tmux_migration_collect_blockers

	if [[ "$tmux_migration_mode" == "check" ]]; then
		if ((${#tmux_migration_blockers[@]} > 0)); then
			printf '\n尚未满足切换条件；请先正常退出上述前台任务。\n'
			exit 2
		fi
		printf '\n已满足切换条件，可从 tmux 外运行 --switch。\n'
		return
	fi

	tmux_migration_switch_server
}

tmux_migration_main "$@"
