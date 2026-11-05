#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

tyfza1_find_volume() {
	local path
	for path in /sys/class/ubi/"$1"_*/name; do
		[ -f "$path" ] || continue
		[ "$(cat "$path")" = "$2" ] || continue
		path=${path%/name}
		echo "${path##*/}"
		return 0
	done
	return 1
}

# Only the selected OpenWrt root and rootfs_data participate in allocation.
# Keep every OEM volume, including the other boot slot, at its original size.
#
# Slot limits:
#   - The OEM layout gives the root volume 33,648,640 bytes. Images larger than
#     that need the migrated layout, which grows the root volume in place.
#   - TYFZA1_MAX_ROOT_BYTES is the migrated cap (128 MiB). It matches the value
#     shipped by the released migration firmware and is kept in sync with the
#     build-time cap in target/linux/rtl9617c/image/Makefile.
#   - Independently of the cap, the writable rootfs_data volume must still get
#     at least TYFZA1_MIN_DATA_BYTES out of the remaining UBI space.
TYFZA1_MAX_ROOT_BYTES=134217728
TYFZA1_MIN_DATA_BYTES=16777216

tyfza1_plan_storage() {
	local ubidev="$1" rootvol="$2" size="$3"
	local path="/sys/class/ubi/$rootvol" data free root_ebs data_ebs=0
	local leb=$(cat "$path/usable_eb_size")
	case "$(cat "$path/name"):$rootvol" in
		ubi_r0:${ubidev}_4|ubi_r1:${ubidev}_7) ;;
		*) echo "Unexpected TYFZA1 root volume: $rootvol" >&2; return 1 ;;
	esac
	[ "$size" -gt 0 ] && [ "$size" -le "$TYFZA1_MAX_ROOT_BYTES" ] || {
		echo "Root image must fit the $TYFZA1_MAX_ROOT_BYTES-byte migrated slot limit" >&2
		return 1
	}
	free=$(cat "/sys/class/ubi/$ubidev/avail_eraseblocks")
	root_ebs=$(cat "$path/reserved_ebs")
	data=$(tyfza1_find_volume "$ubidev" rootfs_data) || data=
	if [ -n "$data" ]; then
		[ "$data" = "${ubidev}_11" ] || return 1
		data_ebs=$(cat "/sys/class/ubi/$data/reserved_ebs")
	else
		# Never overwrite a differently named volume occupying ID 11.
		[ ! -e "/sys/class/ubi/${ubidev}_11" ] || return 1
	fi
	TYFZA1_ROOT_BYTES=$(( (size + leb - 1) / leb * leb ))
	TYFZA1_DATA_BYTES=$(( (free + root_ebs + data_ebs) * leb - TYFZA1_ROOT_BYTES ))
	[ "$TYFZA1_DATA_BYTES" -ge "$TYFZA1_MIN_DATA_BYTES" ] || {
		echo "Insufficient UBI space: root image is $size bytes, only" \
			"$TYFZA1_DATA_BYTES bytes would remain for writable data" \
			"(minimum $TYFZA1_MIN_DATA_BYTES)" >&2
		return 1
	}
}

tyfza1_resize_root() {
	local ubidev="$1" rootvol="$2"
	ubirsvol "/dev/$ubidev" -N "$(cat "/sys/class/ubi/$rootvol/name")" \
		-s "$TYFZA1_ROOT_BYTES"
}

tyfza1_grow_data() {
	local ubidev="$1" data current
	data=$(tyfza1_find_volume "$ubidev" rootfs_data) || data=
	if [ -n "$data" ]; then
		current=$(( $(cat "/sys/class/ubi/$data/reserved_ebs") * $(cat "/sys/class/ubi/$data/usable_eb_size") ))
		[ "$current" -le "$TYFZA1_DATA_BYTES" ] || {
			echo "Existing writable data cannot be shrunk; upgrade from OpenWrt" >&2
			return 1
		}
		[ "$current" -eq "$TYFZA1_DATA_BYTES" ] || \
			ubirsvol "/dev/$ubidev" -N rootfs_data -s "$TYFZA1_DATA_BYTES"
	else
		ubimkvol "/dev/$ubidev" -n 11 -N rootfs_data -m
	fi
}
