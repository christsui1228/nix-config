#!/usr/bin/env bash

set -Eeuo pipefail

BOOTSTRAP_REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_REPO_DIR
readonly BOOTSTRAP_SUPPORTED_PROFILE="wsl"
readonly BOOTSTRAP_APT_MIRROR_SCRIPT="${BOOTSTRAP_REPO_DIR}/system/ubuntu/configure-apt-mirror.sh"
readonly BOOTSTRAP_SYSTEM_PACKAGES_SCRIPT="${BOOTSTRAP_REPO_DIR}/system/ubuntu/install-packages.sh"
readonly BOOTSTRAP_NIX_SHELL_SCRIPT="${BOOTSTRAP_REPO_DIR}/system/nix/normalize-shell-init.sh"
readonly BOOTSTRAP_NIX_INSTALLER_URL="https://nixos.org/nix/install"
readonly BOOTSTRAP_NODE_RUNTIME_SCRIPT="${BOOTSTRAP_REPO_DIR}/node-tools/restore-runtime.sh"
readonly BOOTSTRAP_NODE_VERSION_FILE="${BOOTSTRAP_REPO_DIR}/node-tools/default-node-version"
readonly BOOTSTRAP_TMUX_CONFIG_SCRIPT="${BOOTSTRAP_REPO_DIR}/external-repos/restore-tmux-config.sh"

bootstrap_profile="wsl"
bootstrap_use_china_mirror=false
bootstrap_skip_docker=false
bootstrap_preflight_only=false
bootstrap_current_stage="startup"
bootstrap_runtime_dir=""
bootstrap_home_manager_activation=""

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

bootstrap_cleanup() {
	case "$bootstrap_runtime_dir" in
	/tmp/nix-config-bootstrap.*)
		rm -f -- \
			"$bootstrap_runtime_dir/install-nix.sh" \
			"$bootstrap_runtime_dir/generation"
		rmdir -- "$bootstrap_runtime_dir" 2>/dev/null || true
		;;
	esac
}

# 该函数由 ERR trap 间接调用。
# shellcheck disable=SC2329
bootstrap_on_error() {
	local exit_code="$?"
	local line_number="$1"

	printf '初始化在阶段 %s 的第 %s 行失败，退出码：%s。\n' \
		"$bootstrap_current_stage" "$line_number" "$exit_code" >&2
	exit "$exit_code"
}

bootstrap_run_stage() {
	local stage_name="$1"

	shift
	bootstrap_current_stage="$stage_name"
	bootstrap_log "阶段开始：$stage_name"
	"$@"
	bootstrap_log "阶段完成：$stage_name"
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
  已启用 preflight、可选 APT 中国镜像、系统基础包、Nix 和
  Shell 初始化规范、tmux-config SSH 恢复、Home Manager 阶段，并恢复
  声明的默认 Node runtime。Docker 和版本锁定的 Node CLI 集合尚未接入。
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

	[[ -x "$BOOTSTRAP_APT_MIRROR_SCRIPT" ]] ||
		bootstrap_fail "APT 镜像脚本不存在或不可执行：$BOOTSTRAP_APT_MIRROR_SCRIPT"

	[[ -x "$BOOTSTRAP_SYSTEM_PACKAGES_SCRIPT" ]] ||
		bootstrap_fail "系统包脚本不存在或不可执行：$BOOTSTRAP_SYSTEM_PACKAGES_SCRIPT"

	[[ -x "$BOOTSTRAP_NIX_SHELL_SCRIPT" ]] ||
		bootstrap_fail "Nix Shell 规范脚本不存在或不可执行：$BOOTSTRAP_NIX_SHELL_SCRIPT"

	[[ -x "$BOOTSTRAP_NODE_RUNTIME_SCRIPT" ]] ||
		bootstrap_fail "Node runtime 恢复脚本不存在或不可执行：$BOOTSTRAP_NODE_RUNTIME_SCRIPT"

	[[ -r "$BOOTSTRAP_NODE_VERSION_FILE" ]] ||
		bootstrap_fail "Node 版本清单不存在或不可读：$BOOTSTRAP_NODE_VERSION_FILE"

	[[ -x "$BOOTSTRAP_TMUX_CONFIG_SCRIPT" ]] ||
		bootstrap_fail "tmux-config 恢复脚本不存在或不可执行：$BOOTSTRAP_TMUX_CONFIG_SCRIPT"
}

