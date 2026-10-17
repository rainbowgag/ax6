#!/bin/bash
# 修复 diy.sh 因 git_clone_path 未定义而失败的部分
set -x
apt-get install -y jq > /dev/null 2>&1 || true

echo "===== [1] 补 immortalwrt openssl + ppp (sparse clone) ====="
rm -rf /tmp/imw
git clone --depth 1 --filter=blob:none --sparse -b openwrt-25.12 https://github.com/immortalwrt/immortalwrt.git /tmp/imw > /tmp/imw-clone.log 2>&1
echo "imw clone exit=$?"
cd /tmp/imw || exit 1
git sparse-checkout set package/libs/openssl package/network/services/ppp > /tmp/imw-sparse.log 2>&1
echo "sparse exit=$?"
ls package/libs/openssl/Makefile package/network/services/ppp/Makefile > /tmp/imw-check.txt 2>&1
cat /tmp/imw-check.txt

cd /root/openwrt-2512 || exit 1
rm -rf package/libs/openssl package/network/services/ppp
cp -a /tmp/imw/package/libs/openssl package/libs/
cp -a /tmp/imw/package/network/services/ppp package/network/services/
echo "openssl/ppp copied"
ls package/libs/openssl/Makefile package/network/services/ppp/Makefile

echo "===== [2] 补 lede hack-6.12 overlay (sparse clone) ====="
rm -rf /tmp/lede
git clone --depth 1 --filter=blob:none --sparse -b master https://github.com/coolsnowwolf/lede.git /tmp/lede > /tmp/lede-clone.log 2>&1
echo "lede clone exit=$?"
cd /tmp/lede || exit 1
git sparse-checkout set target/linux/generic/hack-6.12 target/linux/generic/pending-6.12 > /tmp/lede-sparse.log 2>&1
echo "lede sparse exit=$?"

cd /root/openwrt-2512 || exit 1
rm -rf target/linux/generic/hack-6.12
cp -a /tmp/lede/target/linux/generic/hack-6.12 target/linux/generic/
rm -rf target/linux/generic/hack-6.12/767-net-phy-realtek-add-led*
wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-6.12/613-netfilter_optional_tcp_window_check.patch -P target/linux/generic/pending-6.12/ > /tmp/pending-wget.log 2>&1
echo "hack-6.12 overlay done"
ls target/linux/generic/hack-6.12 | head -5

echo "===== 完成 ====="
