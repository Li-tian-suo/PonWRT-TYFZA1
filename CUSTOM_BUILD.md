# TYFZA1 自定义云编译（iperf / USB 共享 / USB 存储 / UU / OpenClash 依赖）

本文件说明本 fork 的自定义构建配置、改动内容、使用方法，以及“某些软件包为什么编译不进固件”的原因分析。

## 1. 改动内容

| 文件 | 作用 |
| --- | --- |
| `port/configs/tyfza1-compat.config` | 必须选入固件的软件包清单；构建时逐条校验，缺失即失败 |
| `port/configs/tyfza1-optional.config` | 可选增强包（ttyd、文件管理、lsusb）；缺失只告警不失败 |
| `configs/tyfza1-full.config` | 自定义镜像配置（使用 `dnsmasq-full`，其余同默认镜像） |
| `port/scripts/prepare-extra-packages.sh` | 按固定 tag + SHA-256 拉取 `luci-app-openclash` 源码 |
| `port/scripts/build.sh` | 构建前准备第三方包；`make world` 之后单独编译 OpenClash APK |
| `scripts/package_release.sh` | 把第三方 APK 复制进发布目录并计入 `SHA256SUMS` |
| `.github/workflows/build-release.yml` | 发布时附带 `packages/*.apk` |
| `RELEASE_NOTES.md` | 新增 `v0.8.2-full.1` 版本说明 |

## 2. 云编译方法

### 2.1 触发

GitHub → 本仓库 → **Actions → Build TYFZA1 firmware → Run workflow**：

| 输入 | 值 |
| --- | --- |
| `release_tag` | `v0.8.2-full.1`（必须与 `RELEASE_NOTES.md` 中 `## v...` 段一致） |
| `config_file` | `configs/tyfza1-full.config` |
| `replace_release` | 首次不勾选；重建同一版本时勾选 |

也可以用 API 触发：

```sh
gh workflow run build-release.yml \
  -f release_tag=v0.8.2-full.1 \
  -f config_file=configs/tyfza1-full.config
```

构建约 2–4 小时。产物：

- `Releases`：`sysupgrade.bin`、`tyfza1-telnet-install.tar.gz`、`SHA256SUMS`、`packages/luci-app-openclash-*.apk`
- `Artifacts → firmware-and-build-log`：同上 + `build.log`（完整编译日志）

### 2.2 构建链路

```
prepare.sh          -> 固定 commit 79bc56cb 的 OpenWrt 源码
sync-overlay.sh     -> 设备 overlay + 自定义 .config + compat/optional 依赖合并
prepare-extra-packages.sh -> 拉取 luci-app-openclash、netspeedtest 源码到 package/
prepare_luci_feeds  -> packages/luci feed + Argon 主题
make defconfig      -> 解析依赖，汇总报告所有被丢弃的 compat 包
make world          -> 内核、rootfs、全部 =y 软件包
make package/<第三方包>/compile -> 单独产出 APK（不进镜像）
package_release.sh  -> sysupgrade.bin + APK + SHA256SUMS
```

## 3. 固件内已包含的包

