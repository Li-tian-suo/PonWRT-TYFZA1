#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Vendor third-party OpenWrt packages that are not part of the pinned official
# feeds. Every archive is pinned by tag/commit and verified by SHA-256 before it
# is unpacked into the OpenWrt tree.
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
umask 022
PORT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT=$(CDPATH= cd -- "$PORT/.." && pwd)
TREE=${1:?Usage: prepare-extra-packages.sh /path/to/openwrt-checkout}
TREE=$(realpath "$TREE")
LOCK="$PORT/sources.lock.json"
DL="$TREE/dl"

field() {
	python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]][sys.argv[3]])' \
		"$LOCK" "$1" "$2"
}

fetch_verified() {
	url=$1
	sha=$2
	file=$3
	if [ ! -s "$file" ] || ! echo "$sha  $file" | sha256sum -c - >/dev/null 2>&1; then
		echo "Downloading $(basename "$file")"
		curl --fail --location --retry 3 --connect-timeout 20 --max-time 900 \
			--output "$file" "$url"
	fi
	echo "$sha  $file" | sha256sum -c -
}

# Nested lookup: field2 <section> <name> <key>
field2() {
	python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]][sys.argv[3]][sys.argv[4]])' \
		"$LOCK" "$1" "$2" "$3"
}

mkdir -p "$DL"

# --- OpenClash (luci-app-openclash) --------------------------------------
OC_TAG=$(field openclash tag)
OC_SHA=$(field openclash sha256)
OC_URL=$(field openclash url)
OC_TARBALL="$DL/openclash-$OC_TAG.tar.gz"
fetch_verified "$OC_URL" "$OC_SHA" "$OC_TARBALL"
if [ -s "$TREE/package/luci-app-openclash/Makefile" ] && [ -d "$TREE/package/luci-app-openclash/root" ]; then
	echo "luci-app-openclash $OC_TAG already vendored"
else
	WORK=$(mktemp -d)
	tar -xzf "$OC_TARBALL" -C "$WORK"
	SOURCE=$(find "$WORK" -mindepth 2 -maxdepth 2 -type d -name luci-app-openclash | head -n 1)
	[ -n "$SOURCE" ] || { echo "luci-app-openclash missing from $OC_TARBALL" >&2; exit 1; }
	mkdir -p "$TREE/package"
	rm -rf "$TREE/package/luci-app-openclash"
	cp -a "$SOURCE" "$TREE/package/luci-app-openclash"
	rm -rf "$WORK"
	echo "Vendored luci-app-openclash $OC_TAG"
fi

# --- netspeedtest (luci-app-netspeedtest + homebox + ookla-speedtest) ----
NS_COMMIT=$(field netspeedtest commit)
NS_SHA=$(field netspeedtest sha256)
NS_URL=$(field netspeedtest url)
NS_TARBALL="$DL/netspeedtest-$NS_COMMIT.tar.gz"
fetch_verified "$NS_URL" "$NS_SHA" "$NS_TARBALL"
if [ -s "$TREE/package/luci-app-netspeedtest/Makefile" ] &&
	[ -s "$TREE/package/homebox/Makefile" ] &&
	[ -s "$TREE/package/ookla-speedtest/Makefile" ]; then
	echo "netspeedtest $NS_COMMIT already vendored"
else
	WORK=$(mktemp -d)
	tar -xzf "$NS_TARBALL" -C "$WORK"
	SOURCE=$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -n 1)
	[ -n "$SOURCE" ] || { echo "netspeedtest tree missing from $NS_TARBALL" >&2; exit 1; }
	mkdir -p "$TREE/package"
	for pkg in luci-app-netspeedtest homebox ookla-speedtest; do
		[ -d "$SOURCE/$pkg" ] || { echo "$pkg missing from $NS_TARBALL" >&2; exit 1; }
		rm -rf "$TREE/package/$pkg"
		cp -a "$SOURCE/$pkg" "$TREE/package/$pkg"
	done
	rm -rf "$WORK"
	echo "Vendored netspeedtest $NS_COMMIT"
fi

# --- Small LuCI applications (toolbox, scheduled reboot, power off) ------
for APP in luci-app-systools luci-app-timedreboot luci-app-poweroffdevice; do
	APP_URL=$(field2 small_apps "$APP" url)
	APP_SHA=$(field2 small_apps "$APP" sha256)
	APP_DIR=$(field2 small_apps "$APP" dir)
	APP_TARBALL="$DL/$APP.tar.gz"
	fetch_verified "$APP_URL" "$APP_SHA" "$APP_TARBALL"
	if [ -s "$TREE/package/$APP/Makefile" ]; then
		echo "$APP already vendored"
		continue
	fi
	WORK=$(mktemp -d)
	tar -xzf "$APP_TARBALL" -C "$WORK"
	TOP=$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -n 1)
	[ -n "$TOP" ] || { rm -rf "$WORK"; echo "empty archive for $APP" >&2; exit 1; }
	if [ -n "$APP_DIR" ]; then
		SRC="$TOP/$APP_DIR"
	else
		SRC="$TOP"
	fi
	[ -s "$SRC/Makefile" ] || { rm -rf "$WORK"; echo "$APP Makefile missing" >&2; exit 1; }
	mkdir -p "$TREE/package"
	rm -rf "$TREE/package/$APP"
	cp -a "$SRC" "$TREE/package/$APP"
	rm -rf "$WORK"
	echo "Vendored $APP"
done
