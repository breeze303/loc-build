#!/bin/bash

# =========================================================
# WRT-CI 代码更新脚本 (u.sh)
# 用于同步主仓库、OpenWRT 源码、Feeds 以及自定义插件
# =========================================================

ROOT_DIR=$(cd $(dirname $0)/.. && pwd)
SCRIPTS_DIR="$ROOT_DIR/Scripts"
BUILD_DIR="$ROOT_DIR/wrt"

set_color() {
    echo -e "\033[32m$1\033[0m"
}

# 1. 更新 WRT-CI 项目本身
update_self() {
    set_color "--- 正在更新 WRT-CI 脚本与配置 ---"
    cd "$ROOT_DIR"
    if [ -d ".git" ]; then
        git pull || echo "警告: WRT-CI 更新失败。"
    else
        echo "提示: 当前目录不是 Git 仓库，跳过自我更新。"
    fi
}

# 2. 更新 OpenWRT 源码
update_source() {
    set_color "--- 正在更新 OpenWRT 源码 ---"
    if [ -d "$BUILD_DIR/.git" ]; then
        cd "$BUILD_DIR"
        # 清除本地修改（Handles.sh 造成的变动）以允许 git pull
        git checkout .
        git pull || echo "警告: 源码更新失败。"
    else
        echo "错误: 未找到 OpenWRT 源码目录 ($BUILD_DIR)。"
    fi
}

# 3. 更新 Feeds
update_feeds() {
    set_color "--- 正在更新 Feeds ---"
    if [ -f "$BUILD_DIR/scripts/feeds" ]; then
        cd "$BUILD_DIR"
        
        # 重置 feeds 目录下的所有本地修改，防止更新冲突
        if [ -d "feeds" ]; then
            for feed in feeds/*; do
                if [ -d "$feed/.git" ]; then
                    (cd "$feed" && git checkout . && git clean -fd)
                fi
            done
        fi

        ./scripts/feeds update -a
        ./scripts/feeds install -a
    fi
}

# 4. 更新自定义软件包
update_packages() {
    set_color "--- 正在更新自定义软件包 ---"
    export GITHUB_WORKSPACE="$ROOT_DIR"
    if [ -f "$SCRIPTS_DIR/Packages.sh" ]; then
        cd "$BUILD_DIR/package" 2>/dev/null || mkdir -p "$BUILD_DIR/package" && cd "$BUILD_DIR/package"
        bash "$SCRIPTS_DIR/Packages.sh"
        bash "$SCRIPTS_DIR/Handles.sh"
    fi
}

# 执行更新流程
update_self
update_source
update_feeds
update_packages

set_color "所有更新已完成！"
