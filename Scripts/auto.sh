#!/bin/bash

# =========================================================
# WRT-CI 本地定时编译脚本 (auto.sh) - 配置驱动版
# =========================================================

# --- 路径设置 ---
ROOT_DIR=$(cd $(dirname $0)/.. ROOT_DIR=$(cd $(dirname $0) && pwd)ROOT_DIR=$(cd $(dirname $0) && pwd) pwd)
BUILD_DIR="${ROOT_DIR}/wrt"
LOG_DIR="${ROOT_DIR}/Logs"
RELEASE_DIR="${ROOT_DIR}/bin/auto-builds"
CONFIG_FILE="${ROOT_DIR}/Config/auto.conf"
DATE=$(date +"%Y%m%d-%H%M")

# --- 加载配置 (如果不存在则使用默认值) ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    WRT_REPO="https://github.com/immortalwrt/immortalwrt.git"
    WRT_BRANCH="master"
    WRT_CONFIGS=("X86")
fi

mkdir -p "$LOG_DIR" "$RELEASE_DIR"
LOG_FILE="$LOG_DIR/build-$DATE.log"

# --- 日志格式化 ---
log_header() {
    echo "=======================================================" >> "$LOG_FILE"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "=======================================================" >> "$LOG_FILE"
    echo "[INFO] $1"
}

log_step() {
    echo "-------------------------------------------------------" >> "$LOG_FILE"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] STEP: $1" >> "$LOG_FILE"
    echo "-------------------------------------------------------" >> "$LOG_FILE"
    echo "[STEP] $1"
}

log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "       $1"
}

# 1. 更新环境与代码
log_header "启动全自动流水线 (WRT-CI AUTO)"
log_msg "仓库: $WRT_REPO"
log_msg "分支: $WRT_BRANCH"
log_msg "机型: ${WRT_CONFIGS[*]}"

log_step "同步源码"
export GITHUB_WORKSPACE="$ROOT_DIR"

# 首次克隆或更新
if [ ! -d "$BUILD_DIR/.git" ]; then
    git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$BUILD_DIR" >> "$LOG_FILE" 2>&1
else
    cd "$BUILD_DIR"
    git remote set-url origin "$WRT_REPO" >> "$LOG_FILE" 2>&1
    git checkout . && git pull origin "$WRT_BRANCH" >> "$LOG_FILE" 2>&1
fi

# 调用更新脚本同步 Feeds 和插件
bash "${ROOT_DIR}/Scripts/Update.sh" >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log_msg "ERROR: 环境更新失败！"
    exit 1
fi

# 2. 循环编译机型
for CONFIG in "${WRT_CONFIGS[@]}"; do
    log_header "正在执行编译机型: $CONFIG"
    cd "$BUILD_DIR"
    
    # 应用配置
    rm -f .config
    [ -f "${ROOT_DIR}/Config/${CONFIG}.txt" ] && cat "${ROOT_DIR}/Config/${CONFIG}.txt" > .config
    [ -f "${ROOT_DIR}/Config/${CONFIG}" ] && cat "${ROOT_DIR}/Config/${CONFIG}" > .config
    
    export WRT_THEME="argon" WRT_NAME="OpenWrt" WRT_IP="192.168.1.1" WRT_MARK="Auto" WRT_DATE=$(date +"%y.%m.%d")
    
    log_step "[$CONFIG] 应用设置与生成配置"
    bash "${ROOT_DIR}/Scripts/Settings.sh" >> "$LOG_FILE" 2>&1
    make defconfig >> "$LOG_FILE" 2>&1
    
    log_step "[$CONFIG] 下载依赖"
    make download -j$(nproc) >> "$LOG_FILE" 2>&1
    
    log_step "[$CONFIG] 启动编译"
    make -j$(nproc) >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_msg "SUCCESS: $CONFIG 编译成功！"
        TARGET_RELEASE="${RELEASE_DIR}/${CONFIG}-${DATE}"
        mkdir -p "$TARGET_RELEASE"
        find ./bin/targets/ -type f \( -name "*.img.gz" -o -name "*.bin" \) -exec cp {} "$TARGET_RELEASE/" \;
    else
        log_msg "FAILURE: $CONFIG 编译失败。"
    fi
    
    make clean >> "$LOG_FILE" 2>&1
done

log_header "流程结束"
