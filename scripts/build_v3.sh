#!/bin/bash
# v3 定制: LAN IP -> 192.168.100.1, root 密码 -> root, 重新编译部署
set -e
cd /root/openwrt-2512 || exit 1

echo "===== [1] 首启脚本: LAN IP = 192.168.100.1 ====="
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/00-lan-ip <<'EOF'
#!/bin/sh
# 设置默认后台地址 192.168.100.1（dhcp start/limit 为相对偏移，随网段自动匹配）
uci -q set network.lan.ipaddr='192.168.100.1'
uci -q set network.lan.netmask='255.255.255.0'
uci -q commit network
/etc/init.d/network reload 2>/dev/null || true
exit 0
EOF

echo "===== [2] 首启脚本: root 密码 = root ====="
cat > files/etc/uci-defaults/00-root-passwd <<'EOF'
#!/bin/sh
# 设置 root 默认密码为 root（首次开机生效）
echo -e 'root\nroot' | passwd root 2>/dev/null || true
exit 0
EOF
chmod +x files/etc/uci-defaults/00-lan-ip files/etc/uci-defaults/00-root-passwd
ls -la files/etc/uci-defaults/

echo "===== [3] 增量重新编译 (make -j4) ====="
make -j4 > /root/build-v3.log 2>&1
EX=$?
echo "[build-v3] make exit=$EX $(date '+%H:%M:%S')"
tail -6 /root/build-v3.log
[ $EX -ne 0 ] && exit 1

echo "===== [4] 产物校验 ====="
ls -la bin/targets/qualcommax/ipq807x/ | grep -E 'sysupgrade|factory'
sha256sum bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
R=build_dir/target-aarch64_cortex-a53_musl/root-qualcommax
ls $R/etc/uci-defaults/ | grep -E '^00-'

 echo "===== [5] 重新部署到升级站 ====="
 bash /root/deploy_firmware.sh
 echo "=== V3_DONE ==="
