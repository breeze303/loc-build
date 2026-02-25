#!/bin/bash

# =========================================================
# WRT-CI 本地定时编译脚本 (auto.sh) - Path Optimized
# =========================================================

ROOT_DIR=$(cd $(dirname $0)/.. && pwd)
BUILD_DIR="${ROOT_DIR}/wrt"
LOG_DIR="${ROOT_DIR}/Logs"
RELEASE_DIR="${ROOT_DIR}/bin/auto-builds"
CONFIG_DIR="${ROOT_DIR}/Config"
PROFILES_DIR="${CONFIG_DIR}/Profiles"
CONFIG_FILE="${CONFIG_DIR}/auto.conf"
DATE=$(date +"%Y%m%d-%H%M")

# --- 加载配置 ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    KEEP_CACHE="true"; CACHE_ITEMS=("dl" "staging_dir")
    WRT_REPO="https://github.com/immortalwrt/immortalwrt.git"
    WRT_BRANCH="master"; WRT_CONFIGS=("X86")
fi

mkdir -p "$LOG_DIR" "$RELEASE_DIR"
LOG_FILE="$LOG_DIR/build-$DATE.log"
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "🚀 启动全自动流水线 (缓存策略: $KEEP_CACHE)"

# --- 执行颗粒度清理 ---
if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR"
    if [ "$KEEP_CACHE" == "false" ]; then
        log "执行全量清理 (make dirclean)..."
        make dirclean >> "$LOG_FILE" 2>&1
    else
        log "按计划保留缓存项: ${CACHE_ITEMS[*]}"
        all_items=("dl" "staging_dir" "build_dir" "bin/packages" ".ccache")
        for item in "${all_items[@]}"; do
            if [[ ! " ${CACHE_ITEMS[*]} " =~ " ${item} " ]]; then
                log "清理非保留项: $item"
                rm -rf "$item"
            fi
        done
    fi
fi

# 1. 源码同步
log "同步源码..."
if [ ! -d "$BUILD_DIR/.git" ]; then
    git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$BUILD_DIR" >> "$LOG_FILE" 2>&1
else
    cd "$BUILD_DIR" && git checkout . && git pull origin "$WRT_BRANCH" >> "$LOG_FILE" 2>&1
fi

# 2. 循环编译
for CONFIG in "${WRT_CONFIGS[@]}"; do
    log "-------------------------------------------------------"
    log "📦 正在编译: $CONFIG"
    cd "$BUILD_DIR"
    rm -rf "./bin/targets/"
    
    # [修正路径] 从子目录 Profiles 读取配置
    [ -f "${CONFIG_DIR}/GENERAL.txt" ] && cat "${CONFIG_DIR}/GENERAL.txt" > .config
    [ -f "${PROFILES_DIR}/${CONFIG}.txt" ] && cat "${PROFILES_DIR}/${CONFIG}.txt" >> .config
    
    export WRT_THEME="argon" WRT_NAME="OpenWrt" WRT_MARK="Auto" WRT_DATE=$(date +"%y.%m.%d")
    bash "${ROOT_DIR}/Scripts/Settings.sh" >> "$LOG_FILE" 2>&1
    make defconfig >> "$LOG_FILE" 2>&1
    make download -j$(nproc) >> "$LOG_FILE" 2>&1
    
    log "执行编译..."
    make -j$(nproc) >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✅ SUCCESS: $CONFIG"
        TARGET_RELEASE="${RELEASE_DIR}/${CONFIG}-${DATE}"
        mkdir -p "$TARGET_RELEASE"
        find ./bin/targets/ -type f \( -name "*.img.gz" -o -name "*.bin" \) -exec cp {} "$TARGET_RELEASE/" \;
    else
        log "❌ FAILURE: $CONFIG"
    fi
done

log "🏁 任务结束。日志: $LOG_FILE"
