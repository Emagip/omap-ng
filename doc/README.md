# Reference documentation: TMDSEVM3530 (OMAP35x EVM)

Collected 2026-11-24. Every file below was downloaded from the source listed, or copied from mainline sources or the local 2009 SDK, so later sessions don't need to go online again. The newest public revision is used where one exists.

The target board:

- Main board `OMAP-EVM-MB-1518` **Rev D** (Gen 1)
- Processor module `O3530-PB-1518` Rev B, with **Samsung K5W1G1GACM-DL60** OneNAND + 128 MB mDDR PoP
- Power module `T4030-PW-1518`
- **No multimedia daughter card**, **no WL1271 Wi-Fi**

**Start with `EXPANSION-CONNECTORS.md`**: the P7/P18 pinout, mapped to OMAP pads and Linux GPIO numbers, plus SW4 boot-switch settings.

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
| `microchip-lan9115-ethernet-datasheet.pdf` | SMSC/Microchip LAN9115. **The Ethernet chip on this Rev D (Gen 1) main board.** | ww1.microchip.com DS00002269A |
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

## Not redistributed: get them yourself, keep them in `doc/private/` (git-ignored)

These documents are needed for some details but **must not be pushed to the public repo**. Put them in `doc/private/` under the file names below and the references in this repo will match.

| Local file name (`doc/private/`) | What it is | Why it isn't in the repo | Where to get it |
|---|---|---|---|
| `ti-omap35x-evm-mainboard-schematic-revG.pdf` | **OMAP35x EVM main-board schematic, Rev G** (20 sheets, Sept 2009; revision history back to Rev D). Sheet 9 = expansion connectors P7/P18 and SW4; sheet 10 = UARTs; sheet 16 = the Rev E+ bus switches. Decoded (as tables) in `EXPANSION-CONNECTORS.md`. | Stamped "TI Proprietary Information / Under Non-Disclosure Agreement" | Attachment on TI's E2E forum: https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/791/omap35x_5F00_evm_5F00_mb_5F00_sch_5F00_revg.pdf (download in a browser). Originally on the EVM's DVD and Mistral's (login-gated, now defunct) support site. |
| `schematic-crops/*.png` | High-resolution crops of schematic sheet 9 (P7, P18, power pins, SW4) | Derived from the NDA-stamped schematic | Render them yourself: `pdftoppm -f 9 -l 9 -r 300 -png <schematic>.pdf sheet9` |
| `swcu050g-tps65950-twl4030-technical-reference-manual.pdf` | **TPS65950 (TWL4030) Technical Reference Manual, SWCU050 Rev G** (947 pp): full register map for GPIO, LED, regulators, USB PHY, MADC | Distributed by TI only behind a myTI login | https://www.ti.com/lit/pdf/swcu050 (free myTI account required) |

## Not obtained (links only)

| Document | Why it's missing | Where |
|---|---|---|
| Main-board schematic **Rev D** exactly | Only Rev G is public. Rev D differences come from its revision history; see `EXPANSION-CONNECTORS.md`. | – |
| Processor-module and power-module schematics | Mistral login | – |
| Mistral **Hardware User Guide**, processor/power/main-board schematics, Gerbers | Gated behind a Mistral login, and the old site is gone. Shipped on the EVM's DVD/SD card: check your kit's original media. | Mistral support pages, archived at web.archive.org: `mistralsolutions.com/assets/downloads/3530.php` |
| Samsung OneNAND+mDDR PoP datasheet (**K5W1G1GACM-DL60**) | No public datasheet found. The closest are the standalone 1 Gb OneNAND KFG1G16U2B/C datasheets. | – |

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
