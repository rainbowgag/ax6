#!/bin/bash
cd /root/openwrt-2512 || exit 1
make -j4 > /root/build-v2.log 2>&1
EX=$?
echo "[build-v2] make exit=$EX $(date '+%H:%M:%S')"
tail -5 /root/build-v2.log
exit $EX
