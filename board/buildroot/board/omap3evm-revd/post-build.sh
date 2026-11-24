#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Buildroot post-build: install the kernel modules built by scripts/build-kernel.sh
# ($OMAPNG_MODULES = <dir containing lib/modules/<version>>, exported by build-rootfs.sh).
set -e
TARGET_DIR="$1"
if [ -n "${OMAPNG_MODULES:-}" ] && [ -d "$OMAPNG_MODULES/lib/modules" ]; then
	rm -rf "$TARGET_DIR/lib/modules"
	mkdir -p "$TARGET_DIR/lib"
	cp -a "$OMAPNG_MODULES/lib/modules" "$TARGET_DIR/lib/"
	# drop build/source symlinks pointing into the host build tree
	find "$TARGET_DIR/lib/modules" -maxdepth 2 \( -name build -o -name source \) -type l -delete
	echo "post-build: installed kernel modules: $(ls "$TARGET_DIR/lib/modules")"
else
	echo "post-build: WARNING: OMAPNG_MODULES not set or empty - no kernel modules installed" >&2
fi
