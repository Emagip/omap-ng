#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Prepare an SD card for the OMAP35x EVM (boots via SW4 = ON ON ON ON OFF OFF OFF OFF).
#
#   sudo scripts/mksd.sh format /dev/sdX   # WIPES the card: p1 FAT32 "BOOT" + p2 ext4 "rootfs"
#   sudo scripts/mksd.sh update /dev/sdX   # only (re)copies boot files to the existing p1
#
# Boot files are taken from $BOOT_FILES (default: ~<user>/omap-build/out/sd-boot):
#   MLO, u-boot.img        (required)
#   anything else in there (zImage, *.dtb, boot.scr, uEnv.txt...) is copied too.
#
# Layout (for the OMAP3 boot ROM, which wants a 255-head/63-sector partition table):
#   p1: cylinders 0-8 = LBA 63..144584 (~70 MB), type 0x0C (FAT32 LBA), bootable,
#       FAT32 with 255/63 geometry and 63 hidden sectors in the boot sector
#   p2: from cylinder 9 to the end, ext4 (root filesystem, filled later)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

MODE="${1:-}"; DEV="${2:-}"
[ "$MODE" = format ] || [ "$MODE" = update ] || die "usage: $0 {format|update} /dev/sdX"
[ -b "$DEV" ] || die "$DEV is not a block device"
[ "$(id -u)" -eq 0 ] || die "run with sudo"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
BOOT_FILES="${BOOT_FILES:-$REAL_HOME/omap-build/out/sd-boot}"

# ---- safety checks: whole disk, removable/USB/MMC, not holding the system ----
NAME="$(basename "$DEV")"
[ "$(lsblk -dno TYPE "$DEV")" = disk ] || die "$DEV is not a whole disk (give /dev/sdX, not a partition)"
TRAN="$(lsblk -dno TRAN "$DEV" 2>/dev/null || true)"
RM="$(cat "/sys/block/$NAME/removable" 2>/dev/null || echo 0)"
case "$NAME" in mmcblk*) TRAN=mmc ;; esac
if [ "$RM" != 1 ] && [ "$TRAN" != usb ] && [ "$TRAN" != mmc ]; then
	die "$DEV is neither removable nor USB/MMC (TRAN='$TRAN') - refusing"
fi
for mp in / /boot /boot/efi /home /run/media/"$REAL_USER"/DaFunnyDrive; do
	src="$(findmnt -no SOURCE "$mp" 2>/dev/null || true)"
	[ -n "$src" ] && [ "$(lsblk -no PKNAME "$src" 2>/dev/null)" = "$NAME" ] && die "$DEV holds $mp - refusing"
done
SIZE_GB=$(( $(blockdev --getsize64 "$DEV") / 1000000000 ))
[ "$SIZE_GB" -le 128 ] || die "$DEV is ${SIZE_GB} GB - larger than any SD card we expect, refusing"

echo "Target: $DEV  ($(lsblk -dno MODEL,SIZE,TRAN "$DEV" | xargs))"
lsblk "$DEV"

part() { case "$NAME" in mmcblk*|loop*|nvme*) echo "${DEV}p$1" ;; *) echo "${DEV}$1" ;; esac; }
P1="$(part 1)"; P2="$(part 2)"

[ -f "$BOOT_FILES/MLO" ] && [ -f "$BOOT_FILES/u-boot.img" ] || die "MLO/u-boot.img missing in $BOOT_FILES (run scripts/build-uboot.sh)"

# unmount anything on the card
for p in $(lsblk -lnpo NAME "$DEV" | tail -n +2); do umount "$p" 2>/dev/null || true; done

if [ "$MODE" = format ]; then
	read -r -p "ALL DATA on $DEV will be destroyed. Type the device name ($NAME) to continue: " ans
	[ "$ans" = "$NAME" ] || die "aborted"
	wipefs -a "$DEV"
	dd if=/dev/zero of="$DEV" bs=1M count=8 conv=fsync status=none
	# Write the MBR ourselves with an explicit 255-head / 63-sector geometry, as the
	# OMAP3 boot ROM expects (TI wiki "MMC Boot Format"). Modern sfdisk derives the
	# CHS fields from whatever geometry the card reader reports, which breaks ROM boot.
	#   p1: cylinders 0..8  -> LBA 63..144584   (FAT32, bootable, ~70 MB)
	#   p2: cylinder 9..end -> LBA 144585..end  (Linux)
	python3 -I - "$DEV" "$(blockdev --getsz "$DEV")" <<'PY'
import sys, os
dev, total = sys.argv[1], int(sys.argv[2])
H, S = 255, 63
CYL = H * S                                  # 16065 sectors per cylinder
def chs(lba):
    c, r = divmod(lba, CYL); h, s = divmod(r, S); s += 1
    if c > 1023: c, h, s = 1023, 254, 63
    return bytes([h, ((c >> 2) & 0xC0) | s, c & 0xFF])
def entry(boot, ptype, start, size):
    return (bytes([0x80 if boot else 0]) + chs(start) + bytes([ptype]) +
            chs(start + size - 1) + start.to_bytes(4, 'little') + size.to_bytes(4, 'little'))
p1_start, p1_end = 63, 9 * CYL - 1
p2_start = 9 * CYL
p2_size = (total - p2_start) // CYL * CYL    # whole cylinders
mbr = bytearray(512)
mbr[440:444] = os.urandom(4)                 # disk signature
mbr[446:462] = entry(True, 0x0C, p1_start, p1_end - p1_start + 1)
mbr[462:478] = entry(False, 0x83, p2_start, p2_size)
mbr[510:512] = b'\x55\xaa'
with open(dev, 'r+b') as f:
    f.write(mbr); f.flush(); os.fsync(f.fileno())
print("MBR written: p1 LBA %d-%d (FAT32, boot), p2 LBA %d+%d" % (p1_start, p1_end, p2_start, p2_size))
PY
	blockdev --rereadpt "$DEV" || partprobe "$DEV" || true; udevadm settle
	fdisk -l "$DEV"
	# -s 1: 1 sector/cluster -> ~142k clusters. With the default (64) the volume has
	# only ~2k clusters, which by the FAT spec is NOT FAT32 and the ROM rejects it.
	mkfs.vfat -F 32 -s 1 -n BOOT -g 255/63 -h 63 "$P1"
	mkfs.ext4 -F -q -L rootfs "$P2"
fi

MNT="$(mktemp -d)"
trap 'umount "$MNT" 2>/dev/null || true; rmdir "$MNT"' EXIT
mount "$P1" "$MNT"
# MLO first: some OMAP3 ROMs only look at the first directory entries
cp "$BOOT_FILES/MLO" "$MNT/MLO"; sync
cp "$BOOT_FILES/u-boot.img" "$MNT/u-boot.img"
for f in "$BOOT_FILES"/*; do
	b="$(basename "$f")"; [ "$b" = MLO ] || [ "$b" = u-boot.img ] && continue
	cp -r "$f" "$MNT/"
done
sync
ls -l "$MNT"
echo "Done. Insert the card in the EVM (SW4 = ON ON ON ON OFF OFF OFF OFF) and power-cycle."