bootstrap_check_network() {
	local network_host
	local network_url

	command -v getent >/dev/null ||
		bootstrap_fail "找不到 getent，无法执行 DNS 检查。"

	if [[ "$bootstrap_use_china_mirror" == true ]]; then
		network_host="mirrors.aliyun.com"
		network_url="https://mirrors.aliyun.com/ubuntu/dists/noble/InRelease"
	else
		network_host="archive.ubuntu.com"
		network_url="https://archive.ubuntu.com/ubuntu/dists/noble/InRelease"
	fi

	getent ahosts "$network_host" >/dev/null ||
		bootstrap_fail "DNS 无法解析：$network_host"

	if command -v curl >/dev/null; then
		curl \
			--fail \
			--head \
			--location \
			--max-time 15 \
			--silent \
			--show-error \
			"$network_url" >/dev/null ||
			bootstrap_fail "无法访问软件源：$network_url"
	else
		bootstrap_warn "尚未安装 curl，只完成 DNS 检查；连接测试交给 APT 阶段。"
	fi
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
	bootstrap_check_not_root
	bootstrap_check_profile
	bootstrap_load_os_release
	bootstrap_check_wsl
	bootstrap_check_architecture
	bootstrap_check_user
	bootstrap_check_systemd
	bootstrap_check_repository
	bootstrap_check_network
	"$BOOTSTRAP_TMUX_CONFIG_SCRIPT" --check

	printf '  profile        %s\n' "$bootstrap_profile"
	printf '  os             %s %s\n' "${PRETTY_NAME:-Ubuntu}" "${VERSION_CODENAME:-}"
	printf '  architecture   %s\n' "$(uname -m)"
	printf '  user           %s\n' "$USER"
	printf '  repository     %s\n' "$BOOTSTRAP_REPO_DIR"
	printf '  china mirror   %s\n' "$bootstrap_use_china_mirror"
	printf '  skip docker    %s\n' "$bootstrap_skip_docker"
	bootstrap_report_tools
}

bootstrap_prepare_sudo() {
	command -v sudo >/dev/null ||
		bootstrap_fail "找不到 sudo，无法执行系统阶段。"

	bootstrap_log "系统阶段需要 sudo 权限"
	sudo -v
}

bootstrap_configure_apt() {
	if [[ "$bootstrap_use_china_mirror" != true ]]; then
		printf '  未启用 --china-mirror，保留当前 Ubuntu APT 源。\n'
		return
	fi

	sudo -- "$BOOTSTRAP_APT_MIRROR_SCRIPT"
}

bootstrap_install_system_packages() {
	sudo -- "$BOOTSTRAP_SYSTEM_PACKAGES_SCRIPT"
}

bootstrap_restore_tmux_config() {
	"$BOOTSTRAP_TMUX_CONFIG_SCRIPT"
}

bootstrap_ensure_runtime_dir() {
	if [[ -n "$bootstrap_runtime_dir" ]]; then
		return
	fi

	bootstrap_runtime_dir="$(mktemp -d /tmp/nix-config-bootstrap.XXXXXX)"
}

bootstrap_load_nix_environment() {
	local profile_script

	if command -v nix >/dev/null; then
		return 0
	fi

	for profile_script in \
		/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
		"$HOME/.nix-profile/etc/profile.d/nix.sh"; do
		if [[ -r "$profile_script" ]]; then
			# shellcheck disable=SC1090
			source "$profile_script"
			break
		fi
	done

	command -v nix >/dev/null
}

bootstrap_nix() {
	command nix \
		--extra-experimental-features "nix-command flakes" \
		"$@"
}

bootstrap_verify_nix() {
	local store_info

	command -v nix >/dev/null ||
		bootstrap_fail "Nix 安装后仍找不到 nix 命令。"

	command -v nix-env >/dev/null ||
		bootstrap_fail "Nix 安装后仍找不到 nix-env 命令。"

	bootstrap_nix --version
	store_info="$(bootstrap_nix store info 2>&1)" ||
		bootstrap_fail "当前普通用户无法连接 Nix daemon。"

	printf '%s\n' "$store_info"
	grep -qx 'Store URL: daemon' <<<"$store_info" ||
		bootstrap_fail "当前 Nix 不是 multi-user daemon 模式。"
}

bootstrap_install_nix() {
	local installer_path

	if bootstrap_load_nix_environment; then
		printf '  已安装 Nix，跳过官方安装器。\n'
		bootstrap_verify_nix
		return
	fi

	if [[ -e /nix || -e /etc/nix ]]; then
		bootstrap_fail \
			"检测到 Nix 残留目录，但无法加载 nix 命令；请先人工检查，脚本不会覆盖安装。"
	fi

	command -v curl >/dev/null ||
		bootstrap_fail "缺少 curl，无法下载官方 Nix installer。"

	bootstrap_ensure_runtime_dir
	installer_path="$bootstrap_runtime_dir/install-nix.sh"

	curl \
		--fail \
		--location \
		--proto '=https' \
		--show-error \
		--silent \
		--tlsv1.2 \
		--output "$installer_path" \
		"$BOOTSTRAP_NIX_INSTALLER_URL"

	[[ -s "$installer_path" ]] ||
		bootstrap_fail "下载的 Nix installer 为空。"

	NIX_INSTALLER_NO_CHANNEL_ADD=1 \
		NIX_INSTALLER_YES=1 \
		sh "$installer_path" --daemon

	bootstrap_load_nix_environment ||
		bootstrap_fail "官方安装器执行完成，但无法加载 Nix 环境。"

	bootstrap_verify_nix
}

