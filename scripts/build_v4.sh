#!/bin/bash
# v4 定制: 版本基线自动应用 + 最新argon含中文 + 密码预置root + 版本10.19.2026
set -e
cd /root/openwrt-2512 || exit 1
R=build_dir/target-aarch64_cortex-a53_musl/root-qualcommax

echo "===== [1] 版本号 -> 10.19.2026 ====="
sed -i 's/^REVISION:=.*/REVISION:=10.19.2026/' include/version.mk
grep '^REVISION' include/version.mk

echo "===== [2] 预置 root 密码哈希 (files/etc/shadow) ====="
HASH='$1$QUXHQx.n$mkasdtRiIdGx5KFkTorth.'
mkdir -p files/etc
sed '1c\root:$1$QUXHQx.n$mkasdtRiIdGx5KFkTorth.:19000:0:99999:7:::' "$R/etc/shadow" > files/etc/shadow
head -2 files/etc/shadow

echo "===== [3] 版本基线自动应用 init 脚本 ===="
mkdir -p files/etc/init.d
cat > files/etc/init.d/passwall-baseline <<'EOF'
#!/bin/sh /etc/rc.common
# 固件基线: 固件版本变化时自动应用以下配置(无线/密码/主题/IPv6)
# 这样保留配置在线升级后, 新固件的基线也能生效; 之后用户可自由修改
START=98
STOP=10

apply_baseline() {
	# 1) 无线: 禁用 2.4G; 5G -> AA_5G / asd12345 (按 band 识别, 不依赖 radio 索引)
	[ -s /etc/config/wireless ] || wifi config 2>/dev/null || true
	for r in $(uci -q show wireless 2>/dev/null | grep "\.band='2g'" | sed "s/\(wireless\.radio[0-9]*\)\..*/\1/"); do
		uci -q set "$r.disabled='1'"
	done
	for r in $(uci -q show wireless 2>/dev/null | grep "\.band='5g'" | sed "s/\(wireless\.radio[0-9]*\)\..*/\1/"); do
		uci -q set "$r.disabled='0'"
		uci -q set "$r.ssid='AA_5G'"
		uci -q set "$r.encryption='psk2'"
		uci -q set "$r.key='asd12345'"
	done
	uci -q commit wireless 2>/dev/null || true
	# 2) root 密码 -> root
	(echo 'root'; echo 'root') | passwd root >/dev/null 2>&1 || true
	# 3) 主题 -> argon (若已安装)
	if [ -d /www/luci-static/argon ]; then
		uci -q set luci.main.mediaurlbase='/luci-static/argon'
		uci -q commit luci
	fi
	# 4) 关闭 IPv6
	for i in $(uci -q show network | grep "\.ipv6='auto'" | sed "s/\(network\.[a-z0-9_]*\)\..*/\1/"); do
		uci -q set "$i.ipv6='0'"
	done
	uci -q delete network.globals.ula_prefix 2>/dev/null || true
	uci -q set dhcp.lan.dhcpv6='disabled' 2>/dev/null || true
	uci -q commit network 2>/dev/null || true
	uci -q commit dhcp 2>/dev/null || true
	cat > /etc/sysctl.d/99-ipv6-off.conf <<'CONF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
CONF
	# 5) 记录已应用版本
	echo "$(cat /etc/openwrt_version)" > /etc/config/.baseline-applied
}

start() {
	[ -f /etc/config/.baseline-applied ] || { apply_baseline; exit 0; }
	cur=$(cat /etc/openwrt_version 2>/dev/null)
	old=$(cat /etc/config/.baseline-applied 2>/dev/null)
	[ "$cur" = "$old" ] || apply_baseline
	exit 0
}
EOF
chmod +x files/etc/init.d/passwall-baseline

echo "===== [4] 换最新版 argon (上游 jerrykuku) ===="
rm -f package/feeds/kiddin9/luci-theme-argon package/feeds/kiddin9/luci-app-argon-config 2>/dev/null || true
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
grep -E "PKG_VERSION|PKG_RELEASE" package/luci-theme-argon/Makefile | head -3

echo "===== [5] .config 追加 argon 相关 ===="
for opt in CONFIG_PACKAGE_luci-theme-argon=y \
           CONFIG_PACKAGE_luci-app-argon-config=y \
           CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y \
           CONFIG_PACKAGE_luci-i18n-base-zh-cn=y; do
	key="${opt%%=*}"
	if grep -q "^$key=" .config; then
		sed -i "s|^$key=.*|$opt|" .config
	else
		echo "$opt" >> .config
	fi
done
grep -E "luci-theme-argon|luci-i18n-argon|luci-app-argon-config" .config

echo "===== [6] defconfig ====="
make defconfig > /root/build-v4-defconfig.log 2>&1
EX=$?
echo "[defconfig] exit=$EX"
tail -4 /root/build-v4-defconfig.log
[ $EX -ne 0 ] && exit 1

echo "===== [7] 增量编译 ===="
make -j4 > /root/build-v4.log 2>&1
EX=$?
echo "[build-v4] make exit=$EX $(date '+%H:%M:%S')"
tail -8 /root/build-v4.log
[ $EX -ne 0 ] && exit 1

echo "===== [8] 产物与 rootfs 验证 ====="
ls -la bin/targets/qualcommax/ipq807x/ | grep -E 'sysupgrade|factory'
sha256sum bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
head -1 "$R/etc/shadow"
ls -la "$R/etc/init.d/passwall-baseline" 2>/dev/null
cat "$R/etc/openwrt_version"

echo "===== [9] 部署 VER=10.19.2026 ====="
sed -i 's/^VER=.*/VER=10.19.2026/' /root/deploy_firmware.sh
grep '^VER=' /root/deploy_firmware.sh
bash /root/deploy_firmware.sh

echo "===== [10] 站点验证 ====="
curl -s http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/version.txt
echo
ls /var/www/passwall-editor/firmware/qualcommax-ipq807x/redmi_ax6/
echo "=== V4_DONE ==="
