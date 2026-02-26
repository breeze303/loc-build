#!/bin/bash

# =========================================================
# WRT-CI 本地一键编译脚本 (Build.sh) - V13.0 Logger
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

# --- 状态变量 ---
WRT_IP="192.168.1.1"; WRT_NAME="OpenWrt"; WRT_SSID="OpenWrt"; WRT_WORD="12345678"; WRT_THEME="argon"
SEL_REPO=""; SEL_BRANCH=""; SEL_MODEL=""

load_auto_conf() {
    if [ -f "$AUTO_CONF" ]; then source "$AUTO_CONF"; A_REPO="$WRT_REPO"; A_BRANCH="$WRT_BRANCH"
    else A_REPO="https://github.com/immortalwrt/immortalwrt.git"; A_BRANCH="master"; fi
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
    echo -e " ${BC}${BOLD}  WRT-CI Dashboard${NC} ${BW}| v13.0 Logger${NC}"
    get_sys_info
    local cur_r=$(echo "${SEL_REPO:-$A_REPO}" | sed 's|https://github.com/||; s|.git||')
    echo -e " ${BC}$(T source):${NC} ${BY}${cur_r}${NC} ${BW}[${SEL_BRANCH:-$A_BRANCH}]${NC}"
    draw_line
}

# --- 功能逻辑: 保存与归档 ---
save_last_build() {
    { echo "L_REPO=\"$SEL_REPO\""; echo "L_BRANCH=\"$SEL_BRANCH\""; echo "L_MODEL=\"$SEL_MODEL\""
      echo "L_IP=\"$WRT_IP\""; echo "L_NAME=\"$WRT_NAME\""; echo "L_SSID=\"$WRT_SSID\""
      echo "L_WORD=\"$WRT_WORD\""; echo "L_THEME=\"$WRT_THEME\""; } > "$LAST_CONF"
}

archive_firmware() {
    msg_step "6"; local date=$(date +"%y.%m.%d")
    local target_dir=$(find "$BUILD_DIR/bin/targets/" -type d -mindepth 2 -maxdepth 2 | head -n 1)
    if [ -n "$target_dir" ]; then
        mkdir -p "$FIRMWARE_DIR"
        find "$target_dir" -type f \( -name "*.img.gz" -o -name "*.bin" -o -name "*.tar.gz" \) | while read -r file; do
            local ext="${file##*.}"
            cp "$file" "$FIRMWARE_DIR/WRT-${WRT_CONFIG:-OpenWrt}-${date}.${ext}"
        done
        msg_ok "固件已提取至: $FIRMWARE_DIR"
    fi
}

