# Redmi AX6 定制 OpenWrt 固件编译包（Kwrt 25.12）

本仓库保存 Redmi AX6（qualcommax/ipq807x）定制固件的**编译配置与脚本**，用于在新 VPS 上从零复现固件构建。

## 固件特性（v10.21.2026 起）

| 项目 | 内容 |
|---|---|
| 源码 | kiddin9/Kwrt 分支 25.12，内核 6.12，squashfs |
| 目标 | Redmi AX6（qualcommax/ipq807x，aarch64_cortex-a53），仅此一个设备 |
| 后台地址 | **192.168.100.1**（首启脚本 00-lan-ip 设置，默认网段 192.168.100.0/24） |
| 登录账号 | **root / root**（files/etc/shadow 预置哈希 + 基线脚本每次开机强制，双保险） |
| PassWall 设备口令 | luci-app-passwall-device **0.8.6**（内置，服务→PassWall 设备口令；支持自更新） |
| 在线升级 | luci-app-gpsysupgrade，更新源指向自有服务器 `http://m.yaml.uk:25532/firmware` |
| 主题 | **Argon 3.0.0（上游 jerrykuku）**，中文界面（luci-i18n-base-zh-cn + argon-config 中文）；**默认亮色模式**（argon.global.mode=light） |
| IPv6 | **已关闭**（基线脚本每次开机幂等禁用 + uci-defaults） |
| 无线 | **2.4G 禁用**；**5G：SSID `AA_5G`，密码 `asd12345`**（WPA2-PSK） |
| 配置生效机制 | **每次开机无条件强制应用**：`/etc/init.d/passwall-baseline`（S99，开机最后阶段执行，无线已就绪）每次开机重设无线/密码/主题/argon 亮色/IPv6 —— 无论全新刷机还是保留配置在线升级都生效 |
| 其他 | PassWall（sing-box + xray-core）、iStore/istorex、TTYD、quickstart 等与测试机同款 |

## 目录结构

```
├── README.md                  # 本文件
├── config/
│   └── custom.config          # 自定义配置增量
├── files/                     # OpenWrt files/ 覆盖目录（编译时自动并入 rootfs）
│   ├── etc/config/            #   luci（argon 默认主题）、argon（mode=light 亮色默认）、passwall_device 默认配置
│   ├── etc/init.d/            #   passwall-device、passwall-baseline（每次开机强制基线）
│   ├── etc/shadow             #   root 密码已预置哈希（root/root）
│   ├── etc/uci-defaults/      #   00-lan-ip、00-root-passwd、98-ipv6-off、99-wifi（首启自动配置）
│   └── usr/                   #   插件 Lua/页面/脚本
└── scripts/
    ├── build_step2.sh         # 配置装配：feeds 安装 + 组装 .config + 补丁 + 插件覆盖 + 升级源替换 + defconfig
    ├── build_step3.sh         # 第二轮定制：插件更新 + argon + 关 IPv6 + 无线 + 版本号
    ├── build_v3.sh            # 第三轮定制：后台地址 192.168.100.1 + root/root 密码
    ├── build_v4.sh            # 第四轮定制：版本基线自动应用 + 最新 argon（含中文）+ 密码预置
    ├── build_v5.sh            # 第五轮定制：基线改为每次开机无条件强制（S99）+ 版本 10.20.2026
    ├── build_v6.sh            # 第六轮定制：passwall-editor 0.8.6 + argon 默认亮色 + 版本 10.21.2026
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
bash /root/build_v6.sh       # 插件 0.8.6 + argon 亮色/ipv6/无线/密码/基线 + 版本号 + defconfig

# 6. 编译（首次约 3 小时；之后增量很快）
export FORCE_UNSAFE_CONFIGURE=1
make -j4 2>&1 | tee /root/build.log

# 7. 产物
#    /root/openwrt-2512/bin/targets/qualcommax/ipq807x/kwrt-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin
#    （另有 factory.ubi / initramfs-factory.ubi）

# 8. 部署到升级站点（先改 deploy_firmware.sh 里的 VER 为本次版本号）
bash /root/deploy_firmware.sh
```

> 配置生效说明：**每次开机** `/etc/init.d/passwall-baseline`（S99）无条件强制应用无线（2.4G 禁/5G=AA_5G+asd12345）、root 密码 root/root、argon 亮色主题、IPv6 关闭。因此无论全新刷机、保留配置在线升级，升级后重启即恢复为基线配置。若某设备需要例外，需修改基线脚本后重新发布固件。

## 版本号说明

- 版本号取编译日期：`include/version.mk` 里 `REVISION:=<日.月.年>`（如 10.21.2026）。
- 每次发布新固件**必须提升版本号**，否则客户端在线升级检测不到更新。
- 服务器 `version.txt` 内容必须与固件 `/etc/openwrt_version` 一致。

## 在线升级机制

- 客户端：系统 → 在线升级（luci-app-gpsysupgrade）。
- 服务器：`http://m.yaml.uk:25532/firmware/qualcommax-ipq807x/redmi_ax6/`
  - `version.txt`：DD.MM.YYYY（如 `10.21.2026`）
  - `kwrt-<版本>-qualcommax-ipq807x-redmi_ax6-squashfs-sysupgrade.bin`：固件
  - `updatelogs.txt`：更新日志
- nginx 站点：`/etc/nginx/sites-available/passwall-editor`（listen 25532，root `/var/www/passwall-editor`）

## 变更记录

- 2026-10-18 v10.21.2026：passwall-editor 升级 **0.8.6**（最新上游 bf18f73）；argon 主题**默认亮色模式**（argon.global.mode=light，files/etc/config/argon + 基线每次开机强制）；此前修复 WiFi SSID 未写入 wifi-iface、root 密码 shadow 格式残缺、中文界面缺 resourcebase 导致 JS 404、quickstart 抢默认页导致无菜单等问题。

- 2026-10-18 v10.20.2026：基线机制改为**每次开机无条件强制应用**（S99 开机最后执行，无线已就绪）：2.4G 禁/5G=AA_5G+asd12345/root密码root/argon/关IPv6 每次开机都会恢复，保证保留配置升级后也生效。
- 2026-10-18 v10.19.2026：新增版本基线自动应用机制 passwall-baseline；argon 升级为上游最新 3.0.0（2026-10-16，中文）；root 密码 shadow 预置。
- 2026-10-17 v10.18.2026：后台地址 192.168.100.1，root/root；passwall-device 0.8.5；argon 主题；关 IPv6；2.4G 禁用；5G = AA_5G/asd12345。
- 2026-10-17 v10.17.2026：首版编译（passwall-device 0.8.1 内置 + 在线升级 m.yaml.uk:25532）。
