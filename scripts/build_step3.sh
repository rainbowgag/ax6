#!/bin/bash
# ============================================================
# 第二轮定制: passwall-device 0.8.5 + argon 主题 + 关 IPv6
#              + 无线(2.4G 禁用 / 5G AA_5G asd12345) + 版本 10.18.2026
# ============================================================
set -e
cd /root/openwrt-2512 || exit 1

echo "===== [1] 更新 passwall-device 插件文件 (0.8.5) ====="
cp -a /root/passwall-editor/passwall-device-control/root/. files/
cp -p files/etc/config/passwall_device files/usr/share/passwall-device/default-config
chmod 755 files/etc/init.d/passwall-device files/usr/share/passwall-device/*.sh files/usr/share/passwall-device/app.lua
chmod 644 files/usr/lib/lua/luci/controller/passwall_device.lua files/usr/share/rpcd/acl.d/luci-app-passwall-device.json files/usr/share/passwall-device/VERSION
echo "插件版本: $(cat files/usr/share/passwall-device/VERSION)"

echo "===== [2] 版本号 -> 10.18.2026 ====="
sed -i 's/^REVISION:=.*/REVISION:=10.18.2026/' include/version.mk
grep '^REVISION:=' include/version.mk

echo "===== [3] files/ 覆盖: luci argon + wifi + ipv6 ====="
mkdir -p files/etc/config files/etc/uci-defaults
cat > files/etc/config/luci <<'EOF'
config core 'main'
	option lang 'auto'
	option mediaurlbase '/luci-static/argon'
EOF

cat > files/etc/uci-defaults/99-wifi <<'EOF'
#!/bin/sh
# 无线: 禁用 2.4G; 5G -> AA_5G / asd12345
[ -s /etc/config/wireless ] || wifi config 2>/dev/null
for r in $(uci -q show wireless 2>/dev/null | grep "\.band='2g'" | sed "s/\(wireless\.radio[0-9]*\)\..*/\1/"); do
	uci set "$r.disabled='1'"
done
for r in $(uci -q show wireless 2>/dev/null | grep "\.band='5g'" | sed "s/\(wireless\.radio[0-9]*\)\..*/\1/"); do
	uci set "$r.disabled='0'"
	uci set "$r.ssid='AA_5G'"
	uci set "$r.encryption='psk2'"
	uci set "$r.key='asd12345'"
done
uci -q commit wireless 2>/dev/null || true
exit 0
EOF

cat > files/etc/uci-defaults/98-ipv6-off <<'EOF'
#!/bin/sh
# 关闭 IPv6
for s in $(uci -q show network 2>/dev/null | grep "\.ipv6='1'" | sed "s/\(network\.[a-z0-9_]*\)\..*/\1/"); do
	uci set "$s.ipv6='0'"
done
uci -q delete network.globals.ula_prefix 2>/dev/null || true
uci -q commit network 2>/dev/null || true
/etc/init.d/odhcpd disable 2>/dev/null || true
cat >> /etc/sysctl.conf <<'SYS'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
SYS
exit 0
EOF
chmod +x files/etc/uci-defaults/99-wifi files/etc/uci-defaults/98-ipv6-off
ls files/etc/uci-defaults/

echo "===== [4] .config 追加 ====="
cat >> .config <<'EOF'

# === 自定义 v2: argon 主题 + 移除 odhcpd(ipv6) ===
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_DEFAULT_odhcpd-ipv6only=n
CONFIG_PACKAGE_odhcpd-ipv6only=n
EOF

echo "===== [5] defconfig ====="
make defconfig > /tmp/defconfig-v2.log 2>&1 || { tail -30 /tmp/defconfig-v2.log; exit 1; }

echo "===== [6] 校验 ====="
grep -E '^CONFIG_PACKAGE_luci-theme-argon=' .config
grep -E '^CONFIG_PACKAGE_luci-app-argon-config=' .config
grep -E '^CONFIG_(DEFAULT_)?odhcpd-ipv6only=' .config
grep -E '^CONFIG_TARGET_(BOARD|SUBTARGET)=' .config
grep -E '^CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=' .config
echo "===== V2_CONFIG_DONE ====="
