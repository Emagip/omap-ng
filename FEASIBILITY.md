# Feasibility study: modern mainline Linux on the TI TMDSEVM3530 (OMAP35x EVM)

Date: 2026-11-24. Paper study only: nothing has been built or flashed yet.

## TL;DR

| Question | Answer |
|---|---|
| Can a recent kernel run on it? | **Yes, very feasible.** Mainline Linux (checked at 7.4-rc4) ships `omap3-evm.dts` with the model string "TI OMAP35XX EVM (TMDSEVM3530)". It builds from the stock `omap2plus_defconfig`. OMAP2+ is still listed as *Maintained*. |
| Bootloader? | **Mainline U-Boot (checked at v2027.01-rc3) still has `omap3_evm_defconfig`**, maintained by Tom Rini. U-Boot SPL (`MLO`) replaces the old x-loader. |
| Compile code for it? | **Yes.** It is ARMv7-A (Cortex-A8, VFPv3 + NEON), so the standard `arm-linux-gnueabihf` / Debian **armhf** target fits. Ubuntu's `gcc-arm-linux-gnueabihf` package or a Buildroot toolchain works. |
| GPIO / I2C / SPI from user space? | **Yes, with caveats**: 1.8 V I/O levels, a pinmux that has to be set in the device tree, and McSPI2 shared with USB host. Details below. |
| Main risk | Processor-module variant (NAND vs **OneNAND**, 128 vs 256 MB) and older main-board revisions. Booting from SD card avoids most of it. |

The TI SDKs in this folder (`OMAP35x_SDK_1.0.2`, kernel 2.6.22; PSP `02.01.01.08`, kernel 2.6.29-rc3, 2009) are **not needed** for this route. They are still useful as hardware documentation and as a known-good fallback. Leave the NAND contents alone.

---

## 1. Board and SoC facts relevant to a modern kernel

- **SoC:** OMAP3530, a Cortex-A8 at up to 600–720 MHz with NEON, plus a C64x+ DSP, an SGX530 GPU and an ISP.
- **PMIC:** TWL4030 on I2C1 at 0x48. It also provides 18 GPIOs, the keypad, the LED and audio.
- **Ethernet:** SMSC on GPMC CS5. That is a LAN9115 on "Gen 1" main boards and a LAN9220 on "Gen 2" (Rev ≥ E) boards. Both use the mainline `smsc911x` driver.
- **Memory:** a PoP part on the processor module.
  - Mainline U-Boot detects it automatically (`board/ti/omap3evm/evm.c`): Hynix gives 256 MB DDR, anything else is treated as Micron 128 MB.
  - The kernel DTS says 256 MB, but U-Boot fixes up `/memory`, so a 128 MB module also works.
- **Flash:** the PSP docs mention both **Micron NAND** and **Samsung OneNAND** processor modules (`scripts/initenv-micron.txt` and `scripts/initenv-samsung.txt`).
- **Supported silicon:** the PSP lists main board Rev C or later with processor board Rev B or later, and OMAP35x ES2.1 or ES3.1. Mainline handles both silicon revisions.

### What works in mainline (expected)

UART console, MMC1 (SD), Ethernet, TWL4030 (regulators, RTC, GPIO, keypad, LED, power-off), the LCD (Sharp LS037V7DW01 panel through omapdrm), the TSC2046 touchscreen, MUSB OTG, EHCI on USB host port 2, NAND (bch8 ECC), cpufreq/PM, and the I2C, SPI and GPIO controllers.

### What will not work, or not usefully

- **C64x+ DSP:** the old DSP Bridge driver was removed from the kernel years ago. Treat the DSP as unavailable.
- **SGX530 3D GPU:** there is no mainline driver, so you get 2D/framebuffer through omapdrm only.
- **WL12xx Wi-Fi on MMC2:** the DTS describes it, but older boards don't have it. On those boards it just fails to probe, which is harmless.
- **USB host on older main boards:** possibly broken. The DTS hard-codes the Gen-2 EHCI PHY wiring (gpio_21 reset, gpio_22 VBUS, the gpio_61 hog). If USB host doesn't work on your board, this is the first suspect; it is a small DT patch.