- **工具**：iperf、iperf3、htop、ethtool、pciutils、jq、curl、wget-ssl、tar、unzip、bash、ip-full、fdisk、hd-idle、tcpdump
- **网页终端**：`ttyd` + `luci-app-ttyd`（LuCI 服务 → 终端）
- **文件管理**：`luci-app-filemanager`（LuCI 系统 → 文件管理，基于 `rpcd-mod-file`）
- **VLAN**：内核 `CONFIG_VLAN_8021Q=y`（generic config），可在 **网络 → 接口 → 设备** 新建 802.1q 设备
- **USB 存储**：`kmod-usb3`、`kmod-usb-storage(-extras/-uas)`、`kmod-fs-exfat`、`kmod-fs-ntfs3`、`kmod-fs-ext4`、`kmod-fs-f2fs`、`kmod-fs-vfat`、`kmod-fuse`、`block-mount`、`e2fsprogs`、`dosfstools`、`exfat-mkfs`、`exfat-fsck`、`ntfs-3g`、`f2fs-tools`
- **USB 网络共享**：`kmod-usb-net`、`rndis`、`cdc-ether/eem/subset/ncm`、`cdc-mbim`、`qmi-wwan`、`ipheth`、`huawei-cdc-ncm`、`sierrawireless`、`rtl8152`、`usb-wdm`、`usb-acm`、`usb-serial(-option/-wwan)`、`umbim`、`uqmi`、`comgt`、`luci-proto-qmi/mbim/ncm/3g`
- **UU 依赖**：`kmod-tun`、`kmod-nf-conntrack-netlink`、`kmod-nf-nathelper(-extra)`、`kmod-ipt-raw`、`kmod-ipt-nat`、`kmod-nft-nat`、`iptables-mod-extra`、`iptables-mod-nat-extra`
- **OpenClash 依赖**：`dnsmasq-full`（nftset + DNSSEC）、`ip-full`、`bash`、`curl`、`unzip`、`ruby`、`ruby-yaml`、`luci-compat`、`luci-lua-runtime`、`luci-lib-ipkg`、`ipset`、`kmod-inet-diag`、`kmod-nft-tproxy`、`kmod-nft-socket`
- **可选（存在依赖问题时自动跳过）**：`usbutils`（lsusb）、`libudev-zero`、`hwdata`
- **Release 附带的独立 APK**：`luci-app-openclash`、`luci-app-netspeedtest` + `homebox` + `ookla-speedtest`（HomeBox 内网测速）
- **原有基础**：VPN（WireGuard/OpenVPN）、SQM、多 WAN、内网穿透所需的内核模块与运行库

## 4. 为什么有些软件包“编译不进固件”

### 4.1 rootfs 只有 32 MiB（最主要原因）

镜像构建阶段有硬性检查（`port/overlay/target/linux/rtl9617c/image/Makefile:19-25`）：

```make
define Build/tyfza1-rootfs-size
	[ "$$size" -le 33648640 ] || exit 1
```

33,648,640 字节 = **32.09 MiB**，对应原厂 `ubi_r0/r1` 卷大小，内核卷另有 6 MiB 上限。默认镜像 rootfs 约 8.07 MiB（`port/APK_COMPATIBILITY.md`），所以可用余量约 24 MiB。

- `luci-app-openclash` 0.48.002 展开后 **22.36 MiB**，其中 `GeoSite.dat` 9.93 MiB、内置 UI（zashboard/metacubexd）约 6 MiB；加上 ruby、dnsmasq-full 等依赖后必然超过上限。
- 结论：**体积大的应用改成独立 APK**，安装到可写 overlay（约 183 MiB）。本方案正是如此。

### 4.2 官方 feed 里根本没有这些包

`configs/feeds.conf` 只固定了两个 feed：

```
src-git packages https://git.openwrt.org/feed/packages.git^db09fc6
src-git luci     https://git.openwrt.org/project/luci.git^86d1549
```

`luci-app-openclash`、`uuplugin` 属于第三方（vernesong / 网易），不在官方 feed 中。直接写 `CONFIG_PACKAGE_luci-app-openclash=y` 的结果是：`make defconfig` 找不到包，静默丢弃该选项，随后构建脚本的校验直接报错退出。

另外 OpenClash 仓库历史体积约 45 GB，用 `src-git` 方式 `feeds update` 会全量克隆，不现实；因此本项目改为**下载固定 tag 的源码压缩包并校验 SHA-256**。

### 4.3 构建脚本“逐条校验”，依赖不满足就失败

`port/scripts/build.sh` 在 `make defconfig` 之后会检查 `tyfza1-compat.config` 里每一条 `CONFIG_PACKAGE_*=y`，并把**所有**被 Kconfig 丢弃的项一次性列出来：

```
Required packages missing after defconfig:
  CONFIG_PACKAGE_xxx=y
```

也就是说：**只要某个必需包的依赖链在本 target 上不成立，整个构建就失败**，不会出现“固件能出来但插件悄悄没了”的情况。可选包（`tyfza1-optional.config`）只打印 `WARNING: optional package dropped`，不中断构建。

### 4.4 Kconfig 依赖裁剪 / 名称冲突（真实案例）

