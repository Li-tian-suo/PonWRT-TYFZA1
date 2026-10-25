#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
export TYFZA1_CARGO=${TYFZA1_CARGO:-$(command -v cargo)}
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
if [ -n "${TYFZA1_PROXY:-}" ]; then
    export http_proxy=$TYFZA1_PROXY https_proxy=$TYFZA1_PROXY
fi
export CURL_OPTIONS='--speed-time 60 --speed-limit 1024'
umask 022
PORT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT=$(CDPATH= cd -- "$PORT/.." && pwd)
export TYFZA1_PROJECT=$PROJECT
TREE=${1:?Usage: build.sh /path/to/openwrt-checkout [jobs]}
TREE=$(realpath "$TREE")
JOBS=${2:-2}
if [ -z "${TYFZA1_RUNTIME_INPUTS:-}" ]; then
    python3 "$PROJECT/tools/prepare_pon_runtime.py" "$TREE/files" \
        --stock "${TYFZA1_STOCK_INPUTS:-$PROJECT/analysis/private/live-files}" \
        --check-inputs-only
fi
PE_RADIO_CFLAGS=-DPE_UPLINK sh "$PROJECT/scripts/build_pe_radio_wd.sh" "$PROJECT/artifacts/pe-radio-production"
cp "$PROJECT/artifacts/pe-radio-production/pe-tx-code.h" \
    "$PORT/overlay/target/linux/rtl9617c/files-6.18/drivers/net/wireless/realtek/rtl_ax_ap/pe-tx-code.h"
sh "$PORT/scripts/sync-overlay.sh" "$TREE"
# Third-party packages (OpenClash) are not in the pinned official feeds.
# A download failure must not abort the firmware build.
if ! sh "$PORT/scripts/prepare-extra-packages.sh" "$TREE"; then
	echo "WARNING: third-party packages unavailable; firmware builds without them" >&2
fi
sh "$PROJECT/scripts/prepare_luci_feeds.sh" "$TREE"
cd "$TREE"
REGDB_PATCHED=0
if ! grep -Fq 'regulatory.db.p7s' package/firmware/wireless-regdb/Makefile; then
    patch -p1 --fuzz=0 < "$PORT/host-patches/110-wireless-regdb-signed.patch"
    REGDB_PATCHED=1
fi
make defconfig
# Report every selection that Kconfig dropped, not just the first one, so a
# missing dependency can be diagnosed from a single build log.
missing=
for package in luci-app-tyfza1-pon luci-theme-argon luci-i18n-argon-config-zh-cn; do
    grep -qx "CONFIG_PACKAGE_$package=y" .config || missing="$missing CONFIG_PACKAGE_$package"
done
while IFS= read -r setting; do
    case "$setting" in
        CONFIG_PACKAGE_*=y)
            grep -qxF "$setting" .config || missing="$missing $setting"
            ;;
    esac
done < "$PORT/configs/tyfza1-compat.config"
if [ -n "$missing" ]; then
    echo "Required packages missing after defconfig:" >&2
    for setting in $missing; do
        echo "  $setting" >&2
    done
    echo "A package disappears when its Kconfig dependencies cannot be met on" >&2
    echo "this target (missing feed package, kernel subsystem, or arch/BROKEN)." >&2
    exit 1
fi
# Optional add-ons are reported, not fatal.
for setting in $(grep -E '^CONFIG_PACKAGE_[A-Za-z0-9_.+-]+=[ym]$' "$PORT/configs/tyfza1-optional.config"); do
    grep -qxF "$setting" .config || echo "WARNING: optional package dropped after defconfig: $setting" >&2
done
if [ "$REGDB_PATCHED" = 1 ]; then
    make package/firmware/wireless-regdb/clean
fi
# On this WSL host, TCP fakeroot fails at the first file operation. Use the
# existing upstream SysV backend, not root builds or altered package ownership.
if grep -qi microsoft /proc/sys/kernel/osrelease; then
    if grep -q -- '--with-ipc=tcp' tools/fakeroot/Makefile; then
        patch -p1 < "$PORT/host-patches/100-fakeroot-sysv.patch"
        make tools/fakeroot/clean
    fi
fi
make -j"$JOBS" download
if [ -n "${TYFZA1_RUNTIME_INPUTS:-}" ]; then
    python3 "$PROJECT/tools/install_runtime_inputs.py" "$TYFZA1_RUNTIME_INPUTS" "$TREE/files"
else
    python3 "$PROJECT/tools/prepare_pon_runtime.py" "$TREE/files" \
        --stock "${TYFZA1_STOCK_INPUTS:-$PROJECT/analysis/private/live-files}"
    python3 "$PROJECT/tools/prepare_wifi_runtime.py" "$TREE/files" --openwrt-tree "$TREE"
fi
df -h "$TREE" "$TREE/.." 2>/dev/null || true
if ! make -j"$JOBS" world; then
	# Parallel output can hide which step failed; replay the rootfs install
	# phase serially with full command tracing so the log names the culprit.
	echo "world failed; replaying package/install with V=s" >&2
	df -h "$TREE" 2>/dev/null || true
	make -j1 V=s package/install 2>&1 | tail -n 200 >&2 || true
	exit 1
fi
# Packages that are too large for the 32 MiB rootfs are built as standalone
# APKs instead of being installed into the image. Failures stay non-fatal so
# the firmware itself is still produced and packaged.
for pkg in ${TYFZA1_EXTRA_PACKAGES-luci-app-openclash luci-app-netspeedtest homebox ookla-speedtest}; do
	if [ ! -f "package/$pkg/Makefile" ]; then
		echo "WARNING: extra package $pkg is not present in the tree" >&2
		continue
	fi
	if ! make -j"$JOBS" "package/$pkg/compile"; then
		echo "WARNING: extra package $pkg failed to build" >&2
	fi
done
