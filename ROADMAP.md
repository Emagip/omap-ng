# Roadmap: mainline Linux + Buildroot on the TMDSEVM3530 (Rev D, OneNAND)

Background: `FEASIBILITY.md` (why and what), `doc/EXPANSION-CONNECTORS.md` (pins and SW4), `GPIO-LED-TEST.md` (first GPIO test).

Each step ends with a **checkpoint**. Don't move on until it passes.

| # | Step | Status |
|---|---|---|
| 0 | Host and serial setup | **done**: USB-serial chain works |
| 1 | Baseline: capture what the board boots today | **done** (2026-11-24); see `logs/baseline/FINDINGS.md`. Multimeter checks still to do. |
| 2 | Mainline U-Boot on SD | **done** 2026-11-24: v2026.10 + ES2.1 MMC patch; 128 MiB, `mtest` 0 errors, LAN9115 `ping` OK, env saved to SD. Logs: `logs/u-boot/`. |
| 3 | Mainline kernel + Rev D device tree | **done** 2026-11-24: 6.18.65 boots to the expected "No working init found" panic (empty rootfs). SD (DMA), OneNAND, I2C1-3, TWL4030, UARTs OK. To verify with a rootfs: LAN9115 driver, LED heartbeat, 126 MB RAM / 16 MB CMA. Log: `logs/linux/`. |
| 4 | Buildroot root filesystem + cross SDK | **boots to a login** (2026-11-24, clean boot: no I2C/TWL errors, no thermal shutdown). **Open:** `eth0` missing: confirmed cause `rd_cycle 188 ns, 32 ticks > 31 ticks` (the kernel rounds ns up to 6.06 ns ticks); DT now uses ns values that give U-Boot's exact NET_GPMC_CONFIG tick counts (cycle 186 ns = 31 ticks). Tested 2026-11-25: the GPMC error is gone and smsc911x probes, but fails without printing anything after the reset-GPIO lookup (no eth0, cable plugged in). Next on the board: CS5 GPMC_CONFIG1..7 and LAN9115 BYTE_TEST/ID_REV/PMT_CTRL via `devmem`, a driver rebind, and `smsc911x.debug=0xffff` on the kernel command line. `Illegal status in __nss_next` on the first one or two logins after boot, later logins fine (intermittent, so not a missing module); next on the board: `ls -l /etc/passwd /etc/shadow; login root` again right after boot, and `strace`/`LD_DEBUG=libs` if it repeats. SDK not built yet. |
| 5 | GPIO (LED), then I2C and SPI | todo |
| 6 | Later / optional | – |

---

## 0. Host and serial setup

### Serial console

The board side:
- connector **P20** ("UART1/2 RS-232", male DB9)
- **J8 on 1-2** selects UART1
- settings **115200 8N1**, no flow control

**Chosen setup: RS-232 → TTL → USB converters on the build PC.** This way:
- the console is a local `/dev/ttyUSB0`
- logs are saved next to the build tree
- later, U-Boot can be driven from the same machine (load images over serial or TFTP)

Your user is already in the `dialout` group.

Wiring checklist:
- **Cable:** P20 is a *male* DB9 wired like a PC port. Depending on the RS-232→TTL module's connector, you may need a **null-modem** cable or adapter. Symptom of a wrong one: nothing at all on the console.
- **TTL level:** set the USB-TTL adapter and the RS-232→TTL module to the same level (3.3 V preferred). Between the two converters it's TX→RX, RX→TX, GND→GND.
- **Fallback:** the server's native RS-232 port, with a null-modem cable, used over SSH.

Terminal (logging always on):

```sh
sudo apt install picocom          # or use: screen /dev/ttyUSB0 115200
mkdir -p ~/omap-build/logs
picocom -b 115200 --logfile ~/omap-build/logs/$(date +%F-%H%M)-console.log /dev/ttyUSB0
# quit: Ctrl-A Ctrl-X
```

