#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Vendor third-party OpenWrt packages that are not part of the pinned official
# feeds. They are fetched from a pinned tag and verified by SHA-256, then copied
# into the OpenWrt tree so `make package/<name>/compile` can build them.
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

OC_TAG=$(field openclash tag)
OC_SHA=$(field openclash sha256)
OC_URL=$(field openclash url)
TARBALL="$DL/openclash-$OC_TAG.tar.gz"
TARGET="$TREE/package/luci-app-openclash"

mkdir -p "$DL"
if [ ! -s "$TARBALL" ] || ! echo "$OC_SHA  $TARBALL" | sha256sum -c - >/dev/null 2>&1; then
	echo "Downloading luci-app-openclash $OC_TAG"
	curl --fail --location --retry 3 --connect-timeout 20 --max-time 600 \
		--output "$TARBALL" "$OC_URL"
fi
echo "$OC_SHA  $TARBALL" | sha256sum -c -

if [ -s "$TARGET/Makefile" ] && [ -d "$TARGET/root" ]; then
	echo "luci-app-openclash $OC_TAG already vendored"
	exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tar -xzf "$TARBALL" -C "$WORK"
SOURCE=$(find "$WORK" -mindepth 2 -maxdepth 2 -type d -name luci-app-openclash | head -n 1)
[ -n "$SOURCE" ] || {
	echo "luci-app-openclash directory missing from $TARBALL" >&2
	exit 1
}
mkdir -p "$TREE/package"
rm -rf "$TARGET"
cp -a "$SOURCE" "$TARGET"
echo "Vendored luci-app-openclash $OC_TAG into $TARGET"