- **虚拟依赖**：`usbutils` 声明 `DEPENDS:=+libusb-1.0 +libudev +usbids`，其中 `libudev` 不是真实包名，而由 `libudev-zero` `PROVIDES` 提供。Kconfig 只认真实符号，实际构建中 `usbutils` 因此被静默丢弃（构建日志第一版报错就是 `CONFIG_PACKAGE_usbutils=y` 缺失）。本仓库把它移入可选清单并显式选入 `libudev-zero`/`hwdata`/`libusb-1.0` 作为兜底。
- `dnsmasq` 与 `dnsmasq-full` 都 `PROVIDES:=dnsmasq`，同时选中会互相顶掉；必须显式 `# CONFIG_PACKAGE_dnsmasq is not set`，本仓库的 `configs/tyfza1-full.config` 已处理。
- `ip-tiny` 与 `ip-full` 同样提供 `ip`，只能二选一。
- `kmod-*` 依赖内核配置：`kmod-usb-net-rndis` 需要 `CONFIG_USB_NET_RNDIS_HOST`（由 `kmod-usb-net` 带入）、`kmod-usb-wdm`、`CONFIG_USB` 等；本 target 的 `config-6.18` 只写了 `CONFIG_USB_SUPPORT=y`，其余由 kmod 包自己的 `KCONFIG` 合并进内核配置，缺一环就会被裁剪。
- 少数软件包被标记 `BROKEN` 或依赖 x86/特定硬件，本 target 上直接不可选。

### 4.5 内核版本与 ABI 绑定

固件内核是 **Linux 6.18.55（自建 target）**，而 `downloads.openwrt.org` 的 snapshot kmod 是别的 target/kernel 编译的，`vermagic` 不匹配，**不能事后 `apk add` 安装**。因此所有内核模块必须在树内一起编译进镜像，这也是为什么 compat 清单里要一次性写全所有 `kmod-*`。

### 4.6 APK 与旧 IPK 不兼容

该 snapshot 已切换到 **apk** 包管理器，而恩山/网盘上大量第三方插件仍是 `.ipk`（opkg 格式）。即使放进固件也无法安装，必须针对 `aarch64_cortex-a55` + musl 重新编译成 `.apk`。本仓库为 OpenClash 单独出厂 APK 就是这个原因；包用构建密钥签名，公钥已由 `package/base-files` 安装到 `/etc/apk/keys/`，设备可直接信任。

### 4.7 LuCI 版本（Lua 页面）

OpenClash 0.48 仍是 Lua/CBI 页面（`luasrc/`），需要 `luci-compat` + `luci-lua-runtime`。当前固定版本的 luci feed 仍提供这两个包，所以可以正常构建/运行；若将来 LuCI 完全移除 Lua 运行时，该类插件就需要改写或改用其他代理前端。

### 4.8 闭源二进制（UU）

`uuplugin` 是网易的闭源可执行文件，**既无法从源码编译，也不适合随固件再分发**。因此固件只预置它需要的运行依赖（TUN、conntrack-netlink、NAT helper、iptables 扩展），插件本体由官方脚本按需下载：

```sh
wget -O /etc/init.d/uu https://raw.githubusercontent.com/PKC278/openwrt-uuplugin/main/uu.init
chmod +x /etc/init.d/uu
service uu enable && service uu start
```

注意：UU 需要关闭“硬件流量卸载”。

### 4.9 snapshot 里已没有 `usb-modeswitch`

固定版本的 packages feed 中不存在 `usb-modeswitch` 包（社区已移除相关打包），因此无法把“3G/4G 上网卡模式切换”编进固件。常见 RNDIS/NCM/MBIM/QMI 设备（手机共享、HiLink 类上网卡）本身就以网卡模式枚举，不受影响；确需切换的老式 modem 只能手动 `usb_modeswitch` 或外装。

## 5. 刷机后使用

### 5.1 iperf3

```sh
iperf3 -s            # 设备做服务端
iperf3 -c 192.168.1.2 -t 30 -P 4
iperf  -c 192.168.1.2 -t 30    # 老版 iperf2
```

### 5.2 USB 网络共享（手机 / 上网卡）

1. 用数据线把手机接到光猫 USB 口，手机开启“USB 网络共享”。
2. `lsusb`、`ip link` 查看新增网卡（通常 `usb0` / `eth1`）。
3. LuCI **网络 → 接口 → 添加新接口**，协议选 **DHCP 客户端**，设备选该网卡；或用命令行：

