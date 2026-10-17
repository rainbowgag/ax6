#!/bin/bash
# 正式编译 runner：先并行 -j4，失败回退 -j1 V=s
# 以 root 构建需绕过 tar 等工具的 root 检查
export FORCE_UNSAFE_CONFIGURE=1
cd /root/openwrt-2512 || exit 1
LOG=/root/build.log
echo "[build] start $(date '+%F %T')" >> "$LOG"
make -j4 >> "$LOG" 2>&1
RC=$?
echo "[build] make -j4 exit=$RC $(date '+%F %T')" >> "$LOG"
if [ $RC -ne 0 ]; then
  echo "[build] fallback -j1 V=s $(date '+%F %T')" >> "$LOG"
  make -j1 V=s >> "$LOG" 2>&1
  echo "[build] fallback exit=$? $(date '+%F %T')" >> "$LOG"
fi
echo "[build] done $(date '+%F %T')" >> "$LOG"
