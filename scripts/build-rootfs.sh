#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the Buildroot root filesystem (+ optionally the SDK) for the OMAP35x EVM Rev D.
#
# Usage: scripts/build-rootfs.sh          # rootfs only
#        scripts/build-rootfs.sh sdk      # rootfs + relocatable SDK tarball
#        BR_VER=2026.02.3 BUILD_DIR=~/omap-build scripts/build-rootfs.sh
#
# Needs the kernel modules from scripts/build-kernel.sh ($BUILD_DIR/out/modules).
# Output: $BUILD_DIR/out/rootfs/{rootfs.ext4,rootfs.tar}  (+ SDK tarball with 'sdk')

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BR_VER="${BR_VER:-2026.02.3}"
BR_GIT="${BR_GIT:-https://gitlab.com/buildroot.org/buildroot.git}"
BUILD_DIR="${BUILD_DIR:-$HOME/omap-build}"
DEFCONFIG="${DEFCONFIG:-omap3evm_revd_defconfig}"

SRC="$BUILD_DIR/buildroot"
OBJ="$BUILD_DIR/build/buildroot"
EXT="$BUILD_DIR/build/br-external"     # permission-sane copy of board/buildroot
OUT="$BUILD_DIR/out/rootfs"
LOG="$BUILD_DIR/logs/rootfs-build-$(date +%F-%H%M).log"
export BR2_DL_DIR="${BR2_DL_DIR:-$BUILD_DIR/dl}"
export OMAPNG_MODULES="${OMAPNG_MODULES:-$BUILD_DIR/out/modules}"

mkdir -p "$BUILD_DIR/logs" "$OUT" "$OBJ" "$BR2_DL_DIR"
exec > >(tee "$LOG") 2>&1
echo "== Buildroot $BR_VER ($DEFCONFIG) -> $OUT"

[ -d "$OMAPNG_MODULES/lib/modules" ] || { echo "ERROR: no kernel modules in $OMAPNG_MODULES (run scripts/build-kernel.sh)"; exit 1; }

# 1. Buildroot tree at the requested tag
if [ ! -d "$SRC/.git" ]; then
	git clone --depth 1 --branch "$BR_VER" "$BR_GIT" "$SRC"
elif [ "$(git -C "$SRC" rev-parse HEAD)" != "$(git -C "$SRC" rev-parse "$BR_VER^{commit}" 2>/dev/null)" ]; then
	git -C "$SRC" fetch --depth 1 origin tag "$BR_VER"
	git -C "$SRC" checkout -q -f "$BR_VER"
fi

# 2. External tree: copy with normal Unix permissions (the repo may live on NTFS,
#    where every file shows up as 0777 and would end up like that in the rootfs)
rsync -a --delete --no-perms --chmod=D755,F644 "$REPO_DIR/board/buildroot/" "$EXT/"
find "$EXT" -name '*.sh' -exec chmod 755 {} +

# 3. Configure + build
make -C "$SRC" O="$OBJ" BR2_EXTERNAL="$EXT" "$DEFCONFIG"
# report defconfig lines that did not survive (missing dependencies / typos)
while IFS= read -r line; do
	case "$line" in *'$('*) ;; BR2_*=*) grep -qxF "$line" "$OBJ/.config" || echo "WARNING: not applied: $line" ;; esac
done < "$EXT/configs/$DEFCONFIG"
make -C "$SRC" O="$OBJ"
if [ "${1:-}" = sdk ]; then
	make -C "$SRC" O="$OBJ" sdk
fi

# 4. Collect
install -m 0644 "$OBJ/images/rootfs.ext4" "$OBJ/images/rootfs.tar" "$OUT/"
[ "${1:-}" = sdk ] && install -m 0644 "$OBJ"/images/*_sdk-buildroot.tar.gz "$OUT/"
ls -l "$OUT"
echo "== done. Log: $LOG"