## 2. Boot strategy (recommended: SD card; don't touch NAND)

1. **SD card, partition 1:** FAT32 holding `MLO` (U-Boot SPL), `u-boot.img`, `zImage` and `omap3-evm.dtb`.
2. **SD card, partition 2:** ext4 root filesystem.
3. **SW4 boot switch:** set it to a boot order with MMC first. See *UserGuide-02.01.01.08.pdf* §4.3.1, "Boot switch position" (Figure 4.1, p. 34). The figure is an image, so read it from the PDF.
4. **Console:** UART1 serial at 115200 8N1. Your `test.ccf` already targets UART1 at 115200. The PSP guide says to set **jumper J8 to 1-2** for UART1.

Why not NAND:

- The NAND currently holds the 2009 x-load/u-boot, written with the old 1-bit Hamming ECC layout.
- Mainline uses BCH8 and a different partition map: `512k(spl),1920k(u-boot),128k(env),128k(dtb),6m(kernel),-(rootfs)`.
- Mixing the two is how boards get soft-bricked. SD boot leaves the factory NAND intact as a fallback.

### OneNAND caveat

If your processor module is the Samsung **OneNAND** variant, mainline `omap3_evm_defconfig` only configures raw NAND. Two consequences:

- **RAM detection:** the SPL's RAM detection reads a NAND ID on GPMC CS0. On a OneNAND module it would fall back to Micron 128 MB timings. That might work, or might be marginal, for Samsung DDR.
- **Possible fix:** a small U-Boot patch (static timings) plus `status = "disabled"` on the DT `nand@0,0` node.

Check which module you have: the old U-Boot boot log or the PoP marking tells you.

## 3. Compiling code for it

- **Host packages (Ubuntu 26.04):**
  - `gcc-arm-linux-gnueabihf`
  - `bison`
  - `flex`
  - `libssl-dev`
  - `u-boot-tools`
  - `device-tree-compiler`
  - `lzop`
  - `bc` (already installed)

  The cross-compiler, `bison`, `flex`, `mkimage` and `dtc` are currently **missing** on this machine.
- **Kernel:** `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig`, then `zImage dtbs modules`. Then enable the options listed in §4.
- **Root filesystem, options:**
  - **Buildroot:** best fit for 128 MB of RAM. Small, and it generates its own matching toolchain and SDK.
  - **Debian 13 (trixie) armhf via debootstrap:** a full `apt` ecosystem and native `gcc` on the board. Fine with 256 MB, workable with 128 MB without a desktop. It is slow; compiling on the board is possible but painful.
- **User code:** cross-compile with `arm-linux-gnueabihf-gcc -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard`. Plain armhf binaries also run.

## 4. GPIO / I2C / SPI from the connectors

### Electrical warning

OMAP3 I/O is **1.8 V** and is **not 3.3 V tolerant**. Anything you attach to expansion-connector pins needs level shifting, or must be 1.8 V parts.

### Bus usage, from the mainline DTS (`omap3-evm-common.dtsi` and `omap3-evm-processor-common.dtsi`)

| Bus | Mainline state on this board | Usable for your own devices? |
|---|---|---|
| I2C1 | 2.6 MHz, TWL4030 PMIC | **No.** Leave it to the PMIC. |
| I2C2 | Enabled, 400 kHz, **no devices** | **Yes, the best candidate.** |
| I2C3 | 400 kHz, TVP5146 at 0x5c (multimedia daughter card) | Yes, if your addresses don't clash. |
| McSPI1 | CS0 = TSC2046 touchscreen. The CS2 pad is reused as gpio_176 (Ethernet IRQ), the CS3 pad as hsusb2_data2. | CS1 *might* be free. Needs the schematic. |
| McSPI2 | **All pads muxed to USB host port 2 (EHCI ULPI data)** | Only if you give up EHCI host by editing the DT pinmux. |
| McSPI3/4 | Not muxed. The pads are shared with other functions. | Depends on which pads reach the connectors. |
| OMAP GPIO banks 1–6 | Many pins are already used (LCD, Ethernet, USB, Wi-Fi) | Yes, for pins that reach a connector and are free. |
| TWL4030 GPIOs | Some used (LED, backlight, the GPIO_61 route hog) | A few spares. These are I2C-attached, so slow. |