# --- 执行编译流水线 (集成日志记录) ---
compile_workflow() {
    local skip_ui=$1
    [ "$skip_ui" != "true" ] && (custom_settings_ui || return)
    save_last_build
    
    # 策略选择
    local strategy="2"; if [ -d "$BUILD_DIR/bin" ]; then show_banner; select_menu "策略 :" "增量快编" "标准更新" "深度清理" "取消"; [ "$RET_IDX" -ge 3 ] && return; strategy=$((RET_IDX+1)); fi
    
    # 初始化日志
    mkdir -p "$LOG_DIR"
    local build_date=$(date +"%Y%m%d-%H%M")
    local LOG_FILE="${LOG_DIR}/${SEL_MODEL}-${build_date}.log"
    msg_info "编译日志将实时保存至: $LOG_FILE"
    sleep 1

    msg_step "1"; if [ -d "$BUILD_DIR/.git" ]; then cd "$BUILD_DIR"; [ "$strategy" != "1" ] && git checkout .; git pull 2>&1 | tee -a "$LOG_FILE" && cd "$ROOT_DIR"; else git clone --depth=1 --single-branch --branch "$SEL_BRANCH" "$SEL_REPO" "$BUILD_DIR" 2>&1 | tee -a "$LOG_FILE"; fi
    
    msg_step "2"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && ./scripts/feeds clean 2>&1 | tee -a "$LOG_FILE"
    [ -d "feeds" ] && for f in feeds/*; do [ -d "$f/.git" ] && (cd "$f" && git checkout . && git clean -fd); done
    ./scripts/feeds update -a 2>&1 | tee -a "$LOG_FILE" && ./scripts/feeds install -a 2>&1 | tee -a "$LOG_FILE"

    msg_step "3"; export GITHUB_WORKSPACE="$ROOT_DIR"; cd "$BUILD_DIR/package" && bash "${SCRIPTS_DIR}/Packages.sh" 2>&1 | tee -a "$LOG_FILE" && bash "${SCRIPTS_DIR}/Handles.sh" 2>&1 | tee -a "$LOG_FILE"

    msg_step "4"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && make clean
    [ "$strategy" != "1" ] && rm -f .config
    cat "${CONFIG_DIR}/GENERAL.txt" >> .config; [ -f "${PROFILES_DIR}/${SEL_MODEL}.txt" ] && cat "${PROFILES_DIR}/${SEL_MODEL}.txt" >> .config
    export WRT_IP WRT_NAME WRT_SSID WRT_WORD WRT_THEME WRT_DATE=$(date +"%y.%m.%d") WRT_MARK="Local"
    bash "${SCRIPTS_DIR}/Settings.sh"; msg_info "Generating config..."; make defconfig 2>&1 | tee -a "$LOG_FILE"
    
    msg_step "5"
    msg_info "$(T dl_msg)"
    make download -j$(nproc) 2>&1 | tee -a "$LOG_FILE"
    
    msg_info "$(T build_msg)"
    # 执行最终编译
    if (make -j$(nproc) || make -j1 V=s) 2>&1 | tee -a "$LOG_FILE"; then
        msg_ok "$(T done)"
        archive_firmware
        echo -e "\n  ${BG}[SUCCESS]${NC} 编译圆满完成！固件已就绪。"
        read -p "  按回车键返回主菜单..."
    else
        echo -e "\n  ${BR}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
        echo -e "  ${BR}[ ERROR ] 编译流程在 Step 5 发生致命错误！${NC}"
        echo -e "  ${BR}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
        msg_err "$(T fail)"
        msg_info "报错日志路径: ${BOLD}$LOG_FILE${NC}"
        echo -e "  ${BY}提示: 请检查日志末尾的 Error 关键字定位问题。${NC}"
        draw_line
        read -p "  请阅读上方报错信息，按回车键返回主菜单..."
    fi
}

# --- 其他功能逻辑 (补全) ---
custom_settings_ui() {
    while true; do
        show_banner; echo -e " ${BP}[ $(T step4) - Config Confirm ]${NC}"
        echo -e " IP: $WRT_IP | Host: $WRT_NAME | WiFi: $WRT_SSID"
        draw_line
        select_menu "Action :" "保持默认并继续" "修改 IP 地址" "修改主机名称" "修改 WiFi 设置" "取消编译"
        case $RET_IDX in 0) return 0;; 1) read -p " ➤ IP: " WRT_IP;; 2) read -p " ➤ Host: " WRT_NAME;; 3) read -p " ➤ SSID: " WRT_SSID; read -p " ➤ Pass: " WRT_WORD;; *) return 1;; esac
    done
}

run_select_repo() { local ns=(); local us=(); while read -r n u || [ -n "$n" ]; do [[ "$n" =~ ^#.*$ || -z "$n" ]] && continue; ns+=("$n"); us+=("$u"); done < "$REPO_LIST_FILE"; show_banner; select_menu "$(T source)" "${ns[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#ns[@]} + 1)) ] && return 1; [ "$RET_IDX" -lt "${#ns[@]}" ] && SEL_REPO="${us[$RET_IDX]}" || read -p " ➤ URL: " SEL_REPO; return 0; }
run_select_branch() { show_banner; msg_info "探测分支..."; local raw=$(timeout 8s git ls-remote --heads "$SEL_REPO" 2>/dev/null); local all=($(echo "$raw" | awk -F'refs/heads/' '{print $2}' | sort -r)); if [ ${#all[@]} -eq 0 ]; then read -p " ➤ $(T branch): " mb; SEL_BRANCH="${mb:-master}"; else list=("${all[@]:0:20}"); show_banner; select_menu "Branch :" "${list[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#list[@]} + 1)) ] && return 1; [ "$RET_IDX" -lt "${#list[@]}" ] && SEL_BRANCH="${list[$RET_IDX]}" || read -p " ➤: " SEL_BRANCH; fi; return 0; }
run_select_model() { local cs=($(ls "$PROFILES_DIR/" | sed 's/\.txt$//')); show_banner; select_menu "Model :" "${cs[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#cs[@]} + 1)) ] && return 1; [ "$RET_IDX" -lt "${#cs[@]}" ] && SEL_MODEL="${cs[$RET_IDX]}" || read -p " ➤ Name: " SEL_MODEL; return 0; }

# --- 主程序入口 ---
while true; do
    show_banner; select_menu "$(T main_menu)" "启动全流程交互编译" "一键再次重编上个机型" "仅同步代码与插件" "调度任务管理中心" "插件管理与维护" "系统脚本自更新" "初始化编译环境" "切换显示语言" "结束当前会话"
    case $RET_IDX in
        0) run_select_repo && run_select_branch && run_select_model && compile_workflow ;;
        1) if [ -f "$LAST_CONF" ]; then source "$LAST_CONF"; SEL_REPO="$L_REPO"; SEL_BRANCH="$L_BRANCH"; SEL_MODEL="$L_MODEL"; compile_workflow "true"; else msg_warn "NONE"; sleep 1; fi ;;
        2) bash "${SCRIPTS_DIR}/Update.sh"; sleep 1 ;;
        3) # manage_timer 逻辑
           msg_info "Timer Mode..."; sleep 1 ;;
        4) # manage_packages 逻辑
           msg_info "Package Mode..."; sleep 1 ;;
        5) msg_info "Checking update..."; git pull && (msg_ok "OK"; exit 0) || msg_err "FAIL"; sleep 1 ;;
        6) sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'; read -p " Enter..." ;;
        7) [ "$CURRENT_LANG" == "zh" ] && echo "en" > "$LANG_CONF" || echo "zh" > "$LANG_CONF"; source "${SCRIPTS_DIR}/Ui.sh" ;;
        8|255) exit 0 ;;
    esac
done
