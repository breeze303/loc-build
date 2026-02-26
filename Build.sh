#!/bin/bash

# =========================================================
# WRT-CI 本地一键编译脚本 (Build.sh) - V21.5 Final Fixed
# =========================================================

ROOT_DIR=$(cd $(dirname $0) && pwd)
SCRIPTS_DIR="${ROOT_DIR}/Scripts"
[ -f "${SCRIPTS_DIR}/Ui.sh" ] && source "${SCRIPTS_DIR}/Ui.sh" || exit 1

# --- 路径设置 ---
BUILD_DIR="${ROOT_DIR}/wrt"
CONFIG_DIR="${ROOT_DIR}/Config"
PROFILES_DIR="${CONFIG_DIR}/Profiles"
LOG_DIR="${ROOT_DIR}/Logs"
AUTO_SCRIPT="${SCRIPTS_DIR}/Auto.sh"
AUTO_CONF="${CONFIG_DIR}/Auto.conf"
LAST_CONF="${CONFIG_DIR}/.last_build.conf"
REPO_LIST_FILE="${CONFIG_DIR}/REPOS.txt"
CORE_PKG_FILE="${CONFIG_DIR}/CORE_PACKAGES.txt"
CUSTOM_PKG_FILE="${CONFIG_DIR}/CUSTOM_PACKAGES.txt"
FIRMWARE_DIR="${ROOT_DIR}/Firmware"

# --- 变量初始化 ---
WRT_IP="192.168.1.1"; WRT_NAME="OpenWrt"; WRT_SSID="OpenWrt"; WRT_WORD="12345678"; WRT_THEME="argon"
SEL_REPO=""; SEL_BRANCH=""; SEL_MODEL=""
A_REPO=""; A_BRANCH=""; A_CONFIGS=(); A_KEEP_CACHE="true"; A_ITEMS=()

load_auto_conf() {
    if [ -f "$AUTO_CONF" ]; then
        source "$AUTO_CONF"
        A_REPO="$WRT_REPO"; A_BRANCH="$WRT_BRANCH"; A_KEEP_CACHE="$KEEP_CACHE"
        [[ "$(declare -p WRT_CONFIGS 2>/dev/null)" == "declare -a"* ]] && A_CONFIGS=("${WRT_CONFIGS[@]}") || A_CONFIGS=("$WRT_CONFIGS")
        [[ "$(declare -p CACHE_ITEMS 2>/dev/null)" == "declare -a"* ]] && A_ITEMS=("${CACHE_ITEMS[@]}") || A_ITEMS=()
    else
        A_REPO="https://github.com/immortalwrt/immortalwrt.git"; A_BRANCH="master"; A_CONFIGS=("X86"); A_KEEP_CACHE="true"; A_ITEMS=("dl" "staging_dir"); fi
}
load_auto_conf

show_banner() {
    clear
    echo -e "${BB}${BOLD}"
    echo "  ██████╗ ██╗   ██╗██╗██╗     ██████╗ "
    echo "  ██╔══██╗██║   ██║██║██║     ██╔══██╗"
    echo "  ██████╔╝██║   ██║██║██║     ██║  ██║"
    echo "  ██╔══██╗██║   ██║██║██║     ██║  ██║"
    echo "  ██████╔╝╚██████╔╝██║███████╗██████╔╝"
    echo "  ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ "
    echo -e "${NC}"
    echo -e " ${BC}${BOLD}  WRT-CI Dashboard${NC} ${BW}| v21.5 Stable${NC}"
    get_sys_info
    local cur_r=$(echo "${SEL_REPO:-$A_REPO}" | sed 's|https://github.com/||; s|.git||')
    echo -e " ${BC}$(T source):${NC} ${BY}${cur_r}${NC} ${BW}[${SEL_BRANCH:-$A_BRANCH}]${NC}"
    draw_line
}

