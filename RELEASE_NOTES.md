## v0.8.2-full.7

### 大固件：OpenClash / HomeBox 等内置（rootfs 上限 128 MiB 生效）

- `luci-app-openclash`、`homebox`、`ookla-speedtest` 由独立 APK 改为**直接内置**。
- `luci-app-netspeedtest` 仍以 APK 提供：它依赖 `python3-email` / `python3-pkg-resources`，与固件使用的 `python3-light` 运行时无法同时选中。
- 依赖 128 MiB 的 rootfs 上限（见 `v0.8.2-full.6`），因此**必须先刷入 full.6 过渡固件**，再通过 sysupgrade 升级本版本。
- U-Boot 恢复网页仍限制 32 MiB，**不能**用恢复网页直接刷本版本。
- 升级后 rootfs 变大、`rootfs_data` 相应缩小（仍保留至少 16 MiB 数据卷余量）。

## v0.8.2-full.6

### 过渡固件：解除 32 MiB rootfs 限制（128 MiB 上限）

- `port/overlay/target/linux/rtl9617c/image/Makefile`：构建期 rootfs 上限 33,648,640 → **134,217,728** 字节。
- `port/overlay/target/linux/rtl9617c/base-files/lib/upgrade/tyfza1-storage.sh`：`tyfza1_plan_storage` 使用同一上限，sysupgrade 不再拒绝大镜像。
- 本版自身仍小于 32 MiB（squashfs 约 27 MiB），可以用 **U-Boot 恢复网页**刷入；刷入后即可用 sysupgrade 升级超过 32 MiB 的固件。
- 注意：U-Boot 恢复网页（`recovery.c`）仍写死 32 MiB 校验，**不要**用恢复网页直接刷大镜像。

## v0.8.2-full.5

### 新增系统工具（工具箱 / 定时重启 / 关机）

- 新增 `luci-app-systools`（OpenWrt 工具箱）：上网向导、IPv6 一键设置、旁路由模式、设备管理、LAN IP、网口管理、Home Assistant/Docker 相关页面。
- 新增 `luci-app-timedreboot`（定时重启）：按天/按周定时重启，带 `dorboot` 辅助脚本与开机自启。
- 新增 `luci-app-poweroffdevice`（单纯关机）：LuCI 页面一键执行 `/sbin/poweroff`，带二次确认。
- Argon Config 无需新增：`luci-app-argon-config` 早已随 Argon 主题进入固件，菜单位置为 **系统（System）→ Argon Config**。
- 三个插件均按 commit + SHA-256 固定源码，编进镜像（体积很小），不占用额外 APK。

## v0.8.2-full.4

### 同步上游原厂数据修复 + 保持自定义依赖

- 同步上游 `6528f6f`、`3439384` 两个原厂数据（factory）修复：
  - Active Ethernet（family 0）机型不再因缺少 PON 协议而在开机迁移中直接失败，改为告警并留空 PON 模式。
  - `config.xml` 缺失或为空时提前判定失败，避免写入不完整的本机身份。
  - `tyfza1-pon-control` 版本号提升到 0.8.2-r2。
- 软件包内容与 `v0.8.2-full.3` 相同：
  - 内核/工具：iperf、iperf3、htop、ethtool、pciutils、jq、curl、wget-ssl、tar(gzip)、unzip、bash、ip-full、fdisk、hd-idle。
  - USB 网络共享：rndis/cdc-ether/cdc-ncm/cdc-mbim/qmi/ipheth/华为/Sierra/RTL8152 + umbim/uqmi/comgt + LuCI 协议页。
  - USB 存储：exFAT/NTFS3/ext4/F2FS/VFAT/UAS + mkfs/fsck 工具、block-mount。
  - UU 依赖与 OpenClash 依赖（dnsmasq-full、ruby、luci-compat 等）。
  - 第二批：WireGuard/OpenVPN 工具、SQM、mwan3、DDNS、UPnP、WOL、nlbwmon、vnstat2、ksmbd、NFS、Python3、btrfs/xfs 工具、USB 串口/网卡驱动。
