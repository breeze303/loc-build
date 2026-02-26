#!/bin/bash

# =========================================================
# WRT-CI 本地一键编译脚本 (Build.sh) - V10.2 Logic Fixed
# =========================================================

ROOT_DIR=$(cd $(dirname $0) && pwd)
SCRIPTS_DIR="${ROOT_DIR}/Scripts"
[ -f "${SCRIPTS_DIR}/Ui.sh" ] && source "${SCRIPTS_DIR}/Ui.sh" || exit 1

# --- 路径设置 ---
BUILD_DIR="${ROOT_DIR}/wrt"
CONFIG_DIR="${ROOT_DIR}/Config"
PROFILES_DIR="${CONFIG_DIR}/Profiles"
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
A_REPO=""; A_BRANCH=""; A_CONFIGS=(); A_KEEP_CACHE="true"; A_ITEMS=()

load_auto_conf() {
    if [ -f "$AUTO_CONF" ]; then
        source "$AUTO_CONF"
        A_REPO="$WRT_REPO"; A_BRANCH="$WRT_BRANCH"; A_KEEP_CACHE="$KEEP_CACHE"
        [[ "$(declare -p WRT_CONFIGS 2>/dev/null)" == "declare -a"* ]] && A_CONFIGS=("${WRT_CONFIGS[@]}") || A_CONFIGS=("$WRT_CONFIGS")
        [[ "$(declare -p CACHE_ITEMS 2>/dev/null)" == "declare -a"* ]] && A_ITEMS=("${CACHE_ITEMS[@]}") || A_ITEMS=()
    else
        A_REPO="https://github.com/immortalwrt/immortalwrt.git"; A_BRANCH="master"; A_CONFIGS=("X86"); A_KEEP_CACHE="true"; A_ITEMS=("dl" "staging_dir")
    fi
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
    echo -e " ${BC}${BOLD}  WRT-CI Dashboard${NC} ${BW}| v10.2 Final${NC}"
    get_sys_info
    local cur_r=$(echo "${SEL_REPO:-$A_REPO}" | sed 's|https://github.com/||; s|.git||')
    echo -e " ${BC}$(T source):${NC} ${BY}${cur_r}${NC} ${BW}[${SEL_BRANCH:-$A_BRANCH}]${NC}"
    draw_line
}

# --- 核心子模块: 插件中心 (修复清单不显示问题) ---
manage_packages() {
    while true; do
        show_banner
        select_menu "$(T pkg) :" "查看插件清单" "添加自定义插件" "删除自定义插件" "手动编辑文件" "返回"
        case $RET_IDX in
            0) # 查看清单
               show_banner
               msg_info "核心内置插件 (Core)"
               [ -f "$CORE_PKG_FILE" ] && grep -v "^#" "$CORE_PKG_FILE" | awk '{printf "  - %-18s %s\n", $1, $2}'
               echo -e "\n  用户自定义插件 (Custom)"
               [ -f "$CUSTOM_PKG_FILE" ] && grep -v "^#" "$CUSTOM_PKG_FILE" | awk '{printf "  - %-18s %s\n", $1, $2}' || echo "  (None)"
               draw_line; read -p " Enter to continue..." ;;
            1) # 添加插件
               echo -e "\n  添加引导 (格式: 包名 仓库 分支):"
               read -p "  ➤ 名称: " pn; read -p "  ➤ 仓库: " pr; read -p "  ➤ 分支: " pb
               echo "$pn $pr ${pb:-master} _ _" >> "$CUSTOM_PKG_FILE"
               msg_ok "已添加 $pn"; sleep 1 ;;
            2) # 删除插件
               read -p "  ➤ 输入要删除的包名: " dn
               sed -i "/^$dn /d" "$CUSTOM_PKG_FILE"
               msg_ok "已删除 $dn"; sleep 1 ;;
            3) # 编辑文件
               ${EDITOR:-vi} "$CUSTOM_PKG_FILE" ;;
            *) return ;;
        esac
    done
}

