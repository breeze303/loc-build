#!/bin/bash

# =========================================================
# WRT-CI 插件下载与版本更新引擎 (Packages.sh)
# =========================================================

SCRIPTS_DIR=$(cd $(dirname $0) && pwd)
ROOT_DIR=$(cd $SCRIPTS_DIR/.. && pwd)
[ -f "${SCRIPTS_DIR}/Ui.sh" ] && source "${SCRIPTS_DIR}/Ui.sh"

# --- 1. 插件下载逻辑 ---
UPDATE_PACKAGE() {
	local name=$1 repo=$2 branch=$3 spec=$4 confs=$5
	[ -z "$name" ] || [ -z "$repo" ] && return
	msg_info "Processing: ${name}"
	for item in ${name//,/ } ${confs//,/ }; do
		[ "$item" == "_" ] && continue
		local found=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$item*" 2>/dev/null)
		[ -n "$found" ] && rm -rf $found
	done
	local target=""
	[[ "$spec" == "name" ]] && target="$name" || target="${repo#*/}"
	target="${target%.git}"
	local url="$repo"
	[[ ! "$url" == "http"* ]] && url="https://github.com/$repo.git"
	rm -rf "$target"
	git clone --depth=1 --single-branch --branch "$branch" "$url" "$target"
	if [[ "$spec" == "pkg" ]]; then
		find ./$target/*/ -maxdepth 3 -type d -iname "*$name*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$target/
	fi
}

PROCESS_FILE() {
	[ ! -f "$1" ] && return
	while read -r n r b s c || [ -n "$n" ]; do
		[[ "$n" =~ ^#.*$ || -z "$n" ]] && continue
		UPDATE_PACKAGE "$n" "$r" "$b" "$s" "$c"
	done < "$1"
}

# --- 2. 自动版本更新逻辑 (补回) ---
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	[ -z "$PKG_FILES" ] && return

	msg_info "Update Check: $PKG_NAME"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
			local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
			local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
			local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
			local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			msg_ok "$PKG_NAME bumped to $NEW_VER"
		fi
	done
}

# --- 执行流程 ---
# A. 下载清单插件
PROCESS_FILE "${ROOT_DIR}/Config/CORE_PACKAGES.txt"
PROCESS_FILE "${ROOT_DIR}/Config/CUSTOM_PACKAGES.txt"

# B. 自动更新特定包版本
UPDATE_VERSION "sing-box"
# UPDATE_VERSION "tailscale"
