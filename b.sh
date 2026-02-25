#!/bin/bash

# =========================================================
# WRT-CI 本地一键编译脚本 (b.sh) - 自引导版 V3.5
# =========================================================

# --- 引导配置 (上传 GitHub 前请修改此处) ---
GITHUB_USER="breeze303" # 你的 GitHub 用户名
REPO_NAME="loc-build"
TARGET_DIR="$HOME/$REPO_NAME"

# --- 核心色彩库 ---
R='\033[0;31m';  BR='\033[1;31m'
G='\033[0;32m';  BG='\033[1;32m'
Y='\033[0;33m';  BY='\033[1;33m'
B='\033[0;34m';  BB='\033[1;34m'
P='\033[0;35m';  BP='\033[1;35m'
C='\033[0;36m';  BC='\033[1;36m'
W='\033[0;37m';  BW='\033[1;37m'
NC='\033[0m'

# =========================================================
# 🚀 引导逻辑 (Bootstrap): 实现一键拉取/更新
# =========================================================
if [[ "$0" == "/dev/fd/"* || "$0" == "bash" || "$(pwd)" != "$TARGET_DIR" ]]; then
    echo -e "${C}>>> 正在同步 WRT-CI 环境...${NC}"
    if ! command -v git &> /dev/null; then
        sudo apt update && sudo apt install -y git
    fi

    if [ ! -d "$TARGET_DIR" ]; then
        echo -e "${G}>>> 首次使用，正在拉取仓库到 $TARGET_DIR ...${NC}"
        git clone "https://github.com/$GITHUB_USER/$REPO_NAME.git" "$TARGET_DIR"
    else
        echo -e "${G}>>> 检测到本地环境，正在执行同步更新...${NC}"
        cd "$TARGET_DIR" && git pull
    fi

    echo -e "${G}>>> 环境同步完成，正在启动控制台...${NC}"
    cd "$TARGET_DIR" && chmod +x b.sh Scripts/*.sh 2>/dev/null
    exec ./b.sh "$@" # 切换到本地脚本运行并传递参数
    exit
fi

# =========================================================
# 核心业务逻辑
# =========================================================

# --- 路径设置 ---
ROOT_DIR=$(pwd)
BUILD_DIR="${ROOT_DIR}/wrt"
CONFIG_DIR="${ROOT_DIR}/Config"
SCRIPTS_DIR="${ROOT_DIR}/Scripts"
AUTO_SCRIPT="${SCRIPTS_DIR}/auto.sh"
AUTO_CONF="${CONFIG_DIR}/auto.conf"
FIRMWARE_DIR="${ROOT_DIR}/Firmware"

# --- 初始配置加载 ---
load_auto_conf() {
    if [ -f "$AUTO_CONF" ]; then
        source "$AUTO_CONF"
        A_REPO="$WRT_REPO"; A_BRANCH="$WRT_BRANCH"
        [[ "$(declare -p WRT_CONFIGS 2>/dev/null)" == "declare -a"* ]] && A_CONFIGS=("${WRT_CONFIGS[@]}") || A_CONFIGS=("$WRT_CONFIGS")
    else
        A_REPO="https://github.com/immortalwrt/immortalwrt.git"; A_BRANCH="master"; A_CONFIGS=("X86")
    fi
}
load_auto_conf

# --- 视觉组件 ---
get_sys_info() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    local mem=$(free -m | awk '/Mem:/ { printf("%3.1f%%", $3/$2*100) }')
    local disk=$(df -h / | awk '/\// {print $(NF-1)}' | head -n 1)
    echo -e " ${BC}◈ CPU: ${BY}$cpu ${BC}◈ MEM: ${BY}$mem ${BC}◈ DISK: ${BY}$disk${NC}"
}

msg_info() { echo -e " ${BC}${NC} ${BW}$1${NC}"; }
msg_ok()   { echo -e " ${BG}✔${NC} ${BW}$1${NC}"; }
msg_warn() { echo -e " ${BY}⚠${NC} ${BW}$1${NC}"; }
msg_err()  { echo -e " ${BR}✘${NC} ${BW}$1${NC}"; }
msg_step() { 
    echo -e "\n ${BP}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e " ${BP}┃${NC}  ${BW}${BOLD}STEP $1${NC} : ${BC}$2${NC}"
    echo -e " ${BP}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

show_banner() {
    clear
    echo -e "${BB}${BOLD}"
    echo "   _      ______ _______         _____ _____ "
    echo "  | |    |  __ \__   __|       / ____|_   _|"
    echo "  | |  | |__) | | |     -    | |      | |  "
    echo "  | |/\| |  _  /  | |    | |   | |      | |  "
    echo "  \  /\  / | \ \  | |    | |   | |____ _| |_ "
    echo "   \/  \/|_|  \_\ |_|    |_|    \_____|_____|"
    echo -e "${NC}"
    echo -e " ${BC}${BOLD}  WRT-CI Automation Dashboard${NC} ${BW}| v3.5${NC}"
    get_sys_info
    echo -e "${BB} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# --- 环境检测 ---
check_env() {
    local deps=("git" "curl" "wget" "jq" "dos2unix" "make" "gcc" "g++")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then missing+=("$dep"); fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        msg_warn "必要组件缺失: ${missing[*]}"
        read -p "  ➤ 一键修复环境? (y/n): " opt
        [ "$opt" == "y" ] && (sudo apt update && sudo apt install -y build-essential libncurses5-dev gawk gettext libssl-dev python3-distutils zlib1g-dev patch unzip qemu-utils "${missing[@]}")
    fi
}

# --- 归档逻辑 ---
archive_firmware() {
    msg_step "6" "固件智能归档"
    local date=$(date +"%y.%m.%d")
    local target_dir=$(find "$BUILD_DIR/bin/targets/" -type d -mindepth 2 -maxdepth 2 | head -n 1)
    
    if [ -z "$target_dir" ]; then
        msg_err "未找到生成文件" ; return 1
    fi

    mkdir -p "$FIRMWARE_DIR"
    msg_info "提取并重命名..."
    find "$target_dir" -type f \( -name "*.img.gz" -o -name "*.bin" -o -name "*.tar.gz" \) | while read -r file; do
        local ext="${file##*.}"
        local new_name="WRT-${WRT_CONFIG:-"OpenWrt"}-${date}.${ext}"
        cp "$file" "$FIRMWARE_DIR/$new_name"
        echo -e "  ${BG}→${NC} ${W}$new_name${NC}"
    done

    msg_ok "存档至: $FIRMWARE_DIR"
    read -p "  ➤ 是否执行清理(make clean)? (y/n): " c_opt
    [ "$c_opt" == "y" ] && (cd "$BUILD_DIR" && make clean)
}

# --- 功能子函数 ---
select_repo_generic() {
    echo -e "\n  ${BC}📡 选择源码仓库源:${NC}" >&2
    echo -e "   1. ImmortalWrt (Official)   2. ImmortalWrt (Qualcomm)\n   3. ImmortalWrt (ZqinKing)   4. 自定义 URL" >&2
    read -p "  ❯ 编号: " repo_opt
    case $repo_opt in
        1) echo "https://github.com/immortalwrt/immortalwrt.git";;
        2) echo "https://github.com/VIKINGYFY/immortalwrt.git";;
        3) echo "https://github.com/ZqinKing/immortalwrt.git";;
        4) read -p "  ❯ 仓库: " r; echo "$r";;
        *) echo "https://github.com/immortalwrt/immortalwrt.git";;
    esac
}

select_model() {
    echo -e "\n  ${BY}📟 选择编译机型:${NC}" >&2
    local cfgs=($(ls "${CONFIG_DIR}/" | grep -v "GENERAL" | sed 's/\.txt$//'))
    for i in "${!cfgs[@]}"; do printf "  ${BC}%2d.${NC} %-14s" "$((i+1))" "${cfgs[$i]}" >&2; [[ $(( (i+1) % 3 )) -eq 0 ]] && echo "" >&2; done
    echo -ne "\n  ${BC}99.${NC} 手动输入  ❯ 编号: " >&2
    read model_idx
    if [[ "$model_idx" == "99" ]]; then read -p "  ❯ 名: " r; echo "$r"
    elif [[ "$model_idx" -ge 1 && "$model_idx" -le "${#cfgs[@]}" ]]; then echo "${cfgs[$((model_idx-1))]}"
    else echo "X86" ; fi
}

compile_workflow() {
    check_env
    if [ -d "$BUILD_DIR/bin" ]; then
        echo -e "\n  ${BY}检测到已有编译记录:${NC}"
        echo -e "   ${BG}1.${NC} 增量快编 | ${BC}2.${NC} 标准更新 | ${BR}3.${NC} 深度清理"
        read -p "  ❯ 策略 [1-3]: " strategy
    fi

    msg_step "1" "源码环境同步"
    if [ -d "$BUILD_DIR/.git" ]; then
        cd "$BUILD_DIR" && [ "$strategy" != "1" ] && git checkout .
        git pull && cd "$ROOT_DIR"
    else git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$BUILD_DIR" ; fi

    msg_step "2" "插件 Feed 更新"
    cd "$BUILD_DIR"
    [ "$strategy" == "3" ] && ./scripts/feeds clean
    [ -d "feeds" ] && for f in feeds/*; do [ -d "$f/.git" ] && (cd "$f" && git checkout . && git clean -fd); done
    ./scripts/feeds update -a && ./scripts/feeds install -a

    msg_step "3" "载入自定义补丁与包"
    export GITHUB_WORKSPACE="$ROOT_DIR"
    cd "$BUILD_DIR/package" && bash "${SCRIPTS_DIR}/Packages.sh" && bash "${SCRIPTS_DIR}/Handles.sh"

    msg_step "4" "编译选项注入"
    cd "$BUILD_DIR"
    [ "$strategy" == "3" ] && make clean
    export WRT_THEME="argon" WRT_NAME="OpenWrt" WRT_IP="192.168.1.1" WRT_DATE=$(date +"%y.%m.%d")
    [ "$strategy" != "1" ] && rm -f .config
    [ -f "${CONFIG_DIR}/${WRT_CONFIG}.txt" ] && cat "${CONFIG_DIR}/${WRT_CONFIG}.txt" >> .config
    [ -f "${CONFIG_DIR}/${WRT_CONFIG}" ] && cat "${CONFIG_DIR}/${WRT_CONFIG}" >> .config
    bash "${SCRIPTS_DIR}/Settings.sh" && make defconfig

    msg_step "5" "启动核心编译引擎"
    make download -j$(nproc)
    if make -j$(nproc) || make -j1 V=s; then msg_ok "编译成功！" ; archive_firmware
    else msg_err "编译失败" ; fi
}

# --- 主程序入口 ---
while true; do
    show_banner
    echo -e "  ${BP}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "  ${BP}│${NC}  ${BG}[1]${NC} ${BW}⚡ 交互编译流程${NC}    ${BC}[2]${NC} ${BW}🔄 同步更新代码${NC}   ${BP}│${NC}"
    echo -e "  ${BP}│${NC}  ${BY}[3]${NC} ${BW}⚙ 自动化与调度${NC}    ${BR}[4]${NC} ${BW}⏻ 结束当前会话${NC}   ${BP}│${NC}"
    echo -e "  ${BP}╰──────────────────────────────────────────────────╯${NC}"
    echo -ne "  ${BC}❯${NC} ${BW}指令编号 [1-4]: ${NC}"
    read main_opt
    case $main_opt in
        1) WRT_REPO=$(select_repo_generic); read -p "  ❯ 分支: " b; WRT_BRANCH=${b:-"master"}
           WRT_CONFIG=$(select_model); compile_workflow; break;;
        2) bash "${SCRIPTS_DIR}/Update.sh"; sleep 2;;
        3) bash -c "source ./b.sh && manage_timer" ;; # 此处假设 manage_timer 已在 shell 环境中或继续保留
        4) msg_info "Bye!"; exit 0;;
        *) msg_warn "无效输入"; sleep 1;;
    esac
done