- 大型第三方应用仍以独立 APK 发布：`luci-app-openclash`、`luci-app-netspeedtest`、`homebox`、`ookla-speedtest`。

## v0.8.2-full.3

### 扩充依赖层（VPN / QoS / 多 WAN / 共享 / 诊断 / Python）

- 在 `v0.8.2-full.2` 基础上补充第二批常用依赖，全部放在可选清单，缺失只告警不中断构建。
- 直接装进固件（`=y`）：
  - VPN：`wireguard-tools`、`luci-proto-wireguard`、`openvpn-openssl`（内核 `kmod-wireguard`、`kmod-ovpn-backports` 原已预装）。
  - 网络功能：`sqm-scripts` + `luci-app-sqm`、`mwan3` + `luci-app-mwan3`、`ddns-scripts` + `luci-app-ddns`、`miniupnpd-nftables` + `luci-app-upnp`、`etherwake` + `luci-app-wol`。
  - 统计与诊断：`luci-app-commands`、`nlbwmon` + `luci-app-nlbwmon`、`vnstat` + `luci-app-vnstat2`、`luci-app-hd-idle`、`smartmontools`、`hdparm`、`lsof`、`openssl-util`、`socat`、`strace`、`irqbalance`、`zoneinfo-core/asia`。
  - 更多 USB 设备：`kmod-usb-serial-ch341/ch348/pl2303/cp210x/ftdi`、`kmod-usb-net-asix(-ax88179)/aqc111/smsc95xx`。
- 以独立 APK 提供（`=m`，装到可写 overlay，不占只读 rootfs）：
  - 文件共享：`ksmbd-server` + `luci-app-ksmbd`、`nfs-kernel-server`。
  - Python 3 运行时（`python3-light` 及 xml/email/urllib/codecs/openssl/pkg-resources 模块），使 HomeBox / netspeedtest 在无外网时也能安装。
  - 额外文件系统：`kmod-fs-btrfs` + `btrfs-progs`、`kmod-fs-xfs` + `xfsprogs`。
- 移除 USB 打印共享：本内核无法选中 `kmod-usb-printer`，`p910nd` 会留下无法满足的依赖。

## v0.8.2-full.2

### 自定义软件包固件（云编译，含独立 APK）

- 与 `v0.8.2-full.1` 相同的固件内容（iperf/iperf3、USB 网络共享、USB 存储、UU 与 OpenClash 依赖、ttyd、文件管理）。
- 大型第三方应用改为 `=m` 选择编译：`luci-app-openclash`、`luci-app-netspeedtest`、`homebox`、`ookla-speedtest` 以独立 APK 随 Release 发布，不进入 32 MiB 只读 rootfs。
- APK 使用固件构建密钥签名，设备 `/etc/apk/keys/` 已包含对应公钥，可直接 `apk add /tmp/<name>.apk`。

## v0.8.2-full.1

### 自定义软件包固件（云编译）