# --- 归档功能 ---
archive_firmware() {
    msg_step "6"
    local target_dir=$(find "$BUILD_DIR/bin/targets/" -mindepth 2 -maxdepth 2 -type d | head -n 1)
    if [ -n "$target_dir" ]; then
        mkdir -p "$FIRMWARE_DIR"
        find "$target_dir" -type f \( -name "*.img.gz" -o -name "*.bin" -o -name "*.tar.gz" -o -name "*.itb" \) | while read -r file; do
            mv -f "$file" "$FIRMWARE_DIR/"
        done
        msg_ok "$(T done)"
    fi
}

# --- 个性化参数确认 ---
custom_settings_ui() {
    while true; do
        show_banner
        echo -e " IP: ${C}$WRT_IP${NC} | Host: ${C}$WRT_NAME${NC} | WiFi: ${C}$WRT_SSID${NC}"
        draw_line
        select_menu "$(T config_confirm)" "$(T keep_continue)" "$(T mod_ip)" "$(T mod_host)" "$(T mod_wifi)" "$(T cancel)"
        case $RET_IDX in
            0) return 0 ;;
            1) read -p " ➤ IP: " WRT_IP ;;
            2) read -p " ➤ Host: " WRT_NAME ;;
            3) read -p " ➤ SSID: " WRT_SSID; read -p " ➤ PW: " WRT_WORD ;;
            *) return 1 ;;
        esac
    done
}

