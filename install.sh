#!/bin/bash

# =========================================================
# WRT-CI 一键部署与同步脚本 (install.sh)
# =========================================================

C='\033[0;36m'; G='\033[0;32m'; NC='\033[0m'
GITHUB_USER="breeze303"
REPO_NAME="loc-build"

# 1. 确定目标目录 (就地原则)
if [[ "$(basename "$(pwd)")" != "$REPO_NAME" ]]; then
    TARGET_DIR="$(pwd)/$REPO_NAME"
else
    TARGET_DIR="$(pwd)"
fi

echo -e "${C}>>> 正在同步 $REPO_NAME 环境...${NC}"

# 2. 检测 Git
if ! command -v git &> /dev/null; then
    sudo apt update && sudo apt install -y git
fi

# 3. 克隆或更新
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${G}>>> 正在克隆仓库到: $TARGET_DIR ...${NC}"
    git clone "https://github.com/$GITHUB_USER/$REPO_NAME.git" "$TARGET_DIR"
else
    echo -e "${G}>>> 检测到本地环境，正在执行同步更新...${NC}"
    cd "$TARGET_DIR" && git pull
fi

# 4. 授权并启动
cd "$TARGET_DIR"
chmod +x b.sh Scripts/*.sh 2>/dev/null
echo -e "${G}>>> 同步完成！启动控制台...${NC}"
sleep 1
./b.sh
