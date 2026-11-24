# Reference documentation: TMDSEVM3530 (OMAP35x EVM)

Collected 2026-11-24. Every file below was downloaded from the source listed, or copied from mainline sources or the local 2009 SDK, so later sessions don't need to go online again. The newest public revision is used where one exists.

The target board is an **older main-board revision** with a **Samsung OneNAND processor module**, **no multimedia daughter card** and **no WL1271 Wi-Fi**.

## Layout

| Folder | Contents |
|---|---|
| `01-board-evm/` | EVM-level docs: Mistral and TI datasheets, switch errata, module datasheets, connector photos |
| `02-soc-omap3530/` | OMAP3530 data manual, technical reference manual, silicon errata |
| `03-onboard-chips/` | TWL4030/TPS65950 PMIC, SMSC/Microchip Ethernet |
| `04-linux-mainline/` | Excerpts from mainline Linux 7.4-rc4 and U-Boot v2027.01-rc3: board DTS, bindings, user-space GPIO/I2C/SPI API docs, U-Boot board code |
| `05-legacy-psp-2009/` | Board files from the TI PSP 02.01.01.08 kernel (2.6.29) in `../../OMAP35x-PSP-SDK-02.01.01.08`. These are the original description of the *old* board. |

## 01-board-evm

| File | What it is | Source |
|---|---|---|
| `mistral-omap35x-evm-datasheet-old-build.pdf` | Mistral EVM datasheet, **old build**. Interfaces, memory options, expansion-connector interface list. | archive.org copy of mistralsolutions.com `datasheets/35x_EVM_old_build.pdf` (2010) |
| `mistral-omap35x-evm-datasheet.pdf` | Same datasheet, newer build | farnell.com/datasheets/1500928.pdf |
| `mistral-hw-user-guide-errata-SW4-SW1.pdf` | **Correct SW4 (boot) and SW1 settings.** Corrects the Hardware User Guide. Read it before changing switches. | archive.org copy of Mistral `Errata.pdf` (2009) |
| `mistral-processor-module-datasheet-old.pdf` / `…-datasheet.pdf` | OMAP35x processor module, old and newer | archive.org copies of Mistral `Processor_Module*.pdf` |
| `mistral-power-module-datasheet-old.pdf` / `…-datasheet.pdf` | TWL4030 power module | archive.org copies of Mistral `Power_Module*.pdf` |
| `mistral-ecn-rework-mainboard-revG.pdf` | USB VBUS rework notes. **Applies to main board Rev G only.** Kept for comparison. | archive.org copy of Mistral `tmdsevm3530/documentation/ecn_layout.pdf` |
| `ti-tmdsevm3530-product-brief.pdf` | TI product brief | media.digikey.com |
| `ti-omap35x-evm-overview-presentation.pdf` | TI EVM overview slides (50 pp) | farnell.com/datasheets/1759493.pdf |
| `ti-omap3530-evm-quick-start-guide.pdf` | TI quick start, DVSDK 4.01: switch settings, cabling | software-dl.ti.com |
| `ti-wiki-evm-front.gif`, `ti-wiki-evm-back-connectors.gif` | Annotated board photos | archive.org copy of the dead processors.wiki.ti.com "OMAP35x EVM" page |

## 02-soc-omap3530

| File | What it is | Source |
|---|---|---|
| `sprs507h-omap3530-datasheet.pdf` | OMAP3530/25 data manual, Rev H (Oct 2013, latest). Ball map, **pad mux modes**, electrical specs. | ti.com/lit/pdf/sprs507 |
| `spruf98y-omap35x-technical-reference-manual.pdf` | OMAP35x TRM, Rev Y (latest, ~30 MB). SCM/pad-config registers, GPIO, McSPI, I2C, GPMC. | ti.com/lit/pdf/spruf98 |
| `sprz278f-omap3530-silicon-errata.pdf` | Silicon errata, Rev F (ES2.0 to 3.1.2) | ti.com/lit/pdf/sprz278 |

## 03-onboard-chips

| File | What it is | Source |
|---|---|---|
| `swcs032f-tps65950-twl4030-data-manual.pdf` | TPS65950 data manual, Rev F. The TPS65950 is the catalog version of the TWL4030: same GPIOs, regulators, MADC, keypad. | ti.com/lit/pdf/swcs032 |
| `microchip-lan9115-ethernet-datasheet.pdf` | SMSC/Microchip LAN9115. **Likely the Ethernet chip on old (Gen 1) main boards.** | ww1.microchip.com DS00002269A |
| `microchip-lan9220-ethernet-datasheet.pdf` | LAN9220, used on Gen 2 (Rev ≥ E) main boards | ww1.microchip.com DS00002417A |