# --- 编译流程 ---
compile_workflow() {
    local skip_ui=$1; [ "$skip_ui" != "true" ] && (custom_settings_ui || return)
    { echo "L_REPO=\"$SEL_REPO\""; echo "L_BRANCH=\"$SEL_BRANCH\""; echo "L_MODEL=\"$SEL_MODEL\""; echo "L_IP=\"$WRT_IP\""; } > "$LAST_CONF"
    
    local strategy="2"
    if [ -d "$BUILD_DIR/bin" ]; then
        show_banner
        select_menu "$(T strategy)" "$(T fast)" "$(T stable)" "$(T clean)" "$(T cancel)"
        res=$?; [ $res -ge 3 ] && return; strategy=$((res+1))
    fi
    
    mkdir -p "$LOG_DIR"; local LOG_FILE="${LOG_DIR}/${SEL_MODEL}-$(date +%m%d-%H%M).log"
    msg_step "1"; if [ -d "$BUILD_DIR/.git" ]; then cd "$BUILD_DIR"; [ "$strategy" != "1" ] && git checkout .; git pull 2>&1 | tee -a "$LOG_FILE" && cd "$ROOT_DIR"; else git clone --depth=1 --single-branch --branch "$SEL_BRANCH" "$SEL_REPO" "$BUILD_DIR" 2>&1 | tee -a "$LOG_FILE"; fi
    msg_step "2"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && ./scripts/feeds clean; [ -d "feeds" ] && for f in feeds/*; do [ -d "$f/.git" ] && (cd "$f" && git checkout . && git clean -fd); done; ./scripts/feeds update -a && ./scripts/feeds install -a
    msg_step "3"; export GITHUB_WORKSPACE="$ROOT_DIR"; cd "$BUILD_DIR/package" && bash "${SCRIPTS_DIR}/Packages.sh" && bash "${SCRIPTS_DIR}/Handles.sh"
    msg_step "4"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && make clean; [ "$strategy" != "1" ] && rm -f .config; cat "${CONFIG_DIR}/GENERAL.txt" >> .config; [ -f "${PROFILES_DIR}/${SEL_MODEL}.txt" ] && cat "${PROFILES_DIR}/${SEL_MODEL}.txt" >> .config; bash "${SCRIPTS_DIR}/Settings.sh"; make defconfig
    msg_step "5"; msg_info "$(T dl_msg)"; make download -j$(nproc)
    msg_info "$(T build_msg)"; if (make -j$(nproc) || make -j1 V=s) 2>&1 | tee -a "$LOG_FILE"; then msg_ok "$(T done)"; archive_firmware; read -p " $(T done). $(T press_enter)"; else msg_err "$(T fail)"; read -p " $(T fail). Log: $LOG_FILE. $(T press_enter)"; fi
}

# --- 辅助逻辑略 (保持 V21.0 稳定代码) ---
run_select_repo() { local ns=(); local us=(); while read -r n u || [ -n "$n" ]; do [[ "$n" =~ ^#.*$ || -z "$n" ]] && continue; ns+=("$n"); us+=("$u"); done < "$REPO_LIST_FILE"; show_banner; select_menu "$(T source) :" "${ns[@]}" "手动" "返回"; if [ "$RET_IDX" -lt "${#ns[@]}" ]; then SEL_REPO="${us[$RET_IDX]}"; return 0; elif [ "$RET_IDX" -eq "${#ns[@]}" ]; then read -p " ➤ URL: " ur; SEL_REPO="$ur"; return 0; fi; return 1; }
run_select_branch() { show_banner; msg_info "$(T info): $(T searching_branches)"; local raw=$(timeout 8s git ls-remote --heads "$SEL_REPO" 2>/dev/null); local all=($(echo "$raw" | awk -F'refs/heads/' '{print $2}' | sort -r)); if [ ${#all[@]} -eq 0 ]; then read -p " ➤ $(T branch): " mb; SEL_BRANCH="${mb:-master}"; return 0; else list=("${all[@]:0:20}"); show_banner; select_menu "$(T branch) :" "${list[@]}" "$(T manual)" "$(T back)"; if [ "$RET_IDX" -lt "${#list[@]}" ]; then SEL_BRANCH="${list[$RET_IDX]}"; return 0; elif [ "$RET_IDX" -eq "${#list[@]}" ]; then read -p " ➤: " mb; SEL_BRANCH="$mb"; return 0; fi; fi; return 1; }
run_select_model() { local cs=($(ls "$PROFILES_DIR/" | sed 's/\.txt$//')); show_banner; select_menu "$(T model) :" "${cs[@]}" "$(T manual)" "$(T back)"; if [ "$RET_IDX" -lt "${#cs[@]}" ]; then SEL_MODEL="${cs[$RET_IDX]}"; return 0; elif [ "$RET_IDX" -eq "${#cs[@]}" ]; then read -p " ➤: " rm; SEL_MODEL="$rm"; return 0; fi; return 1; }

manage_timer() { while true; do show_banner; select_menu "$(T timer) :" "$(T set_sched)" "$(T check_task)" "$(T term_sched)" "$(T config_pipe)" "$(T view_logs)" "$(T back)"; case $RET_IDX in 3) config_auto_build ;; 5|255) return ;; *) msg_info "..."; sleep 1 ;; esac; done; }
manage_packages() { while true; do show_banner; select_menu "$(T pkg) :" "$(T view_list)" "$(T add_pkg)" "$(T del_pkg)" "$(T edit_file)" "$(T ver_update)" "$(T back)"; case $RET_IDX in 5|255) return ;; *) msg_info "..."; sleep 1 ;; esac; done; }

# --- 主循环 ---
while true; do
    show_banner
    select_menu "$(T main_menu)" "$(T build)" "$(T rebuild)" "$(T sync)" "$(T timer)" "$(T pkg)" "$(T self)" "$(T env)" "$(T lang)" "$(T exit)"
    case $RET_IDX in
        0) run_select_repo && run_select_branch && run_select_model && compile_workflow ;;
        1) if [ -f "$LAST_CONF" ]; then source "$LAST_CONF"; SEL_REPO="$L_REPO"; SEL_BRANCH="$L_BRANCH"; SEL_MODEL="$L_MODEL"; compile_workflow "true"; else msg_warn "$(T no_history)"; sleep 1; fi ;;
        2) bash "${SCRIPTS_DIR}/Update.sh"; sleep 1 ;;
        3) manage_timer ;;
        4) manage_packages ;;
        5) msg_info "Updating..."; if git pull | grep -q "Already up to date."; then msg_ok "LATEST"; sleep 1; else exec "$0" "$@"; fi ;;
        6) sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'; read -p " $(T press_enter)" ;;
        7) [ "$CURRENT_LANG" == "zh" ] && echo "en" > "$LANG_CONF" || echo "zh" > "$LANG_CONF"; source "${SCRIPTS_DIR}/Ui.sh" ;;
        8|255) exit 0 ;;
    esac
done