### Build host

- **Packages:**
  `sudo apt install gcc-arm-linux-gnueabihf bison flex libssl-dev libgnutls28-dev u-boot-tools device-tree-compiler lzop bc python3-setuptools swig python3-dev picocom`
- Buildroot adds its own requirements (`build-essential`, `rsync`, `cpio`, `unzip`, `file`, `wget`).
- **Build trees go on the ext4 home disk:** `~/omap-build/{u-boot,linux,buildroot,logs}`. NTFS is too slow and breaks symlinks. This repo holds only scripts, configs, patches and docs.

### Hardware

SD card (≥ 1 GB), multimeter, and for step 5: an NPN transistor, an LED and resistors.

**Checkpoint 0:** `picocom` opens `/dev/ttyUSB0`, and shorting TX↔RX at the converter's DB9 echoes what you type (loopback test).

## 1. Baseline: capture what the board boots today

Nothing is written to the board in this step.

1. Power off. **Write down the current SW4 positions** (1–8) and the J8 position.
2. Connect the console, start `picocom` with logging, power on.
3. Capture everything: x-loader/U-Boot banners, any kernel output. If a U-Boot prompt appears, stop autoboot and run:
   - `version`, `bdinfo`, `printenv`, `onenand info` (or `nand info`), `mmc info` (with a card in)
   - `md.l 0x4830a204 1`: CONTROL_IDCODE (silicon revision, ES 2.x / 3.x)
   - `md.l 0x480022f0 1`: CONTROL_STATUS. The low 6 bits are the latched `sys_boot[5:0]`, a hardware check of the SW4 decoding in `doc/EXPANSION-CONNECTORS.md`.
4. Multimeter checks, board **unpowered** unless noted:
   - P7 A3/A4 = VIO_1V8 and A1/A2 = VBAT (powered measurements)
   - whether U134 / U122 / U126 are fitted
   - continuity from P7 A10 (EXP_SPI2_CLK) towards the processor-module connector, if reachable
5. Commit the log and the findings to `logs/baseline/` in this repo (small text files only).

**Checkpoint 1:** we know:
- the silicon revision
- the RAM size the old firmware reports
- whether the old OneNAND contents still boot
- the original SW4 setting
- the Rev D routing facts

## 2. Mainline U-Boot on SD

- **Source:** the latest U-Boot release tag. Config `omap3_evm_defconfig`, cross-compiled with `arm-linux-gnueabihf-`.
- **Outputs:** `MLO` (SPL) and `u-boot.img`.
- **SD layout:**
  - partition 1: FAT32, ~64 MB, **boot flag set**, holding `MLO` (must be the first file copied) and `u-boot.img`
  - partition 2: ext4, for the root filesystem
- **Switches:** SW4 = `ON ON ON ON OFF OFF OFF OFF` (USB → UART3 → **MMC1** → OneNAND).
- **Repo:** `scripts/build-uboot.sh` and `scripts/mksd.sh`.

**Checkpoint 2:**
- the SPL banner, then the `OMAP3_EVM #` prompt
- `mtest` over a few MB passes
- the SMSC LAN9115 is detected: `ping` to the host works

**ES2.1 MMC erratum (2.1.1.128):** multi-block reads on MMC1/2 corrupt data. Mainline U-Boot lost the single-block workaround in its driver-model MMC path, so the first SD boot failed with `Error reading cluster ... u-boot.img, err -5`. Fixed by `patches/u-boot/0001-mmc-omap_hsmmc-restore-single-block-quirk-for-OMAP34.patch`, which is worth sending upstream once tested. **Check the Linux `omap_hsmmc` driver for the same erratum in step 3.**

If the SPL hangs or RAM is unstable: apply the **Infineon DDR timing patch** (`FEASIBILITY.md` §7) as `patches/u-boot/0001-omap3evm-onenand-ddr-timings.patch`.