```sh
uci set network.usbt=interface
uci set network.usbt.proto='dhcp'
uci set network.usbt.device='usb0'
uci commit network && /etc/init.d/network reload
```

- 安卓 RNDIS：`kmod-usb-net-rndis`
- iOS：`kmod-usb-net-ipheth`
- NCM/MBIM/QMI 上网卡：`luci-proto-ncm` / `luci-proto-mbim` / `luci-proto-qmi`（`umbim`、`uqmi` 已装）

### 5.3 USB 存储（exFAT / NTFS3 / ext4 / F2FS）

```sh
block info                 # 查看分区与文件系统
block detect | uci import fstab
uci set fstab.@mount[0].enabled='1'
uci commit fstab && /etc/init.d/fstab restart
```

- exFAT：`kmod-fs-exfat` + `exfat-mkfs` / `exfat-fsck`（`mkfs.exfat`、`fsck.exfat`）
- NTFS：优先内核 `ntfs3`；兼容性优先时用 `ntfs-3g`（FUSE）
- ext4 / F2FS：`e2fsprogs`、`f2fs-tools`

### 5.4 OpenClash

从 Release 下载 `luci-app-openclash-*.apk`，上传到设备后：

```sh
apk add /tmp/luci-app-openclash-0.48.002-r1.apk
```

安装后把内核（mihomo / clash meta）放到 `/etc/openclash/core/` 并赋可执行权限，再在 LuCI **服务 → OpenClash** 中启用。内核体积大且需自行选择版本，固件与 APK 都不内置。

### 5.5 网页终端（ttyd）

LuCI **服务 → 终端**，默认监听 `0.0.0.0:7681`；也可以命令行 `ttyd -p 7681 login`。首次使用前在 **系统 → 管理权** 设置 root 密码。

### 5.6 文件管理

LuCI **系统 → 文件管理**（`luci-app-filemanager`），可浏览、上传/下载、编辑文本与十六进制、删除文件。后端使用 `rpcd-mod-file`，`luci-base` 已依赖，无需额外配置。

### 5.7 VLAN（802.1Q）

内核已内置 `CONFIG_VLAN_8021Q=y`，无需额外 kmod：

1. LuCI **网络 → 接口 → 设备** → **添加设备配置** → 类型选 **802.1Q VLAN**，选择父接口并填 VLAN ID。
2. 或命令行：

```sh
ip link add link lan1 name lan1.100 type vlan id 100
ip link set lan1.100 up
uci set network.vlan100=device
uci set network.vlan100.name='lan1.100'
uci set network.vlan100.type='8021q'
uci set network.vlan100.ifname='lan1'
uci set network.vlan100.vid='100'
uci commit network && /etc/init.d/network reload
```

### 5.8 HomeBox 内网测速

Release 附带 3 个 APK：`luci-app-netspeedtest`、`homebox`、`ookla-speedtest`。应用依赖 Python 3 模块，先联网安装依赖再装本地包：

```sh
apk update
apk add python3-light python3-pkg-resources python3-xml python3-email python3-urllib python3-codecs python3-openssl
apk add /tmp/luci-app-netspeedtest-*.apk /tmp/homebox-*.apk /tmp/ookla-speedtest-*.apk
```

装好后在 LuCI **网络 → 网速测试** 中打开 HomeBox / iperf3 / 在线测速。三者合计约 30 MiB，安装在 183 MiB 的 overlay 数据卷中，不占用只读 rootfs。

## 6. 已知限制

- rootfs 只读区固定 32.09 MiB，无法通过本配置继续塞入大型应用；扩展请走 overlay 或 USB 存储。
- UU 插件、Clash 内核与 HomeBox/ookla 测速组件均为独立安装或运行时下载，首次使用需要设备能访问外网。
- 硬件流量卸载与 UU/部分代理功能可能冲突，必要时在 **网络 → 防火墙** 关闭。
- 本设备 USB 控制器为 xHCI 主机模式，只能作为 USB 主机（接手机 / 上网卡 / U 盘），不能反向以 RNDIS 网卡模式被电脑识别。