bootstrap_normalize_nix_shell() {
	sudo "$BOOTSTRAP_NIX_SHELL_SCRIPT" --user "$USER"
}

bootstrap_build_home_manager() {
	local build_output
	local generation_link

	bootstrap_ensure_runtime_dir
	generation_link="$bootstrap_runtime_dir/generation"

	build_output="$(
		bootstrap_nix build \
			--no-update-lock-file \
			--out-link "$generation_link" \
			--print-out-paths \
			"path:${BOOTSTRAP_REPO_DIR}#homeConfigurations.chris.activationPackage"
	)"

	[[ "$build_output" == /nix/store/*-home-manager-generation ]] ||
		bootstrap_fail "Home Manager 构建返回了意外路径：$build_output"

	[[ -x "$build_output/activate" ]] ||
		bootstrap_fail "Home Manager generation 缺少可执行的 activate。"

	[[ -f "$build_output/gen-version" ]] ||
		bootstrap_fail "Home Manager generation 缺少 gen-version。"

	bootstrap_home_manager_activation="$build_output"
	printf '  activation    %s\n' "$bootstrap_home_manager_activation"
}

bootstrap_ensure_home_manager_entrypoint() {
	local config_home
	local current_target
	local entrypoint

	config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
	entrypoint="$config_home/home-manager"

	mkdir -p -- "$config_home"

	if [[ -L "$entrypoint" ]]; then
		current_target="$(readlink -f -- "$entrypoint")"
		if [[ "$current_target" == "$BOOTSTRAP_REPO_DIR" ]]; then
			printf '  Home Manager 配置入口已经指向当前仓库。\n'
			return
		fi

		bootstrap_fail \
			"Home Manager 配置入口指向其他位置：$current_target"
	fi

	if [[ -e "$entrypoint" ]]; then
		bootstrap_fail \
			"Home Manager 配置入口已存在且不是软链接：$entrypoint"
	fi

	ln -s -- "$BOOTSTRAP_REPO_DIR" "$entrypoint"
	printf '  创建配置入口：%s -> %s\n' "$entrypoint" "$BOOTSTRAP_REPO_DIR"
}

bootstrap_activate_home_manager() {
	local current_generation
	local profile
	local profile_dir
	local profile_changed=false

	[[ -n "$bootstrap_home_manager_activation" ]] ||
		bootstrap_fail "尚未构建 Home Manager，拒绝激活。"

	bootstrap_ensure_home_manager_entrypoint

	profile_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"
	profile="$profile_dir/home-manager"
	mkdir -p -- "$profile_dir"

	current_generation="$(readlink -f -- "$profile" 2>/dev/null || true)"
	if [[ "$current_generation" == "$bootstrap_home_manager_activation" ]]; then
		printf '  Home Manager profile 已是当前 generation，不创建重复 generation。\n'
	else
		nix-env \
			--profile "$profile" \
			--set "$bootstrap_home_manager_activation"
		profile_changed=true
	fi

	if "$bootstrap_home_manager_activation/activate" --driver-version 1; then
		return
	fi

	if [[ "$profile_changed" == true && -n "$current_generation" ]]; then
		bootstrap_warn "新配置激活失败，正在恢复上一个 Home Manager generation。"
		nix-env --profile "$profile" --set "$current_generation"
		"$current_generation/activate" --driver-version 1 ||
			bootstrap_warn "旧 generation 自动恢复失败，请人工执行 Home Manager 回滚。"
	fi

	bootstrap_fail "Home Manager 激活失败。"
}

bootstrap_restore_node_tools() {
	local fnm_bin

	[[ -n "$bootstrap_home_manager_activation" ]] ||
		bootstrap_fail "尚未构建 Home Manager，拒绝恢复 Node runtime。"

	fnm_bin="$bootstrap_home_manager_activation/home-path/bin/fnm"
	[[ -x "$fnm_bin" ]] ||
		bootstrap_fail "Home Manager generation 中找不到 fnm。"

	FNM_BIN="$fnm_bin" "$BOOTSTRAP_NODE_RUNTIME_SCRIPT"
}

bootstrap_postflight() {
	local actual_node_version
	local declared_node_version
	local fnm_bin
	local home_manager_bin
	local profile
	local tmux_bin
	local tmux_config_link
	local tmux_local_config_link
	local tmux_nix_plugins_link

	profile="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
	home_manager_bin="$bootstrap_home_manager_activation/home-path/bin/home-manager"
	fnm_bin="$bootstrap_home_manager_activation/home-path/bin/fnm"
	tmux_bin="$bootstrap_home_manager_activation/home-path/bin/tmux"
	tmux_config_link="$(readlink -- "$HOME/.tmux.conf" 2>/dev/null || true)"
	tmux_local_config_link="$(readlink -- "$HOME/.tmux.conf.local" 2>/dev/null || true)"
	tmux_nix_plugins_link="$(readlink -- "$HOME/.config/tmux/nix-plugins.conf" 2>/dev/null || true)"

	bootstrap_verify_nix

	[[ "$(readlink -f -- "$profile" 2>/dev/null || true)" == "$bootstrap_home_manager_activation" ]] ||
		bootstrap_fail "Home Manager profile 没有指向刚刚构建的 generation。"

	[[ -x "$home_manager_bin" ]] ||
		bootstrap_fail "激活后的用户环境中找不到 home-manager。"

	"$home_manager_bin" --version

	[[ -x "$tmux_bin" ]] ||
		bootstrap_fail "激活后的用户环境中找不到 tmux。"

	[[ "$tmux_config_link" == /nix/store/*-home-manager-files/.tmux.conf ]] ||
		bootstrap_fail "$HOME/.tmux.conf 尚未由 Home Manager 管理。"

	[[ "$tmux_local_config_link" == /nix/store/*-home-manager-files/.tmux.conf.local ]] ||
		bootstrap_fail "$HOME/.tmux.conf.local 尚未由 Home Manager 管理。"

	[[ "$tmux_nix_plugins_link" == /nix/store/*-home-manager-files/.config/tmux/nix-plugins.conf ]] ||
		bootstrap_fail "$HOME/.config/tmux/nix-plugins.conf 尚未由 Home Manager 管理。"

	[[ "$(readlink -f -- "$HOME/.tmux.conf" 2>/dev/null || true)" == "$HOME/tmux-config/.tmux.conf" ]] ||
		bootstrap_fail "$HOME/.tmux.conf 没有指向 tmux-config。"

	[[ "$(readlink -f -- "$HOME/.tmux.conf.local" 2>/dev/null || true)" == "$HOME/tmux-config/.tmux.conf.local" ]] ||
		bootstrap_fail "$HOME/.tmux.conf.local 没有指向 tmux-config。"

	IFS= read -r declared_node_version <"$BOOTSTRAP_NODE_VERSION_FILE"
	actual_node_version="$(
		"$fnm_bin" exec --using "$declared_node_version" node --version
	)"
	[[ "$actual_node_version" == "v$declared_node_version" ]] ||
		bootstrap_fail \
			"postflight Node 版本不匹配：期望 v$declared_node_version，实际 $actual_node_version"

	printf '  Home Manager profile 验证完成。\n'
	printf '  tmux 与外部配置链接验证完成：%s\n' "$("$tmux_bin" -V)"
	printf '  默认 Node runtime 验证完成：%s\n' "$actual_node_version"
}

bootstrap_report_partial_completion() {
	if [[ "$bootstrap_skip_docker" == true ]]; then
		bootstrap_warn \
			"已按 --skip-docker 跳过 Docker；版本锁定的 Node CLI 集合尚未接入。"
	else
		bootstrap_warn "Docker 和版本锁定的 Node CLI 集合尚未接入 bootstrap。"
	fi
}

bootstrap_main() {
	trap 'bootstrap_on_error "$LINENO"' ERR
	trap bootstrap_cleanup EXIT

	bootstrap_parse_args "$@"
	bootstrap_run_stage "preflight" bootstrap_preflight

	if [[ "$bootstrap_preflight_only" == true ]]; then
		exit 0
	fi

	bootstrap_run_stage "prepare_sudo" bootstrap_prepare_sudo
	bootstrap_run_stage "configure_apt" bootstrap_configure_apt
	bootstrap_run_stage "install_system_packages" bootstrap_install_system_packages
	bootstrap_run_stage "restore_tmux_config" bootstrap_restore_tmux_config
	bootstrap_run_stage "install_nix" bootstrap_install_nix
	bootstrap_run_stage "normalize_nix_shell" bootstrap_normalize_nix_shell
	bootstrap_run_stage "build_home_manager" bootstrap_build_home_manager
	bootstrap_run_stage "activate_home_manager" bootstrap_activate_home_manager
	bootstrap_run_stage "restore_node_tools" bootstrap_restore_node_tools
	bootstrap_run_stage "postflight" bootstrap_postflight
	bootstrap_report_partial_completion
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	bootstrap_main "$@"
fi