## 04-linux-mainline

- `dts/`
  - Board: `omap3-evm.dts` with its two included `.dtsi` files.
  - SoC: `omap3.dtsi` and `omap34xx.dtsi`.
  - PMIC: `twl4030*.dtsi`.
  - Ethernet: `omap-gpmc-smsc911x.dtsi`.
  - `omap3430-sdp.dts` is the **template for OneNAND on GPMC**: same SoC family, with a `ti,omap2-onenand` node.
- `kernel-docs/`
  - User-space API:
    - `gpio-chardev.rst`: the GPIO character-device API, which is what your C programs will use.
    - `i2c-dev-interface.rst`: `/dev/i2c-N`.
    - `spidev.rst`: `/dev/spidevB.C`.
  - DT bindings:
    - `pinctrl-single.yaml`, plus `dt-bindings-pinctrl-omap.h` for the `OMAP3_CORE1_IOPAD` macros.
    - `ti,gpmc*.yaml`, including **`ti,gpmc-onenand.yaml`**.
  - `arm-omap.rst`: general OMAP notes.
  - `gpio-tools-examples/`: the kernel's own small C programs using the GPIO chardev (`lsgpio`, `gpio-hammer`, `gpio-event-mon`). Good starting points for your own code.
- `u-boot/`
  - `omap3_evm_defconfig`.
  - `evm.c` and `evm.h`: board revision detection (Gen 1 = LAN9115, Gen 2 = LAN9220) and the DDR selection (Hynix gives 256 MB, otherwise Micron 128 MB timings).

## 05-legacy-psp-2009 (the original description of *your* board generation)

- `mach-omap2/board-omap3evm.c`: I2C1 at 2.6 MHz (TWL4030); **I2C2 and I2C3 registered at 400 kHz with no devices**, so they are free for expansion use. Also the Ethernet IRQ GPIO, LCD GPIOs, and MMC1 (4-bit, WP = gpio_63, CD = TWL GPIO0). A comment says some TWL GPIOs go to the **"P2" connector**.
- `mach-omap2/board-omap3evm-flash.c`: the **OneNAND partition map** (x-loader 512 KiB, u-boot 1.875 MiB, params 128 KiB, kernel 5 MiB, jffs2 rest) and the NAND map.
- `include/mach/mux.h`: the old pad-mux names, handy to cross-check against the TRM.
- `configs/omap3_evm_defconfig`: the 2009 kernel config.

## Not obtained (links only)

| Document | Why it's missing | Where |
|---|---|---|
| **Main-board schematic** (`omap35x_evm_mb_sch_revg.pdf`, Rev G "based on Rev D") | The e2e server returned HTTP 500 to the automated download. Download it from a browser. It's the main hope for the **expansion-connector pinout**. | https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/791/omap35x_5F00_evm_5F00_mb_5F00_sch_5F00_revg.pdf |
| Mistral **Hardware User Guide**, processor/power/main-board schematics, Gerbers | Gated behind a Mistral login, and the old site is gone. Shipped on the EVM's DVD/SD card: check your kit's original media. | Mistral support pages, archived at web.archive.org: `mistralsolutions.com/assets/downloads/3530.php` |
| TPS65950 TRM (SWCU050) | ti.com requires a myTI login | https://www.ti.com/lit/pdf/swcu050 |
| Samsung OneNAND PoP datasheet | Part number unknown until the board markings are read | – |

## Online references (latest, not downloaded)

- Mainline kernel docs: https://docs.kernel.org/ (see the userspace-api/gpio, i2c, spi and devicetree sections)
- libgpiod (the C library and tools for the GPIO chardev): https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/
- U-Boot docs: https://docs.u-boot.org/
- Buildroot manual: https://buildroot.org/downloads/manual/manual.html
- OMAP mailing list and patchwork: linux-omap@vger.kernel.org, https://patchwork.kernel.org/project/linux-omap/list/
- TI product page (current datasheet and errata revisions): https://www.ti.com/product/OMAP3530
- BeagleBoard (same OMAP3530, best-documented OMAP3 community board): https://old.beagleboard.org/hardware/design

## Local copies already in the parent folder (not duplicated)

- `../../OMAP35x-PSP-SDK-02.01.01.08/docs/`: PSP 02.01.01.08 User Guide (SW4 figure §4.3.1, OneNAND flashing), Release Notes, Migration Guide, Data Sheet.
- `../../OMAP35x_SDK_1.0.2/docs/OMAP35x/`: SDK 1.0.2 User Guide, Data Sheet, daughter card addendum.
- A newer PSP user guide (03.00.00.02, Sept 2009) is public at software-dl.ti.com but adds little over the local 02.01.01.08 one, so it was skipped.