- 在 0.8.2-beta 基础上增加自定义软件包选择，构建通过 GitHub Actions 完成。
- 预装 iperf、iperf3、htop、ethtool、pciutils、jq、curl、wget-ssl、tar（含 gzip）、unzip、bash、ip-full、fdisk、hd-idle。
- 补齐 USB 主机与共享网络协议：usb-net、rndis、cdc-ether/eem/subset/ncm、cdc-mbim、qmi-wwan、ipheth、Huawei CDC-NCM、Sierra、RTL8152，以及 usb-wdm、usb-acm、usb-serial-option/wwan、umbim、uqmi、comgt。
- 补齐 USB 存储驱动与工具：exFAT（内核 + exfat-mkfs/exfat-fsck）、NTFS3（内核 + ntfs-3g 兜底）、ext4、F2FS、VFAT、UAS、block-mount、e2fsprogs、dosfstools、f2fs-tools。
- 增加 UU 加速器运行依赖：TUN、conntrack-netlink、NAT helper、iptables raw/nat 扩展、nft NAT；插件本体不随固件分发。
- 增加 OpenClash 运行依赖：dnsmasq-full（含 nftset/DNSSEC）、ip-full、bash、curl、unzip、ruby、ruby-yaml、luci-compat、luci-lua-runtime、ipset、inet-diag、nft-tproxy/socket。
- `luci-app-openclash` 体积约 22 MiB，超出 32 MiB 只读 rootfs 上限，改为随 Release 附带独立 APK，安装到可写 overlay 数据卷（约 183 MiB）。
- 新增网页终端 ttyd（LuCI 服务 → 终端）与网页文件管理（LuCI 系统 → 文件管理）。
- 802.1Q VLAN 由内核 `CONFIG_VLAN_8021Q=y` 提供，可在 **网络 → 接口 → 设备** 中添加 802.1q 设备。
- HomeBox 内网测速（`luci-app-netspeedtest` + `homebox` + `ookla-speedtest`）随 Release 以独立 APK 提供，避免 Python/Go 体积占用 rootfs。
- 新增自定义构建配置 `configs/tyfza1-full.config`、可选包清单 `port/configs/tyfza1-optional.config` 与第三方包准备脚本。

## v0.8.2-beta

### 无线与硬件加速

- 双频无线采用对称双 PE 路径：上行 PE0 接收、PE1 处理；下行 PE1 选包聚合、PE0 构建发送描述符。
- 更新黑白架构图，标明对称数据路径和缓冲回收分工。
- 限制 PN/SN 快照尝试次数，退出锁保护后重试，修复同步时无限等待。
- 修复 RX DMA 标签未就绪时的中断重启，完善 RDU 和接收批次衔接。
- RXBD 按批次归还，完善无线启停、BA 会话切换及缓冲所有权交接。
- 修复 NI 预取描述符过早复用，保留末两项描述符及其载荷。
- 统一 ARM 与 PE 的 QM 缓冲布局、报文偏移和长度边界，修正 EQ/EPP AXI 属性及队列信用配置。
- 提前归还 NI 接收信用，修复接收环快照时序和 TCP/UDP 硬件校验状态处理。
- 修复跨 TID 重排序、捕获批次衔接及控制帧穿插时的快路径处理。
- 优化批次内目的站点查找和空接收队列调度。
- 补齐 HT/VHT RX LDPC 能力，修正 RTL8852C RFE54 的 LNA 待机配置。
- 修复 Wi-Fi 接口标识和 IPv4/IPv6 硬件流表匹配。
- 完善 160 MHz DFS 子频段过滤、CAC 状态和动态检测参数。
- 调整 NI 中断与无线接收的 CPU 分配，减少额外 RPS 转发。

### 有线、PON 与系统

- 2.5G LAN4 改为异步初始化，修复接口提前打开时的 RTNL 死锁。
- 对齐原厂 S3 PHY 下电位掩码，保留 PCIe/USB 控制位，补齐两种机型的端口隔离与速率切换检查。
- 恢复 L2QM 端口私有缓冲预留，改善共享缓冲拥塞时的收发。
- 修复 VLAN 接口加入网桥后本地 PON 业务匹配失效。
- 将光学及无线校准链接预置到固件，修复只读根文件系统下的校准加载。
- 修复 CPU 调频错误处理、并发访问及同频率重试。
- 修复发射功率 0 dBm 设置、设置失败上报及未知功率显示。
- 固定平台定制软件包版本，避免升级覆盖 LuCI、无线和功率适配。
- 补充 APK 架构兼容说明。

### 构建与测试

