#!/bin/bash

# =========================================================
# WRT-CI 本地一键编译脚本 (b.sh) - V6.9 Robust Edition
# =========================================================

ROOT_DIR=$(cd $(dirname $0) && pwd)
SCRIPTS_DIR="${ROOT_DIR}/Scripts"
[ -f "${SCRIPTS_DIR}/ui.sh" ] && source "${SCRIPTS_DIR}/ui.sh" || exit 1

# --- 路径设置 ---
BUILD_DIR="${ROOT_DIR}/wrt"
CONFIG_DIR="${ROOT_DIR}/Config"
PROFILES_DIR="${CONFIG_DIR}/Profiles"
AUTO_SCRIPT="${SCRIPTS_DIR}/auto.sh"
AUTO_CONF="${CONFIG_DIR}/auto.conf"
REPO_LIST_FILE="${CONFIG_DIR}/REPOS.txt"
CUSTOM_PKG_FILE="${CONFIG_DIR}/CUSTOM_PACKAGES.txt"
FIRMWARE_DIR="${ROOT_DIR}/Firmware"

# --- 配置加载 ---
load_auto_conf() {
    if [ -f "$AUTO_CONF" ]; then
        source "$AUTO_CONF"
        A_REPO="$WRT_REPO"; A_BRANCH="$WRT_BRANCH"
        [[ "$(declare -p WRT_CONFIGS 2>/dev/null)" == "declare -a"* ]] && A_CONFIGS=("${WRT_CONFIGS[@]}") || A_CONFIGS=("X86")
        A_KEEP_CACHE="${KEEP_CACHE:-true}"
        [[ "$(declare -p CACHE_ITEMS 2>/dev/null)" == "declare -a"* ]] && A_ITEMS=("${CACHE_ITEMS[@]}") || A_ITEMS=("dl" "staging_dir")
    else
        A_REPO="https://github.com/immortalwrt/immortalwrt.git"; A_BRANCH="master"; A_CONFIGS=("X86")
        A_KEEP_CACHE="true"; A_ITEMS=("dl" "staging_dir")
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
    echo -e " ${BC}${BOLD}  WRT-CI Dashboard${NC} ${BW}| v6.9 Robust${NC}"
    get_sys_info
    local cur_r=$(echo "${A_REPO:-Official}" | sed 's|https://github.com/||; s|.git||')
    echo -e " ${BC}$(T source):${NC} ${BY}${cur_r}${NC} ${BW}[${A_BRANCH:-master}]${NC}"
    draw_line
}

