#!/bin/bash

# 预置目录
PKG_PATH="${GITHUB_WORKSPACE}/wrt/package"
[ -z "$GITHUB_WORKSPACE" ] && PKG_PATH="$(pwd)"

# 检查标记函数: PATCH_FILE "文件路径" "检查内容(grep)" "修改命令(sed)" "描述"
PATCH_FILE() {
	local FILE=$1
	local STR=$2
	local CMD=$3
	local MSG=$4

	if [ -f "$FILE" ]; then
		if grep -q "$STR" "$FILE"; then
			echo "- $MSG (已处理，跳过)"
		else
			eval "$CMD" "$FILE"
			echo "- $MSG (已修复)"
		fi
	fi
}

echo "正在执行自定义修复 (Handles.sh)..."

# 预置 HomeProxy 数据 (保持原有逻辑，因为涉及删除重下)
if [ -d "$PKG_PATH/homeproxy" ]; then
	echo " "
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"
	rm -rf ./$HP_PATH/resources/*
	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")
	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/
	cd .. && rm -rf ./$HP_RULE/
	echo "homeproxy data has been updated!"
fi

# 修改 argon 主题配置
PATCH_FILE "$PKG_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon" \
	"primary '#31a1a1'" \
	"sed -i \"s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/\"" \
	"theme-argon"

# 修改 aurora 菜单式样
# 遍历目录，对每个 aurora 配置文件进行处理
find "$PKG_PATH/luci-app-aurora-config/root/" -type f -name "*aurora" 2>/dev/null | while read -r FILE; do
	PATCH_FILE "$FILE" "nav_submenu_type 'boxed-dropdown'" "sed -i \"s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g\"" "theme-aurora ($FILE)"
done

# 修改 qca-nss-drv 启动顺序
PATCH_FILE "../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init" "START=85" "sed -i 's/START=.*/START=85/g'" "qca-nss-drv"

# 修改 qca-nss-pbuf 启动顺序
PATCH_FILE "$PKG_PATH/kernel/mac80211/files/qca-nss-pbuf.init" "START=86" "sed -i 's/START=.*/START=86/g'" "qca-nss-pbuf"

# 修复 Rust 编译失败
RUST_MAKEFILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" 2>/dev/null)
if [ -n "$RUST_MAKEFILE" ]; then
	PATCH_FILE "$RUST_MAKEFILE" "ci-llvm=false" "sed -i 's/ci-llvm=true/ci-llvm=false/g'" "rust-llvm"
fi

# 修复 DiskMan 编译失败
PATCH_FILE "$PKG_PATH/luci-app-diskman/applications/luci-app-diskman/Makefile" "ntfs-3g-utils" "sed -i '/ntfs-3g-utils /d'" "diskman-ntfs"

# 修复 luci-app-netspeedtest
PATCH_FILE "$PKG_PATH/luci-app-netspeedtest/netspeedtest/files/99_netspeedtest.defaults" "exit 0" "sed -i '/exit 0/d; \$a\exit 0'" "netspeedtest-exit"
PATCH_FILE "$PKG_PATH/luci-app-netspeedtest/speedtest-cli/Makefile" "ca-bundle" "sed -i 's/ca-certificates/ca-bundle/g'" "netspeedtest-ca"

# 修复 daed
DAED_MAKEFILE=$(find "$PKG_PATH" -maxdepth 4 -name Makefile | xargs grep -l "PKG_NAME:=daed" 2>/dev/null)
if [ -n "$DAED_MAKEFILE" ]; then
	PATCH_FILE "$DAED_MAKEFILE" "# GOEXPERIMENT=" "sed -i 's/GOEXPERIMENT=/# &/'" "daed-go"
fi

# 修复 smartdns 哈希问题
SMARTDNS_MAKEFILE="$PKG_PATH/openwrt-smartdns/Makefile"
if [ -f "$SMARTDNS_MAKEFILE" ]; then
	PATCH_FILE "$SMARTDNS_MAKEFILE" "PKG_HASH:=skip" "sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g'" "smartdns-hash"
	PATCH_FILE "$SMARTDNS_MAKEFILE" "\$(TOPDIR)/feeds/packages" "sed -i 's|\.\./\.\./lang/rust/rust-package\.mk|\$(TOPDIR)/feeds/packages/lang/rust/rust-package.mk|g'" "smartdns-rust-path"
fi

echo "所有修复操作已完成！"