# --- 其他功能函数保持 V10.1 逻辑 ---
config_auto_build() {
    while true; do
        show_banner; echo -e "  ${BP}[ $(T config_pipe) ]${NC}\n  ◈ $(T source): $A_REPO\n  ◈ $(T branch): $A_BRANCH\n  ◈ $(T model): ${A_CONFIGS[*]}\n  ◈ $(T cache): $A_KEEP_CACHE (${A_ITEMS[*]})"; draw_line
        select_menu "Options :" "修改远程仓库" "修改编译分支" "管理待编译机型" "配置缓存策略" "保存配置并返回" "放弃修改并返回"
        local idx=$RET_IDX
        case $idx in
            0) local names=(); local urls=(); while read -r n u || [ -n "$n" ]; do [[ "$n" =~ ^#.*$ || -z "$n" ]] && continue; names+=("$n"); urls+=("$u"); done < "$REPO_LIST_FILE"
               show_banner; select_menu "$(T source)" "${names[@]}" "手动输入" "返回"
               if [ "$RET_IDX" -lt "${#names[@]}" ]; then A_REPO="${urls[$RET_IDX]}"
               elif [ "$RET_IDX" -eq "${#names[@]}" ]; then read -p "  ➤ URL: " ur; A_REPO="$ur"; fi ;;
            1) show_banner; msg_info "正在探测分支..."; local raw=$(timeout 5s git ls-remote --heads "$A_REPO" 2>/dev/null); local all=($(echo "$raw" | awk -F'refs/heads/' '{print $2}' | sort -r))
               if [ ${#all[@]} -eq 0 ]; then read -p " ➤ $(T branch): " mb; A_BRANCH="${mb:-master}"; else
               list=("${all[@]:0:20}"); select_menu "$(T branch)" "${list[@]}" "手动输入" "返回"
               if [ "$RET_IDX" -lt "${#list[@]}" ]; then A_BRANCH="${list[$RET_IDX]}"
               elif [ "$RET_IDX" -eq "${#list[@]}" ]; then read -p " ➤: " mb; A_BRANCH="$mb"; fi; fi ;;
            2) local cfgs=($(ls "$PROFILES_DIR/" | sed 's/\.txt$//')); multi_select_menu "$(T model)" "${cfgs[@]}"
               if [[ "$RET_VAL" != "BACK" && -n "$RET_VAL" ]]; then A_CONFIGS=(); for i in $RET_VAL; do A_CONFIGS+=("${cfgs[$i]}"); done; fi ;;
            3) show_banner; select_menu "策略 :" "保留缓存 (推荐)" "全量清理 (Space)" "返回"
               if [ "$RET_IDX" -eq 0 ]; then A_KEEP_CACHE="true"; items=("dl" "staging_dir" "build_dir" "bin/packages" ".ccache"); multi_select_menu "勾选保留项 :" "${items[@]}"
               if [[ "$RET_VAL" != "BACK" && -n "$RET_VAL" ]]; then A_ITEMS=(); for i in $RET_VAL; do A_ITEMS+=("${items[$i]}"); done; fi
               elif [ "$RET_IDX" -eq 1 ]; then A_KEEP_CACHE="false"; A_ITEMS=(); fi ;;
            4) { echo "WRT_REPO=\"$A_REPO\""; echo "WRT_BRANCH=\"$A_BRANCH\""; echo "KEEP_CACHE=\"$A_KEEP_CACHE\""
                 echo -n "WRT_CONFIGS=("; for c in "${A_CONFIGS[@]}"; do echo -n "\"$c\" "; done; echo ")";
                 echo -n "CACHE_ITEMS=("; for i in "${A_ITEMS[@]}"; do echo -n "\"$i\" "; done; echo ")"; } > "$AUTO_CONF"; msg_ok "DONE"; sleep 1; return ;;
            *) return ;;
        esac
    done
}

manage_timer() {
    while true; do
        show_banner; select_menu "$(T timer) :" "设定周期执行计划" "检查当前活跃计划" "终止计划任务" "配置自动化流水线" "查看实时进程日志" "返回"
        case $RET_IDX in
            0) read -p " ➤ $(T hour): " th; read -p " ➤ $(T min): " tm; (crontab -l 2>/dev/null | grep -v "$AUTO_SCRIPT"; echo "$tm $th * * * /bin/bash $AUTO_SCRIPT") | crontab -; msg_ok "DONE"; sleep 1 ;;
            1) local c=$(crontab -l 2>/dev/null | grep "$AUTO_SCRIPT"); [ -n "$c" ] && msg_ok "Active: $(echo $c | awk '{print $2":"$1}')" || msg_warn "None"; read -p " Enter..." ;;
            2) crontab -l 2>/dev/null | grep -v "$AUTO_SCRIPT" | crontab -; msg_ok "DONE"; sleep 1 ;;
            3) config_auto_build ;;
            4) local l=$(ls -t "$ROOT_DIR/Logs/"*.log 2>/dev/null | head -n 1); [ -f "$l" ] && tail -f "$l" || msg_err "FAIL"; sleep 1 ;;
            *) return ;;
        esac
    done
}

