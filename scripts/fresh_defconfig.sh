#!/bin/bash
# 全新元数据 + 组装配置 + defconfig
cd /root/openwrt-2512 || exit 1

echo "===== [1] 清空 tmp/ 重建元数据 ====="
rm -rf tmp/

echo "===== [2] 组装 .config ====="
cp -f devices/common/.config .config
cat devices/qualcommax_ipq807x/.config >> .config
cat >> .config <<'EOF'

# === 自定义: 只编译 Redmi AX6 ===
CONFIG_TARGET_ALL_PROFILES=n
CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=y

# === 自定义: PassWall + 在线升级 + 测试机同款应用 ===
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

echo "===== [3] 无线驱动调整 ====="
sed -n '/# Wireless Drivers/,/# end of Wireless Drivers/p' .config | sed -e 's/=m/=n/' >> .config
sed -i "s/\(kmod-qca.*\)=m/\1=n/" .config

echo "===== [4] make defconfig ====="
make defconfig > /tmp/fresh-defconfig.log 2>&1
echo "defconfig exit=$?"

echo "===== [5] 校验 ====="
{
  echo "--- 目标 ---"
  grep -E '^CONFIG_TARGET_(BOARD|SUBTARGET|qualcommax|mediatek|ipq807x)=' .config
  echo "--- redmi_ax6 设备 ---"
  grep -E 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=' .config
  echo "--- 关键包 ---"
  grep -E '^CONFIG_PACKAGE_(luci-app-passwall|luci-app-gpsysupgrade|sing-box|xray-core|luci-app-store|luci-app-ttyd|luci-app-quickstart|luci-app-vantage)=' .config
  echo "--- recursive 错误数 ---"
  grep -c 'recursive dependency' /tmp/fresh-defconfig.log
} > /tmp/fresh-result.txt 2>&1
cat /tmp/fresh-result.txt
