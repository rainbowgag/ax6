# Redmi AX6 定制 OpenWrt 固件编译包（Kwrt 25.12）

本仓库保存 Redmi AX6（qualcommax/ipq807x）定制固件的**编译配置与脚本**，用于在新 VPS 上从零复现固件构建。

## 固件特性（v10.19.2026 起）

| 项目 | 内容 |
|---|---|
| 源码 | kiddin9/Kwrt 分支 25.12，内核 6.12，squashfs |
| 目标 | Redmi AX6（qualcommax/ipq807x，aarch64_cortex-a53），仅此一个设备 |
| 后台地址 | **192.168.100.1**（首启脚本 00-lan-ip 设置，默认网段 192.168.100.0/24） |
| 登录账号 | **root / root**（files/etc/shadow 预置密码哈希 + 基线脚本双保险；升级后也保持 root/root） |
| PassWall 设备口令 | luci-app-passwall-device **0.8.5**（内置，服务→PassWall 设备口令；支持自更新） |
| 在线升级 | luci-app-gpsysupgrade，更新源指向自有服务器 `http://m.yaml.uk:25532/firmware` |
| 主题 | **Argon 3.0.0（2026-10-16 最新上游 jerrykuku）**，中文界面（luci-i18n-base-zh-cn + argon-config 中文） |
| IPv6 | **已关闭**（基线脚本/uci-defaults：接口 ipv6=0 + 删 ULA + sysctl 全局禁用） |
| 无线 | **2.4G 禁用**；**5G：SSID `AA_5G`，密码 `asd12345`**（WPA2-PSK） |
| 配置生效机制 | **版本基线自动应用**：`/etc/init.d/passwall-baseline` 检测到固件版本变化（含保留配置在线升级）时，自动重设无线/密码/主题/IPv6，之后用户可自由修改 |
| 其他 | PassWall（sing-box + xray-core）、iStore/istorex、TTYD、quickstart 等与测试机同款 |

## 目录结构

```
├── README.md                  # 本文件
├── config/
│   └── custom.config          # 自定义配置增量
├── files/                     # OpenWrt files/ 覆盖目录（编译时自动并入 rootfs）
│   ├── etc/config/            #   luci（argon 默认主题）、passwall_device 默认配置
│   ├── etc/init.d/            #   passwall-device、passwall-baseline（版本基线自动应用）
│   ├── etc/shadow             #   root 密码已预置哈希（root/root）
│   ├── etc/uci-defaults/      #   00-lan-ip、00-root-passwd、98-ipv6-off、99-wifi（首启自动配置）
│   └── usr/                   #   插件 Lua/页面/脚本
└── scripts/
    ├── build_step2.sh         # 配置装配：feeds 安装 + 组装 .config + 补丁 + 插件覆盖 + 升级源替换 + defconfig
    ├── build_step3.sh         # 第二轮定制：插件更新 + argon + 关 IPv6 + 无线 + 版本号
    ├── build_v3.sh            # 第三轮定制：后台地址 192.168.100.1 + root/root 密码
    ├── build_v4.sh            # 第四轮定制：版本基线自动应用 + 最新 argon（含中文）+ 密码预置
    ├── fix_diy.sh             # 修复 diy.sh 依赖
    ├── fresh_defconfig.sh     # 全新元数据 + 组装配置 + defconfig
    ├── run_build.sh           # 编译入口（-j4，失败回退 -j1 V=s）
    ├── run_build_v2.sh        # 增量重编入口
    └── deploy_firmware.sh     # 部署到在线升级站点（注意修改 VER）
```

## 在新 VPS 上编译（Ubuntu 22.04，建议 ≥4C/8G/60G 磁盘）

```bash
# 1. 基础依赖
apt update && apt install -y build-essential git curl wget jq file python3 unzip \
    gawk gettext libncurses5-dev zlib1g-dev libssl-dev rsync gcc-multilib \
    bison flex patch gzip bzip2 tar xz-utils

# 2. 克隆源码（25.12 分支）
git clone -b 25.12 https://github.com/kiddin9/Kwrt.git /root/openwrt-2512
cd /root/openwrt-2512

# 3. 初始化（feeds 更新）
./scripts/feeds update -a
./scripts/feeds install -a -p kiddin9 -f

# 4. 把本仓库内容放到编译树
cp -r files/* /root/openwrt-2512/files/          # 覆盖目录（含插件 + 定制 + shadow + 基线脚本）
cp scripts/* /root/                               # 脚本

# 5. 配置（如 diy.sh 报 git_clone_path 错，先执行 fix_diy.sh）
bash /root/fix_diy.sh
bash /root/build_step2.sh    # 组装 .config + 插件覆盖 + 升级源替换 + defconfig
bash /root/build_v4.sh       # argon/ipv6/无线/密码/基线 + 版本号 + defconfig

# 6. 编译（首次约 3 小时；之后增量很快）
export FORCE_UNSAFE_CONFIGURE=1
make -j4 2>&1 | tee /root/build.log

# 7. 产物
#    /root/openwrt-2512/bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
#    （另有 factory.ubi / initramfs-factory.ubi）

# 8. 部署到升级站点（先改 deploy_firmware.sh 里的 VER 为本次版本号）
bash /root/deploy_firmware.sh
```

> 配置生效说明：**全新刷机**时 uci-defaults 首启执行；**保留配置在线升级**时，`/etc/init.d/passwall-baseline` 检测到固件版本变化后自动重设无线/密码/主题/IPv6（旧配置会被新版本基线覆盖一次，之后用户可自由修改）。

## 版本号说明

- 版本号取编译日期：`include/version.mk` 里 `REVISION:=<日.月.年>`（如 10.19.2026）。
- 每次发布新固件**必须提升版本号**，否则客户端在线升级检测不到更新。
- 服务器 `version.txt` 内容必须与固件 `/etc/openwrt_version` 一致。

## 在线升级机制

- 客户端：系统 → 在线升级（luci-app-gpsysupgrade）。
- 服务器：`http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/`
  - `version.txt`：DD.MM.YYYY（如 `10.19.2026`）
  - `kwrt-<版本>-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin`：固件
  - `updatelogs.txt`：更新日志
- nginx 站点：`/etc/nginx/sites-available/passwall-editor`（listen 25532，root `/var/www/passwall-editor`）

## 变更记录

- 2026-10-18 v10.19.2026：修复保留配置升级后定制不生效（新增版本基线自动应用机制 passwall-baseline）；argon 升级为上游最新 3.0.0（2026-10-16，中文界面）；root 密码改为 shadow 预置哈希，保证 root/root；无线/密码/主题仍为 2.4G 禁、5G=AA_5G/asd12345、argon。
- 2026-10-17 v10.18.2026：后台地址 192.168.100.1，root/root；passwall-device 0.8.5；argon 主题；关 IPv6；2.4G 禁用；5G = AA_5G/asd12345。
- 2026-10-17 v10.17.2026：首版编译（passwall-device 0.8.1 内置 + 在线升级 m.yaml.uk:25532）。
