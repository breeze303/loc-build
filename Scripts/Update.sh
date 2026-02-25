#!/bin/bash

# =========================================================
# WRT-CI 代码更新脚本 (Update.sh) - UNIFIED UI
# =========================================================

ROOT_DIR=$(cd $(dirname $0)/.. && pwd)
SCRIPTS_DIR="$ROOT_DIR/Scripts"
[ -f "${SCRIPTS_DIR}/ui.sh" ] && source "${SCRIPTS_DIR}/ui.sh" || exit 1

BUILD_DIR="$ROOT_DIR/wrt"

# 1. 更新主仓库
msg_info "正在同步主仓库脚本与配置..."
cd "$ROOT_DIR"
if [ -d ".git" ]; then
    git pull
else
    msg_warn "未检测到 Git 仓库，跳过自我更新。"
fi

# 2. 更新 OpenWRT 源码
msg_info "正在同步 OpenWRT 源码..."
if [ -d "$BUILD_DIR/.git" ]; then
    cd "$BUILD_DIR"
    git checkout .
    git pull
else
    msg_err "源码目录不存在。"
fi

# 3. 更新 Feeds
msg_info "正在更新插件源 (Feeds)..."
if [ -f "$BUILD_DIR/scripts/feeds" ]; then
    cd "$BUILD_DIR"
    # 清理冲突
    for feed in feeds/*; do [ -d "$feed/.git" ] && (cd "$feed" && git checkout . && git clean -fd); done
    ./scripts/feeds update -a && ./scripts/feeds install -a
fi

# 4. 执行插件同步
msg_info "正在同步自定义插件..."
export GITHUB_WORKSPACE="$ROOT_DIR"
cd "$BUILD_DIR/package" 2>/dev/null && bash "$SCRIPTS_DIR/Packages.sh"

msg_ok "代码与插件已同步至最新状态。"