compile_workflow() {
    local strategy="2"
    if [ -d "$BUILD_DIR/bin" ]; then show_banner; select_menu "策略 :" "增量快编" "标准更新" "深度清理" "取消"; [ "$RET_IDX" -ge 3 ] && return; strategy=$((RET_IDX+1)); fi
    msg_step "1" "1"; if [ -d "$BUILD_DIR/.git" ]; then cd "$BUILD_DIR"; [ "$strategy" != "1" ] && git checkout .; git pull && cd "$ROOT_DIR"; else git clone --depth=1 --single-branch --branch "$SEL_BRANCH" "$SEL_REPO" "$BUILD_DIR"; fi
    msg_step "2" "2"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && ./scripts/feeds clean; [ -d "feeds" ] && for f in feeds/*; do [ -d "$f/.git" ] && (cd "$f" && git checkout . && git clean -fd); done; ./scripts/feeds update -a && ./scripts/feeds install -a
    msg_step "3" "3"; export GITHUB_WORKSPACE="$ROOT_DIR"; cd "$BUILD_DIR/package" && bash "${SCRIPTS_DIR}/Packages.sh" && bash "${SCRIPTS_DIR}/Handles.sh"
    msg_step "4" "4"; cd "$BUILD_DIR"; [ "$strategy" == "3" ] && make clean; [ "$strategy" != "1" ] && rm -f .config; cat "${CONFIG_DIR}/GENERAL.txt" >> .config; [ -f "${PROFILES_DIR}/${SEL_MODEL}.txt" ] && cat "${PROFILES_DIR}/${SEL_MODEL}.txt" >> .config; bash "${SCRIPTS_DIR}/Settings.sh"; make defconfig
    msg_step "5" "5"; msg_info "$(T dl_msg)"; make download -j$(nproc); msg_info "$(T build_msg)"; if make -j$(nproc) || make -j1 V=s; then msg_ok "$(T done)"; else msg_err "$(T fail)"; fi
}

while true; do
    show_banner; select_menu "$(T main_menu)" "启动全流程交互编译" "一键再次重编上个机型" "仅同步代码插件" "调度与自动化管理" "扩展插件中心" "切换显示语言" "结束当前会话"
    case $RET_IDX in
        0) local names=(); local urls=(); while read -r n u || [ -n "$n" ]; do [[ "$n" =~ ^#.*$ || -z "$n" ]] && continue; names+=("$n"); urls+=("$u"); done < "$REPO_LIST_FILE"
           show_banner; select_menu "Source :" "${names[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#names[@]} + 1)) ] && continue
           [ "$RET_IDX" -lt "${#names[@]}" ] && SEL_REPO="${urls[$RET_IDX]}" || read -p " ➤ URL: " SEL_REPO
           show_banner; msg_info "探测分支..."; raw=$(timeout 5s git ls-remote --heads "$SEL_REPO" 2>/dev/null); all=($(echo "$raw" | awk -F'refs/heads/' '{print $2}' | sort -r))
           if [ ${#all[@]} -eq 0 ]; then read -p " ➤ Branch: " SEL_BRANCH; else list=("${all[@]:0:20}"); select_menu "Branch :" "${list[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#list[@]} + 1)) ] && continue; [ "$RET_IDX" -lt "${#list[@]}" ] && SEL_BRANCH="${list[$RET_IDX]}" || read -p " ➤: " SEL_BRANCH; fi
           cfgs=($(ls "$PROFILES_DIR/" | sed 's/\.txt$//')); show_banner; select_menu "Model :" "${cfgs[@]}" "手动" "返回"; [ "$RET_IDX" -ge $((${#cfgs[@]} + 1)) ] && continue
           [ "$RET_IDX" -lt "${#cfgs[@]}" ] && SEL_MODEL="${cfgs[$RET_IDX]}" || read -p " ➤: " SEL_MODEL; compile_workflow ;;
        1) if [ -f "$LAST_CONF" ]; then source "$LAST_CONF"; SEL_REPO="$L_REPO"; SEL_BRANCH="$L_BRANCH"; SEL_MODEL="$L_MODEL"; WRT_IP="$L_IP"; WRT_NAME="$L_NAME"; WRT_SSID="$L_SSID"; WRT_WORD="$L_WORD"; WRT_THEME="$L_THEME"; compile_workflow; else msg_warn "NONE"; sleep 1; fi ;;
        2) bash "${SCRIPTS_DIR}/Update.sh"; sleep 1 ;;
        3) manage_timer ;;
        4) manage_packages ;;
        5) [ "$CURRENT_LANG" == "zh" ] && echo "en" > "$LANG_CONF" || echo "zh" > "$LANG_CONF"; source "${SCRIPTS_DIR}/Ui.sh" ;;
        6|255) exit 0 ;;
    esac
done