### Software side (mainline)

- **I2C:** `CONFIG_I2C_CHARDEV=y` is already in `omap2plus_defconfig`. You get `/dev/i2c-N` and can use `i2c-tools`.
- **GPIO:** use the chardev and libgpiod (`gpiodetect`, `gpioset`, `gpioget`). `CONFIG_GPIO_SYSFS=y` is also set, but deprecated.
- **SPI:** `CONFIG_SPI_OMAP24XX=y` is set. **`CONFIG_SPI_SPIDEV` is not**, so enable it. Then add a DT child under `&mcspiN` with one of the compatibles spidev accepts (a bare `"spidev"` is rejected), or bind through `driver_override`.
- **Pinmux:** mainline has **no runtime pinmux from user space**. Any pad you want as GPIO, I2C or SPI must be muxed by a `pinctrl-single` entry in the DT, using the same `OMAP3_CORE1_IOPAD(...)` pattern as the existing nodes. The clean approach is a small board `.dts` that includes `omap3-evm.dts`, or a DT overlay loaded by U-Boot.

### Still missing: the physical connector pinout

The SDK docs in this folder don't include the main-board expansion-connector tables or the schematic. I tried to fetch them online, but the Farnell datasheet timed out and the old `processors.wiki.ti.com` no longer resolves, so I did not confirm them. The TI wiki page that was down says the multimedia daughter card repeats the main board's expansion-connector pinout, so the daughter card's schematic or guide also gives the pin map.

To get the exact pin map, find one of these:

- the **Mistral "OMAP35x EVM Hardware User Guide"**
- the **main-board schematic**: the TI OMAP3EVM pages linked schematic and layout PDFs
- the **multimedia daughter card** docs

With that, the last step is a desk exercise: for each connector pin, find its OMAP pad, check that it doesn't conflict with the table above, and write the pinmux node.

## 5. Effort estimate

| Step | Effort |
|---|---|
| Install toolchain, build mainline U-Boot and kernel from defconfigs | ~1 hour, mostly compile time (16 cores) |
| Buildroot root filesystem | 1–2 hours of compile time, once |
| First boot on SD over serial | Easy, *if* it's a NAND module and a Gen-2 board |
| Debug for an older board or OneNAND module | Small DT and U-Boot patches, from a day to a few days |
| Custom DT for your GPIO/I2C/SPI pins | A few hours, once the schematic is in hand |

## 6. Host-side notes for this folder

- `/run/media/emagip/DaFunnyDrive` is NTFS (fuseblk). Kernel and Buildroot builds there will be slow and can break: symlinks, permissions, executable bits. **Put build trees on the ext4 home disk** (~660 GB free), not on this drive. Keep only scripts, notes and final images here.
- The NTFS ownership needed `git config --global --add safe.directory <this repo>`.
- `src/` (git-ignored) holds sparse reference checkouts of mainline Linux and U-Boot, used for this study:
  - `src/linux-dts` (torvalds/linux `8d7fe98`, 7.4-rc4: `arch/arm/boot/dts/ti/omap`, `arch/arm/configs`)
  - `src/u-boot-probe` (u-boot `ee1b347`, v2027.01-rc3: `configs`, `board/ti`)

## 7. Open questions for you

1. Processor module: NAND (Micron) or OneNAND (Samsung)? 128 or 256 MB?
2. Main-board revision, from the silkscreen: Rev C/D (Gen 1) or Rev E/G (Gen 2)?
3. Do you have the multimedia daughter card fitted? It occupies I2C3, McBSP and the camera port.
4. What do you want to attach (which buses, voltages)? That decides which pins to mux.
