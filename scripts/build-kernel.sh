#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the mainline (LTS) Linux kernel for the TI OMAP35x EVM Rev D.
#
# Usage: scripts/build-kernel.sh
#        LINUX_VER=v6.18.65 BUILD_DIR=~/omap-build scripts/build-kernel.sh
#
# The source tree and build output live in $BUILD_DIR (ext4), NOT in this repo.
# Repo inputs:
#   board/dts/*.dts         board device trees, copied into arch/arm/boot/dts/ti/omap/
#   board/kernel.config     Kconfig fragment merged over omap2plus_defconfig
#   board/boot.cmd          U-Boot boot script -> boot.scr
#   patches/linux/*.patch   applied in order with 'git am' (optional)
# Output:
#   $BUILD_DIR/out/sd-boot/{zImage,omap3-evm-revd.dtb,boot.scr}   (FAT partition)
#   $BUILD_DIR/out/modules/lib/modules/<ver>/...                  (for the rootfs)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_VER="${LINUX_VER:-v6.18.65}"
LINUX_GIT="${LINUX_GIT:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
BUILD_DIR="${BUILD_DIR:-$HOME/omap-build}"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
DEFCONFIG="${DEFCONFIG:-omap2plus_defconfig}"
JOBS="${JOBS:-$(nproc)}"
DTS_DIR=arch/arm/boot/dts/ti/omap

SRC="$BUILD_DIR/linux"
OBJ="$BUILD_DIR/build/linux"
OUT="$BUILD_DIR/out/sd-boot"
MODS="$BUILD_DIR/out/modules"
LOG="$BUILD_DIR/logs/kernel-build-$(date +%F-%H%M).log"
K=(make -C "$SRC" O="$OBJ" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE")

mkdir -p "$BUILD_DIR/logs" "$OUT" "$OBJ"
exec > >(tee "$LOG") 2>&1
echo "== Linux $LINUX_VER ($DEFCONFIG) -> $OUT"

# 1. Pristine tree at the requested tag
if [ ! -d "$SRC/.git" ]; then
	git clone --depth 1 --branch "$LINUX_VER" "$LINUX_GIT" "$SRC"
else
	git -C "$SRC" am --abort 2>/dev/null || true
	if [ "$(git -C "$SRC" rev-parse HEAD)" != "$(git -C "$SRC" rev-parse "$LINUX_VER^{commit}" 2>/dev/null)" ]; then
		git -C "$SRC" fetch --depth 1 origin tag "$LINUX_VER"
	fi
	git -C "$SRC" checkout -q -f "$LINUX_VER"
	git -C "$SRC" clean -fdxq
fi

# 2. Local patches
shopt -s nullglob
patches=("$REPO_DIR"/patches/linux/*.patch)
if [ ${#patches[@]} -gt 0 ]; then
	echo "== applying ${#patches[@]} patch(es)"
	git -C "$SRC" -c user.name=build -c user.email=build@localhost am -3 "${patches[@]}"
fi

# 3. Board device trees into the tree + Makefile entries
dtbs=()
for dts in "$REPO_DIR"/board/dts/*.dts; do
	b="$(basename "$dts" .dts)"
	cp "$dts" "$SRC/$DTS_DIR/"
	grep -q "^dtb-\$(CONFIG_SOC_OMAP3430) += $b.dtb\$" "$SRC/$DTS_DIR/Makefile" ||
		echo "dtb-\$(CONFIG_SOC_OMAP3430) += $b.dtb" >> "$SRC/$DTS_DIR/Makefile"
	dtbs+=("ti/omap/$b.dtb")
done
# commit them in the build tree so the kernel version is not reported as "-dirty"
git -C "$SRC" add "$DTS_DIR"
git -C "$SRC" -c user.name=build -c user.email=build@localhost \
	commit -q -m "ARM: dts: omap3-evm: add board device trees from omap-ng (board/dts)"

# 4. Configure: defconfig + fragment
"${K[@]}" "$DEFCONFIG"
if [ -f "$REPO_DIR/board/kernel.config" ]; then
	echo "== merging board/kernel.config"
	"$SRC/scripts/kconfig/merge_config.sh" -m -O "$OBJ" "$OBJ/.config" "$REPO_DIR/board/kernel.config"
	"${K[@]}" olddefconfig
	# report fragment options that did not survive (missing deps / typos)
	while IFS= read -r line; do
		case "$line" in CONFIG_*=*) grep -qx "$line" "$OBJ/.config" || echo "WARNING: not applied: $line" ;; esac
	done < "$REPO_DIR/board/kernel.config"
fi

# 5. Build
"${K[@]}" -j"$JOBS" zImage modules "${dtbs[@]}"

# 6. Collect
install -m 0644 "$OBJ/arch/arm/boot/zImage" "$OUT/"
for d in "${dtbs[@]}"; do install -m 0644 "$OBJ/arch/arm/boot/dts/$d" "$OUT/"; done
mkimage -A arm -O linux -T script -C none -n "TMDSEVM3530 Rev D boot" \
	-d "$REPO_DIR/board/boot.cmd" "$OUT/boot.scr"
rm -rf "$MODS"
"${K[@]}" INSTALL_MOD_PATH="$MODS" INSTALL_MOD_STRIP=1 modules_install
echo "== kernel $(cat "$OBJ/include/config/kernel.release")"
ls -l "$OUT"
echo "== done. Log: $LOG"