- 构建时从当前源码生成 PE 固件，同步内核、驱动和软件包版本。
- 增加原厂寄存器、缓冲归还、双 PE 交接和报文完整性检查。
- 完善 TCP/UDP 测试端点及双向 GRO 处理，隔离造流量进程与 NI 接收核。
- 补齐 LAN 异步初始化、QSPI 和百兆链路的 GitHub Actions 检查。
- 完成单流及双向 TCP/UDP 实机测试，更新吞吐、丢包、RDU 和长尾记录。
- 长期稳定性：待测试。

### 存储扩容

- 全千兆版和 2.5G 版增加单系统存储布局，移除原厂系统卷，剩余空间分配给 OpenWrt。
- 原厂配置、应用数据及校准保存为两份压缩副本，保留 MAC、SN 和设备授权信息。
- 支持迁移中断恢复、升级配置恢复及工厂数据备用副本读取。
- 修复首次迁移缺少 UBI 设备节点而进入 failsafe 的问题。
- 修复 GPON/XG-PON/XGS-PON 配置中 EPON 身份表为空时的工厂数据导入。
- 全千兆版实机 Overlay 容量约 188.7 MiB、可用约 183.8 MiB；2.5G 版模拟可用约 191.1 MiB，实机待测试。

## v0.8.1-beta

- 修复 2.5G 版升级时误报 invalid sysupgrade file 的问题。
- 修复 2.5G 版蓝口连接百兆网卡时有链路却无法收发、获取 IP 的问题。
- 增加 OMCC 版本选择，支持默认 0xb0 与兼容模式 0x86。
- 增加独立的 Class 332 增强认证开关，默认保持启用。

## v0.8.0-beta

- 同一镜像兼容全千兆版和 2.5G 口版，两种机型都提供四个 LAN 口。
- 网口统一为 LAN1–LAN4；2.5G 版最左侧蓝口对应 LAN4。
- 修复 RTL8221B 冷启动和 HiSGMII 初始化，包括应答超时后的请求释放。
- 单个网口初始化失败不再拖掉全部网口；灯控、诊断或无线通知器出错也不会撤销有线接口。
- 修正 2.5G 口的计数器、PON 统计和界面端口显示。
- 校正两种机型的 LAN、USB 灯位。
- 恢复 LAN 与双频 Wi-Fi 出厂 MAC。
- 补齐 WPA3/PMF 能力声明与管理帧保护。
- 修正 2.4 GHz HT40、HE40 配置，完善 DFS 停止与重新启用时的状态处理。
- 优化 Wi-Fi 硬件加速，5 GHz UDP 实测吞吐约 1.34 Gbps。
- 改进 PE 批量收发与 HE 聚合，减少无线传输开销。
- 修复无线入桥后的流表衔接和小包长度处理。
- 新增无线发射功率设置。
- 加入 CPU 调频页面，修正温度读取和平台信息显示。
- 重整 ONU 管理界面，集中展示线路、业务、加速和诊断状态。
- 集成 Argon 主题与简体中文。
- 处理升级后的 LuCI、Argon 资源缓存。
- 从原厂配置恢复 PON 模式及设备身份。
- 接入带签名校验的 OpenWrt 官方软件源，预装常用插件所需的内核模块和依赖。
- 调整可写数据卷，新装后可用空间约 34.6 MiB；保留原厂配置及回退所需卷。
- 支持原生 U-Boot 安装、标准 sysupgrade，以及早期 alpha 固件直接升级。
- 更新 Telnet 安装包和安装说明。
- GitHub Actions 支持同版本重新构建，并加入双板型端口、故障隔离和统计映射检查。

## v0.7.0-alpha

### 本版更新

- 同一固件兼容全千兆版和 2.5G 口版，修正网口初始化、协商及两种机型的指示灯。
- 修正 WPA3/PMF、2.4GHz HE40 配置及 LAN、双频 Wi-Fi 出厂 MAC 地址恢复。
- 修复无线入桥后的硬件卸载衔接、数据收发处理和 DFS 生命周期。
- 更新 ONU 管理界面，集成 Argon 主题及简体中文。

