# SPDX-License-Identifier: GPL-2.0-only
# U-Boot boot script for the TMDSEVM3530 Rev D (128 MB RAM, SD boot).
# Compiled to boot.scr by scripts/build-kernel.sh; found by U-Boot's distro boot
# on the bootable FAT partition (mmc 0:1).
#
# Load addresses are chosen inside 128 MB: TI's default fdtaddr (0x88000000)
# assumes 256 MB boards and is outside this board's RAM.

echo "== boot.scr: TMDSEVM3530 Rev D"
setenv kaddr 0x82000000
setenv faddr 0x83000000
setenv bootargs console=ttyS0,115200n8 root=/dev/mmcblk0p2 rootfstype=ext4 rw rootwait ${optargs}

fatload mmc 0:1 ${kaddr} zImage
fatload mmc 0:1 ${faddr} omap3-evm-revd.dtb
bootz ${kaddr} - ${faddr}
