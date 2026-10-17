#!/bin/bash
# 部署固件到在线升级站点（编译完成后执行）
set -e
TREE=/root/openwrt-2512
WEB=/var/www/passwall-editor
VER=10.18.2026
EXPECT="kwrt-${VER}-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin"
MODEL_DIR=$WEB/firmware/qualcommax-ipq807x/redmi_ax6

echo "===== [1] 查找构建产物 ====="
ls -la $TREE/bin/targets/qualcommax/ipq807x/ | grep -E 'sysupgrade|factory' || true

BIN=$(ls $TREE/bin/targets/qualcommax/ipq807x/*-squashfs-sysupgrade.bin 2>/dev/null | head -1)
if [ -z "$BIN" ]; then
  echo "!! 未找到 sysupgrade.bin"
  exit 1
fi
echo "产物: $BIN"

echo "===== [2] 部署到升级站点 ====="
mkdir -p "$MODEL_DIR"
cp -f "$BIN" "$MODEL_DIR/$EXPECT"
echo "$VER" > "$MODEL_DIR/version.txt"
echo "$(date '+%Y-%m-%d %H:%M') 固件更新至 $VER" >> "$WEB/firmware/updatelogs.txt"

echo "===== [3] 校验 ====="
sha256sum "$MODEL_DIR/$EXPECT"
ls -la "$MODEL_DIR/"
echo "===== 完成 ====="
