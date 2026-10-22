#!/bin/bash
# v6 定制: passwall-editor 升级到最新(0.8.7) + argon 主题默认亮色 + 版本10.22.2026
set -e
cd /root/openwrt-2512 || exit 1
R=build_dir/target-aarch64_cortex-a53_musl/root-qualcommax

echo "===== [1] 更新 passwall-editor 到最新 ====="
cd /root/passwall-editor
git pull origin 2>&1 | tail -3 || git fetch origin && git reset --hard origin/HEAD
git log -1 --format='%h %ci %s'
echo "--- 新版本号 ---"
cat passwall-device-control/VERSION
cd /root/openwrt-2512

echo "===== [2] 同步插件 root 到编译树 files/ ====="
cp -a /root/passwall-editor/passwall-device-control/root/. files/
chmod 755 files/etc/init.d/passwall-device files/usr/share/passwall-device/*.sh files/usr/share/passwall-device/app.lua 2>/dev/null || true
chmod 644 files/usr/lib/lua/luci/controller/passwall_device.lua files/usr/share/rpcd/acl.d/luci-app-passwall-device.json files/usr/share/passwall-device/VERSION 2>/dev/null || true
echo "--- 编译树 VERSION ---"
cat files/usr/share/passwall-device/VERSION

echo "===== [3] argon 默认亮色 (files/etc/config/argon) ====="
mkdir -p files/etc/config
cat > files/etc/config/argon <<'EOF'
config global
	option login_style 'classic'
	option primary '#5e72e4'
	option dark_primary '#483d8b'
	option blur '10'
	option blur_dark '10'
	option transparency '0.5'
	option transparency_dark '0.5'
	option mode 'light'
	option online_wallpaper 'bing'
EOF
cat files/etc/config/argon

echo "===== [4] 基线脚本增加 argon 亮色强制 ====="
cat > files/etc/init.d/passwall-baseline <<'EOF'
#!/bin/sh /etc/rc.common
# 固件基线 - 每次开机无条件强制应用(开机最后阶段 S99 执行, 无线已就绪)
# 2.4G 禁用; 5G=AA_5G/asd12345; root密码=root; 主题=argon亮色+中文; IPv6关闭; quickstart 不抢默认页
START=99
STOP=01

apply_baseline() {
	# 1) 无线: 2.4G 禁用; 5G=AA_5G/asd12345（SSID/加密/密码必须设置在 wifi-iface 上）
	[ -s /etc/config/wireless ] || wifi config 2>/dev/null || true
	for r in $(uci -q show wireless 2>/dev/null | sed -n 's/^wireless\.\(radio[0-9][0-9]*\)=wifi-device$/\1/p'); do
		band="$(uci -q get wireless.$r.band 2>/dev/null)"
		iface="$(uci -q show wireless 2>/dev/null | sed -n "s/^wireless\.\([a-zA-Z0-9_]*\)\.device='$r'$/\1/p" | head -n1)"
		[ -z "$iface" ] && iface="default_$r"
		case "$band" in
			5g)
				uci -q set wireless.$r.disabled='0'
				uci -q set wireless.$iface.disabled='0'
				uci -q set wireless.$iface.ssid='AA_5G'
				uci -q set wireless.$iface.encryption='psk2'
				uci -q set wireless.$iface.key='asd12345'
				;;
			2g)
				uci -q set wireless.$r.disabled='1'
				uci -q set wireless.$iface.disabled='1'
				;;
		esac
	done
	uci -q commit wireless 2>/dev/null || true
	[ -s /etc/config/wireless ] && /etc/init.d/wifi reload >/dev/null 2>&1 || true

	# 2) root 密码 -> root（直接写 shadow，确定性）
	sed -i 's|^root:.*|root:$1$QUXHQx.n$mkasdtRiIdGx5KFkTorth.:19000:0:99999:7:::|' /etc/shadow 2>/dev/null || true

	# 3) 主题 -> argon 亮色 + 中文界面 + 资源路径
	if [ -d /www/luci-static/argon ]; then
		uci -q set luci.main.mediaurlbase='/luci-static/argon'
	fi
	uci -q set luci.main.lang='zh-cn'
	uci -q set luci.main.resourcebase='/luci-static/resources'
	uci -q set luci.main.ubuspath='/ubus/'
	uci -q set argon.global.mode='light'
	uci -q commit luci 2>/dev/null || true
	uci -q commit argon 2>/dev/null || true

	# 4) 关闭 IPv6
	for i in $(uci -q show network | grep "\.ipv6='auto'" | sed "s/\(network\.[a-z0-9_]*\)\..*/\1/"); do
		uci -q set "$i.ipv6='0'"
	done
	uci -q delete network.globals.ula_prefix 2>/dev/null || true
	uci -q set dhcp.lan.dhcpv6='disabled' 2>/dev/null || true
	uci -q commit network 2>/dev/null || true
	uci -q commit dhcp 2>/dev/null || true
	mkdir -p /etc/sysctl.d
	cat > /etc/sysctl.d/99-ipv6-off.conf <<'CONF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
CONF

	# 5) quickstart 是全屏向导，会吞掉侧边菜单；禁用它，让后台默认落在标准状态页(有菜单)
	if [ -x /etc/init.d/quickstart ]; then
		/etc/init.d/quickstart disable 2>/dev/null || true
		/etc/init.d/quickstart stop 2>/dev/null || true
	fi

	exit 0
}

start() {
	apply_baseline
}
EOF
chmod +x files/etc/init.d/passwall-baseline
grep -n "argon\|mode" files/etc/init.d/passwall-baseline | head -6

echo "===== [5] 版本号 -> 10.22.2026 ====="
sed -i 's/^REVISION:=.*/REVISION:=10.22.2026/' include/version.mk
grep '^REVISION' include/version.mk

echo "===== [6] 增量编译 ====="
make -j4 > /root/build-v6.log 2>&1
EX=$?
echo "[build-v6] make exit=$EX $(date '+%H:%M:%S')"
tail -8 /root/build-v6.log
[ $EX -ne 0 ] && exit 1

echo "===== [7] 产物与 rootfs 验证 ====="
ls -la bin/targets/qualcommax/ipq807x/ | grep -E 'sysupgrade|factory'
sha256sum bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
echo "--- 插件版本 ---"
cat "$R/usr/share/passwall-device/VERSION"
echo "--- argon mode ---"
grep "mode" "$R/etc/config/argon"
echo "--- 基线链接 ---"
ls "$R/etc/rc.d/" | grep -i baseline
echo "--- 版本 ---"
cat "$R/etc/openwrt_version"
echo

echo "===== [8] 部署 VER=10.22.2026 ====="
sed -i 's/^VER=.*/VER=10.22.2026/' /root/deploy_firmware.sh
grep '^VER=' /root/deploy_firmware.sh
bash /root/deploy_firmware.sh

echo "===== [9] 站点验证 ====="
curl -s http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/version.txt
echo
ls -la /var/www/passwall-editor/firmware/qualcommax-ipq807x/redmi_ax6/
curl -s -o /tmp/v6-check.bin http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/kwrt-10.22.2026-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
sha256sum /tmp/v6-check.bin
echo "=== V6_DONE ==="