### 待验证与待处理

- 两种板型的冷启动、灯态、2.5G 持续双向收发及 WPA3/HE40 仍待实机验证。
- 开启 Wi-Fi 流量硬件加速后，Wi-Fi 最高吞吐只有约 500 Mbps，待进一步修复。

## v0.6.0-alpha

### 实测进展

- **XG-PON 线路 PPPoE 拨号成功，千兆带宽跑满，CPU 占用约 4.5%。** 以上为本次测试环境下的实测结果。

### 本版更新

- 修复 PPPoE/PON 双向硬件转发和小包封装异常，降低转发时的 CPU 开销。
- 修复 VLAN WAN 业务入口及防火墙流表的设备识别，完善 PPPoE 拨号与硬件卸载衔接。
- 网口统一命名为 `lan1`–`lan5`，PON 业务口改为 `pon0`；保留配置升级时自动迁移原有设备引用。
- 修正硬件转发流量统计，完善转发关闭、重新启用后的恢复。

### 已知问题与待验证项

- VLAN WAN 启动修复仍待重启实测。
- 2.5G 网口及 USB 面板指示灯状态异常，仍待排查。

## v0.5.0-alpha

- 新增原生指示灯和灯光开关，接入 PON、网口、USB 与双频 Wi-Fi 状态。
- 接入 USB 2.0/3.0、U 盘自动挂载及常见文件系统，完善 2.5G 网口。
- 修复保留配置升级后的指示灯初始化，完善 PON 认证灯态。
- 修复硬件转发初始化、流表匹配及 Wi-Fi 上行处理异常。

## v0.4.2-alpha

- 修复 PON 上行繁忙时的 VLAN 处理及 PPPoE 重试异常。

## v0.4.1-alpha

- 修复 PON 多业务及 VLAN 处理异常
- 修复 Wi-Fi 自动选信道失败
- 无线默认地区调整为中国

## v0.4.0-alpha

- 新增 5 GHz Wi-Fi 160 MHz 支持，已实测双天线连接；完善信道切换和雷达避让。
- 优化 Wi-Fi 收发和双向硬件加速，修复暂停传输、省电及加密密钥更新时的数据处理问题。
- 加入无线温度监测和自动校准。
- 完善各类 PON 模式的认证、业务配置及切换流程，修复原厂配置读取和不同模式相互影响的问题。
- 改进光纤短时断线及设备异常后的恢复，修复重新连接时业务配置、加密和硬件转发的衔接问题。
- 增加光口故障监测、异常发光保护和断电通知的驱动支持。
- 修正内存启动镜像的大小检查，补充原厂 USB 识别与挂载分析，以及 PON/Wi-Fi 测试工具。

## v0.3.1-alpha

- 光学、射频校准数据改为每次启动从原厂配置卷加载到 `/tmp`，修复读取失败后沿用旧校准文件的问题。
- 补充原厂系统槽、配置卷保留和校准数据自动加载说明。

## v0.3.0-alpha

- 修复启动时射频校准数据未及时加载，导致找不到 Wi-Fi 设备、无线页面出现 404 的问题。
- 优化双频 Wi-Fi 6 与双向硬件加速的数据收发、动态速率和省电调度。
- 完善 PON 的 OMCI 业务配置、VLAN 映射及硬件转发联动。
- 改进 PON、网络转发和 PCIe 的启停与资源管理。
- 重整 PON 管理页面，集中展示线路、认证和业务状态，保留原生 OpenWrt 网络配置入口。
- 改进自定义软件包选择、增量构建同步和 GitHub Actions 发布流程。

PON 各模式的 OLT 互通与 Wi-Fi 兼容性待测试；持续高负载丢包待优化。各项进度与安装方法见 README。
