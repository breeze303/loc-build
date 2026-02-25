#!/bin/bash

# =========================================================
# WRT-CI 插件下载管理脚本
# =========================================================

SCRIPTS_DIR=$(cd $(dirname $0) && pwd)
[ -f "${SCRIPTS_DIR}/ui.sh" ] && source "${SCRIPTS_DIR}/ui.sh"

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	msg_info "处理插件: ${PKG_NAME}"

	# 清理冲突
	for NAME in "${PKG_LIST[@]}"; do
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do rm -rf "$DIR"; done <<< "$FOUND_DIRS"
		fi
	done

	# 确定目标目录
	local TARGET_DIR=""
	if [[ "$PKG_SPECIAL" == "name" ]]; then
		TARGET_DIR="$PKG_NAME"
	else
		TARGET_DIR="${REPO_NAME%.git}"
	fi

	# 确定克隆地址 (支持完整 URL 或 GitHub 简写)
	local CLONE_URL="$PKG_REPO"
	if [[ ! "$CLONE_URL" == "http"* ]]; then
		CLONE_URL="https://github.com/$PKG_REPO.git"
	fi

	# 始终删除并重新克隆
	echo "正在拉取: $CLONE_URL [$PKG_BRANCH]"
	rm -rf "$TARGET_DIR"
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "$CLONE_URL" $TARGET_DIR

	# 处理克隆后的特殊逻辑
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		echo "正在从大杂烩仓库中提取包: $PKG_NAME"
		find ./$TARGET_DIR/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$TARGET_DIR/
	fi
}

# =========================================================
# 默认核心插件 (框架内置)
# =========================================================
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-smartdns" "pymumu/luci-app-smartdns" "master"
UPDATE_PACKAGE "smartdns" "pymumu/openwrt-smartdns" "master"

UPDATE_PACKAGE "lucky" "sirpdboy/luci-app-lucky" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "master" "" "homebox speedtest"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
UPDATE_PACKAGE "daed" "QiuSimons/luci-app-daed" "master"

# =========================================================
# 用户自定义插件逻辑
# =========================================================

# 1. 尝试从外部文件读取 (Config/CUSTOM_PACKAGES.txt)
# 格式: 包名 仓库 选项(pkg/name) 冲突包
CUSTOM_FILE="../../Config/CUSTOM_PACKAGES.txt"
if [ -f "$CUSTOM_FILE" ]; then
    echo -e "\n加载自定义插件列表 ($CUSTOM_FILE)..."
    while read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        UPDATE_PACKAGE $line
    done < "$CUSTOM_FILE"
fi

# 2. 直接在此下方添加手动调用 (方便快速调试)
# UPDATE_PACKAGE "Hello" "world/hello" "master"

# =========================================================
# 版本更新逻辑
# =========================================================
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		return
	fi

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_NAME 已升级至 $NEW_VER"
		fi
	done
}

UPDATE_VERSION "sing-box"