# --- [加固版] 智能分支获取 ---
select_remote_branch() {
    local repo_url=$1
    show_banner >&2
    echo -e "\n  ${C}正在探测远程分支, 请稍候...${NC}" >&2
    
    # 使用 timeout 防止网络卡死，增加 5 秒限制
    local raw_data=$(timeout 5s git ls-remote --heads "$repo_url" 2>/dev/null)
    local all_branches=($(echo "$raw_data" | awk -F'refs/heads/' '{print $2}' | sort -r))
    
    if [ ${#all_branches[@]} -eq 0 ]; then
        echo -e "  ${BY}[提示]${NC} 无法自动获取列表 (网络超时或仓库私有)" >&2
        echo -ne "  ➤ 请手动输入分支名 (默认 master): " >&2
        read mb
        echo "${mb:-master}"
    else
        local branches=("${all_branches[@]:0:25}") # 最多显示 25 个
        show_banner >&2
        select_menu "请选择编译分支 (显示最近25个) :" "${branches[@]}" "$(T manual)" "$(T back)"
        local res=$?
        if [ $res -lt ${#branches[@]} ]; then
            echo "${branches[$res]}"
        elif [ $res -eq ${#branches[@]} ]; then
            echo -ne "\n  ➤ $(T manual): " >&2; read mb; echo "$mb"
        else
            echo "BACK"
        fi
    fi
}

# --- [加固版] 仓库选择器 ---
select_source_repo() {
    local names=(); local urls=()
    if [ -f "$REPO_LIST_FILE" ]; then
        while IFS='|' read -r name url || [ -n "$name" ]; do 
            [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
            names+=("$name"); urls+=("$url")
        done < "$REPO_LIST_FILE"
    fi
    show_banner >&2
    select_menu "$(T source)" "${names[@]}" "$(T manual)" "$(T back)"
    local res=$?
    if [ $res -lt ${#names[@]} ]; then
        echo "${urls[$res]}"
    elif [ $res -eq ${#names[@]} ]; then
        echo -ne "\n  ➤ 输入完整 URL: " >&2; read r; echo "$r"
    else
        echo "BACK"
    fi
}

# --- 编译策略选择 ---
select_build_strategy() {
    if [ -d "$BUILD_DIR/bin" ]; then
        show_banner >&2; select_menu "$(T strategy)" "$(T fast)" "$(T stable)" "$(T clean)" "$(T back)"
        local res=$?; [ $res -eq 0 ] && echo "1"; [ $res -eq 1 ] && echo "2"; [ $res -eq 2 ] && echo "3"; [ $res -ge 3 ] && echo "BACK"
    else echo "2"; fi
}

# --- 核心流水线 (加固) ---
compile_workflow() {
    local strategy=$(select_build_strategy)
    [[ "$strategy" == "BACK" ]] && return
    
    msg_step "1" "源码环境同步"
    if [ -d "$BUILD_DIR/.git" ]; then
        cd "$BUILD_DIR"; [ "$strategy" != "1" ] && git checkout .; git pull && cd "$ROOT_DIR"
    else git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$BUILD_DIR" ; fi

    msg_step "2" "插件 Feed 更新"
    cd "$BUILD_DIR"; [ "$strategy" == "3" ] && ./scripts/feeds clean
    [ -d "feeds" ] && for f in feeds/*; do [ -d "$f/.git" ] && (cd "$f" && git checkout . && git clean -fd) ; done
    ./scripts/feeds update -a && ./scripts/feeds install -a

    msg_step "3" "载入自定义补丁与包"
    export GITHUB_WORKSPACE="$ROOT_DIR"; cd "$BUILD_DIR/package" && bash "${SCRIPTS_DIR}/Packages.sh" && bash "${SCRIPTS_DIR}/Handles.sh"

    msg_step "4" "生成编译配置"
    cd "$BUILD_DIR"; [ "$strategy" == "3" ] && make clean
    export WRT_THEME="argon" WRT_NAME="OpenWrt" WRT_IP="192.168.1.1" WRT_DATE=$(date +"%y.%m.%d")
    [ "$strategy" != "1" ] && rm -f .config
    [ -f "${CONFIG_DIR}/GENERAL.txt" ] && cat "${CONFIG_DIR}/GENERAL.txt" >> .config
    [ -f "${PROFILES_DIR}/${WRT_CONFIG}.txt" ] && cat "${PROFILES_DIR}/${WRT_CONFIG}.txt" >> .config
    bash "${SCRIPTS_DIR}/Settings.sh" && make defconfig

    msg_step "5" "启动并行编译引擎"
    make download -j$(nproc); if make -j$(nproc) || make -j1 V=s; then msg_ok "$(T done)"; else msg_err "$(T fail)"; fi
}

# --- 主入口 (逻辑加固) ---
while true; do
    show_banner
    select_menu "$(T main_menu)" "$(T build)" "$(T sync)" "$(T timer)" "$(T pkg)" "$(T lang)" "$(T exit)"
    case $? in
        0) # 手动编译流程
           nr=$(select_source_repo); [[ "$nr" == "BACK" || -z "$nr" ]] && continue
           nb=$(select_remote_branch "$nr"); [[ "$nb" == "BACK" || -z "$nb" ]] && continue
           show_banner; cfgs=($(ls "$PROFILES_DIR/" | sed 's/\.txt$//'))
           select_menu "$(T model)" "${cfgs[@]}" "$(T manual)" "$(T back)"
           m_idx=$?
           if [ $m_idx -ge $((${#cfgs[@]} + 1)) ]; then continue
           elif [ $m_idx -eq ${#cfgs[@]} ]; then read -p "  ➤ Name: " r; WRT_CONFIG="$r"
           else WRT_CONFIG=${cfgs[$m_idx]}; fi
           WRT_REPO="$nr"; WRT_BRANCH="$nb"
           compile_workflow; break ;;
        1) bash "${SCRIPTS_DIR}/Update.sh"; sleep 1 ;;
        2) bash -c "source ./b.sh && manage_timer" ;;
        3) bash -c "source ./b.sh && manage_packages" ;;
        4) switch_language ;;
        5|255) msg_info "Goodbye!"; exit 0 ;;
    esac
done
