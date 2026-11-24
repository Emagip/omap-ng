# Baseline, 2026-11-24: what the board boots today

Log: `2026-11-24-old-uboot-console.log`, cleaned of CR/NUL/backspaces. The MAC address is partly redacted (the full one is in the local log in `~/omap-build/logs/`).

Setup:
- console on P20 via RS-232→TTL→USB, 115200 8N1, J8 = UART1
- **SW4 = `ON ON ON ON OFF OFF OFF OFF`**, already the SD-first setting from `ROADMAP.md`
- no SD card inserted

## What booted

| Stage | Version | Notes |
|---|---|---|
| X-Loader | TI **1.42** | Detects a **Samsung MuxOneNAND1G**; "No NAND device found" is expected |
| U-Boot | **2008.10** (built May 22 2009) | From TI PSP 02.01.01.08, the same build date as the files in `../../temps_sd/`. Prints "OMAP3 EVM board + LPDDR/ONENAND". |
| Kernel | not started | `bootcmd` reads the kernel from OneNAND 0x280000. It's still there (uImage, 2.6.29 era). |

## Hardware facts confirmed

| Item | Value | How |
|---|---|---|
| **Silicon** | **OMAP3530 ES2.1**, GP device | `CONTROL_IDCODE` = `0x2B7AE02F` (TRM Table 1-10: ES2.1). U-Boot: "OMAP35X-Family-GP rev 2". |
| Device type | GP (general purpose): unsigned `MLO` is fine | `CONTROL_STATUS[10:8]` = 0x3 |
| **Boot pins** | `sys_boot[5:0]` = **0b110000** (0x30): sys_boot5 = 1, [4:0] = 0b10000 → USB → UART3 → MMC1 → OneNAND | `CONTROL_STATUS[5:0]` = 0x30. **This matches the SW4 decoding in `doc/EXPANSION-CONNECTORS.md` exactly (ON = 0)**, so the polarity is now confirmed in hardware too. With no SD card the ROM fell through to OneNAND, as expected. |
| OneNAND | **128 MB**, muxed, 1.8 V, 16-bit (device ID 0x30) | `onenand info` |
| RAM | 128 MB (`mem=128M` in bootargs) | The old U-Boot's `bdinfo` doesn't fill in DRAM size. Mainline U-Boot will report it. |
| PoP part | K5W1G1GACM-DL60 = 1 Gb OneNAND + 1 Gb mDDR | consistent with the two lines above |
| Clocks at boot | "CPU-OPP2, L3 165 MHz": DDR at ~166 MHz | X-Loader/U-Boot banner |
| Ethernet MAC | `00:50:C2:xx:xx:xx`, stored in the old U-Boot environment | Carry it over to the mainline U-Boot environment (`ethaddr`) |
| Old network setup | board 192.168.1.10, TFTP server 192.168.1.57 | old U-Boot `printenv` |

## ES2.1 and mainline

- ES2.1 is explicitly supported in mainline Linux: `arch/arm/mach-omap2/id.c`, the ES2-specific restore path in `control.c`, the `omap3430es2plus` clock tables in `omap34xx.dtsi`, and the ES1/ES2 variant of the display controller in `display.c`.
- **Not available on ES2.1:** IO-chain control (`OMAP3_HAS_IO_CHAIN_CTRL` is ES3.1+ only). It only matters for wakeup from off-mode; ignore it for now.
- Check `doc/02-soc-omap3530/sprz278f-omap3530-silicon-errata.pdf` for ES2.1 errata if anything odd shows up (MMC, USB, PM).
- Max CPU clock on ES2.1 may be lower than on ES3.1. Start without aggressive cpufreq OPPs.

## Not done / still open

- **Ethernet:** not tested here (no `ping`). It will be tested with mainline U-Boot.
- **Multimeter checks** (P7/P18 power pins, U134/U122/U126 fitted or not): still to do before wiring anything to the expansion connectors.
- **Old OneNAND contents are kept as they are.** They are the fallback when no SD card is inserted.
