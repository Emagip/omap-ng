#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build mainline U-Boot (SPL "MLO" + u-boot.img) for the TI OMAP35x EVM (TMDSEVM3530).
#
# Usage: scripts/build-uboot.sh            # uses defaults below
#        UBOOT_VER=v2026.10 BUILD_DIR=~/omap-build scripts/build-uboot.sh
#
# The source tree and build output live in $BUILD_DIR (ext4), NOT in this repo.
# Repo inputs (optional):
#   patches/u-boot/*.patch      applied in order with 'git am'
#   board/u-boot.config         Kconfig fragment merged over omap3_evm_defconfig
# Output: $BUILD_DIR/out/sd-boot/{MLO,u-boot.img}

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UBOOT_VER="${UBOOT_VER:-v2026.10}"
UBOOT_GIT="${UBOOT_GIT:-https://github.com/u-boot/u-boot.git}"
BUILD_DIR="${BUILD_DIR:-$HOME/omap-build}"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
DEFCONFIG="${DEFCONFIG:-omap3_evm_defconfig}"
JOBS="${JOBS:-$(nproc)}"

SRC="$BUILD_DIR/u-boot"
OBJ="$BUILD_DIR/build/u-boot"
OUT="$BUILD_DIR/out/sd-boot"
LOG="$BUILD_DIR/logs/u-boot-build-$(date +%F-%H%M).log"

mkdir -p "$BUILD_DIR/logs" "$OUT"
exec > >(tee "$LOG") 2>&1
echo "== U-Boot $UBOOT_VER  ($DEFCONFIG)  -> $OUT"

# 1. Fetch a pristine tree for the requested tag
if [ ! -d "$SRC/.git" ]; then
	git clone --depth 1 --branch "$UBOOT_VER" "$UBOOT_GIT" "$SRC"
else
	if [ "$(git -C "$SRC" describe --tags --exact-match 2>/dev/null)" != "$UBOOT_VER" ] \
	   || [ -n "$(git -C "$SRC" status --porcelain)" ] \
	   || [ "$(git -C "$SRC" rev-parse HEAD)" != "$(git -C "$SRC" rev-parse "$UBOOT_VER^{commit}" 2>/dev/null)" ]; then
		git -C "$SRC" fetch --depth 1 origin tag "$UBOOT_VER"
		git -C "$SRC" am --abort 2>/dev/null || true
		git -C "$SRC" checkout -f "$UBOOT_VER"
		git -C "$SRC" clean -fdx -q
	fi
fi

# 2. Apply local patches (if any)
shopt -s nullglob
patches=("$REPO_DIR"/patches/u-boot/*.patch)
if [ ${#patches[@]} -gt 0 ]; then
	echo "== applying ${#patches[@]} patch(es)"
	git -C "$SRC" -c user.name=build -c user.email=build@localhost am -3 "${patches[@]}"
fi

# 3. Configure (out-of-tree) + optional fragment
make -C "$SRC" O="$OBJ" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" "$DEFCONFIG"
if [ -f "$REPO_DIR/board/u-boot.config" ]; then
	echo "== merging board/u-boot.config"
	"$SRC/scripts/kconfig/merge_config.sh" -m -O "$OBJ" "$OBJ/.config" "$REPO_DIR/board/u-boot.config"
	make -C "$SRC" O="$OBJ" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
fi

# 4. Build
make -C "$SRC" O="$OBJ" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS"

# 5. Collect
install -m 0644 "$OBJ/MLO" "$OBJ/u-boot.img" "$OUT/"
ls -l "$OUT"
echo "== done. Log: $LOG"