## 3. Mainline kernel + Rev D device tree

- **Kernel:** the newest LTS series, latest point release.
- **Config:** `omap2plus_defconfig` + `board/kernel.config` fragment. Start with `SPI_SPIDEV`, `GPIO_CDEV` and the MTD OneNAND driver; trim later.
- **Device tree:** `board/dts/omap3-evm-revd.dts` includes `omap3-evm.dts`, then:
  - OneNAND node instead of NAND
  - disable USB host (EHCI) and drop its pinmux and GPIO hogs (gpio_61, TWL GPIO2, gpio_21/22)
  - disable `mmc2`, `wlcore` and the WL12xx regulator
  - drop the `tvp5146` node
  - disable the TSC2046 touchscreen on `&mcspi1` (removed on this unit; the LCD stays)
  - `mmc1` 4-bit
  - memory 128 MB
  - LED pinmux on gpio_158
- **Boot:** `zImage` + `omap3-evm-revd.dtb` on the FAT partition, loaded by U-Boot (a `boot.scr` or an extlinux.conf). Console `ttyS0,115200n8`.
- **Repo:** `scripts/build-kernel.sh`.

**Checkpoint 3:**
- the kernel boots to a shell, using a Buildroot initramfs or rootfs (step 4)
- `dmesg` shows OneNAND, smsc911x, I2C1–3 and McSPI with no errors
- `cat /proc/meminfo` shows about 128 MB

## 4. Buildroot root filesystem + cross SDK

- **Buildroot:** latest LTS release, with a `board/buildroot/omap3evm_revd_defconfig` (external tree in this repo) for:
  - target: ARM Cortex-A8, EABIhf, NEON
  - glibc or musl (musl is smaller)
  - BusyBox
  - packages: **libgpiod (tools), i2c-tools, spi-tools**, dropbear (SSH), htop
- **Outputs:** an ext4 rootfs image for partition 2, plus `make sdk` → a relocatable **cross toolchain + sysroot** (libgpiod included) for your C programs.
- Optionally let Buildroot build the kernel and U-Boot too, once steps 2–3 work by hand.

**Checkpoint 4:**
- login over serial and over SSH
- `gpiodetect` lists 7 gpiochips (6 OMAP banks + TWL4030)
- a hello-world cross-compiled with the SDK runs on the board

## 5. GPIO, then I2C and SPI

1. **On-board LED** `omap3evm::ledb` via sysfs (no wiring).
2. **External LED** on P7 A18 / gpio_158 through an NPN transistor: `gpioset`, then `examples/gpio-blink/` (libgpiod C). See `GPIO-LED-TEST.md`.
3. **I2C2** (P7 A30/A31) or **I2C3** (P18 B25/B26) with a 1.8 V device, or a level shifter: `i2cdetect -y 1` (I2C2) or `-y 2` (I2C3). Linux numbers the buses from 0: I2C1 = `/dev/i2c-0`.
4. **SPI2** (P7 A10–A13, A15) with spidev: `spidev_test`, then a C program.

**Checkpoint 5:** the LED blinks from a C program you built with the SDK.

## 6. Later / optional

- Writing the new bootloader + kernel + rootfs to **OneNAND** (UBI/UBIFS), to boot without an SD card
- Power management (cpufreq, suspend), the LCD + touchscreen with omapdrm
- TWL4030 MADC analog inputs via IIO
- Trimmed kernel config, faster boot
- Upstreaming the Rev D / OneNAND device tree, if it turns out clean

## Planned repo layout

```
board/       dts/omap3-evm-revd.dts, kernel.config, buildroot/ (BR2_EXTERNAL tree)
patches/     u-boot/, linux/
scripts/     build-uboot.sh, build-kernel.sh, mksd.sh
examples/    gpio-blink/, ...
logs/        baseline/ and other small text logs worth keeping
doc/         reference material (see doc/README.md)
```
