#!/bin/bash
# v5 定制: 基线改为每次开机无条件强制应用(START=99, 无线就绪后执行) + 版本10.20.2026
set -e
cd /root/openwrt-2512 || exit 1
R=build_dir/target-aarch64_cortex-a53_musl/root-qualcommax

echo "===== [1] 版本号 -> 10.20.2026 ====="
sed -i 's/^REVISION:=.*/REVISION:=10.20.2026/' include/version.mk
grep '^REVISION' include/version.mk

echo "===== [2] 重写 passwall-baseline (每次开机无条件强制执行) ====="
mkdir -p files/etc/init.d
cat > files/etc/init.d/passwall-baseline <<'EOF'
#!/bin/sh /etc/rc.common
# 固件基线 - 每次开机无条件强制应用(开机最后阶段 S99 执行, 无线已就绪)
# 2.4G 禁用; 5G=AA_5G/asd12345; root密码=root; 主题=argon; IPv6关闭
START=99
STOP=01

apply_baseline() {
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
	[ -s /etc/config/wireless ] && /etc/init.d/wifi reload >/dev/null 2>&1 || true

	(echo 'root'; echo 'root') | passwd root >/dev/null 2>&1 || true

	if [ -d /www/luci-static/argon ]; then
		uci -q set luci.main.mediaurlbase='/luci-static/argon'
		uci -q commit luci 2>/dev/null || true
	fi

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
	exit 0
}

start() {
	apply_baseline
}
EOF
chmod +x files/etc/init.d/passwall-baseline
head -8 files/etc/init.d/passwall-baseline

echo "===== [3] 确认 shadow 预置仍在 files/ ====="
head -1 files/etc/shadow

echo "===== [4] 增量编译 (files 变更触发镜像重建) ====="
make -j4 > /root/build-v5.log 2>&1
EX=$?
echo "[build-v5] make exit=$EX $(date '+%H:%M:%S')"
tail -8 /root/build-v5.log
[ $EX -ne 0 ] && exit 1

echo "===== [5] 产物与 rootfs 验证 ====="
ls -la bin/targets/qualcommax/ipq807x/ | grep -E 'sysupgrade|factory'
sha256sum bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
ls -la "$R/etc/init.d/passwall-baseline"
ls "$R/etc/rc.d/" | grep -i baseline
cat "$R/etc/openwrt_version"

echo "===== [6] 部署 VER=10.20.2026 ====="
sed -i 's/^VER=.*/VER=10.20.2026/' /root/deploy_firmware.sh
grep '^VER=' /root/deploy_firmware.sh
bash /root/deploy_firmware.sh

echo "===== [7] 站点验证 ====="
curl -s http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/version.txt
echo
ls -la /var/www/passwall-editor/firmware/qualcommax-ipq807x/redmi_ax6/
curl -s -o /tmp/v5-check.bin http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/kwrt-10.20.2026-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
sha256sum /tmp/v5-check.bin
echo "=== V5_DONE ==="
