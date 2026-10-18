#!/bin/bash
# ============================================================
# Kwrt 25.12 固件编译 - 第二阶段：装配配置 + 打补丁 + defconfig
# 目标设备: Redmi AX6 (qualcommax/ipq807x)
# ============================================================
set -x
cd /root/openwrt-2512 || exit 1

echo "===== [1/8] 安装 kiddin9 feed ====="
./scripts/feeds install -a -p kiddin9 -f || true

echo "===== [2/8] 运行目标设备 diy.sh ====="
bash devices/qualcommax_ipq807x/diy.sh || true

echo "===== [3/8] 组装 .config ====="
cp -f devices/common/.config .config
cat devices/qualcommax_ipq807x/.config >> .config

echo "===== [4/8] 应用补丁 (common + ipq807x) ====="
cp -rn devices/common/patches devices/qualcommax_ipq807x/ || true
find devices/qualcommax_ipq807x/patches -maxdepth 1 -type f -name '*.revert.patch' -print0 2>/dev/null | sort -z | xargs -I % -0 -n 1 sh -c "patch -d './' -R --no-backup-if-mismatch -p1 -F 1 -i '%'"
find devices/qualcommax_ipq807x/patches -maxdepth 1 -type f -name '*.patch' ! -name '*.revert.patch' ! -name '*.bin.patch' -print0 2>/dev/null | sort -z | xargs -I % -0 -n 1 sh -c "patch -d './' --no-backup-if-mismatch -p1 -F 1 -i '%'"

echo "===== [4b/8] DTS model 改名 Redmi AX9000 ====="
sed -i "s/model = "Redmi AX6"/model = "Redmi AX9000"/" target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq8071-ax6.dts

echo "===== [5/8] 拷贝 diy 自定义文件 ====="
cp -Rf ./diy/* ./ || true

echo "===== [6/8] 自定义配置追加 ====="
cat >> .config <<'EOF'

# === 自定义: 只编译 Redmi AX6 ===
CONFIG_TARGET_ALL_PROFILES=n
CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=y

# === 自定义: PassWall 设备控制 + 在线升级 + 测试机同款应用 ===
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-gpsysupgrade=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_luci-app-istorex=y
CONFIG_PACKAGE_luci-app-oui=y
CONFIG_PACKAGE_luci-app-quickstart=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-vantage=y
EOF

echo "===== [7/8] 覆盖 luci-app-passwall-device 插件文件 ====="
mkdir -p files
cp -a /root/passwall-editor/passwall-device-control/root/. files/
cp -p files/etc/config/passwall_device files/usr/share/passwall-device/default-config
chmod 755 files/etc/init.d/passwall-device files/usr/share/passwall-device/*.sh files/usr/share/passwall-device/app.lua
chmod 644 files/usr/lib/lua/luci/controller/passwall_device.lua files/usr/share/rpcd/acl.d/luci-app-passwall-device.json files/usr/share/passwall-device/VERSION

echo "===== [8/8] 改 gpsysupgrade 更新源为自有服务器 ====="
GP_DIR=$(find feeds/kiddin9 -maxdepth 1 -type d -name '*gpsysupgrade*' | head -1)
echo "gpsysupgrade dir: $GP_DIR"
if [ -n "$GP_DIR" ]; then
  grep -rl 'https://dl.openwrt.ai/firmware' "$GP_DIR" 2>/dev/null | while read -r f; do
    sed -i 's#https://dl.openwrt.ai/firmware#http://m.yaml.uk:25532/firmware#g' "$f"
    echo "patched: $f"
  done
fi

echo "===== defconfig (第一次) ====="
make defconfig > /root/build-defconfig1.log 2>&1 || { echo "defconfig 失败"; tail -30 /root/build-defconfig1.log; exit 1; }

echo "===== 无线驱动调整 ====="
sed -n '/# Wireless Drivers/,/# end of Wireless Drivers/p' .config | sed -e 's/=m/=n/' >> .config
sed -i "s/\(kmod-qca.*\)=m/\1=n/" .config

echo "===== defconfig (第二次) ====="
make defconfig > /root/build-defconfig2.log 2>&1 || { echo "defconfig2 失败"; tail -30 /root/build-defconfig2.log; exit 1; }

echo "===== 校验关键配置 ====="
grep -E '^CONFIG_TARGET_(BOARD|SUBTARGET|PROFILE)=' .config
grep -E '^CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=' .config
grep -E '^CONFIG_PACKAGE_(luci-app-passwall|luci-app-gpsysupgrade|sing-box|xray-core|luci-app-passwall-device|luci-app-store|luci-app-ttyd)=' .config
echo "===== 第二阶段完成 ====="
