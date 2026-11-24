# OMAP35x EVM expansion connectors: P7 and P18 (Rev D main board)

**Source:** `01-board-evm/ti-omap35x-evm-mainboard-schematic-revG.pdf`, sheet 9 ("Expansion Module Connectors"). Cropped images of the connector symbols are in `01-board-evm/expansion-connectors/`.

**Pad → GPIO numbers:** from `02-soc-omap3530/sprs507h-omap3530-datasheet.pdf`. Mode 4 = `gpio_N`. In Linux, `gpio_N` is line `N % 32` of bank `N / 32 + 1`: `gpio_178` is `gpio6` line 18, i.e. gpiochip5 line 18 in libgpiod numbering. Check with `gpioinfo`.

> **The schematic is Rev G ("based on Rev D"); your board is Rev D.** Its revision history says Rev E added "on-board MDC support", camera and WL1271 support. With them came the bus switches on sheet 16 (U134 SN74CB3Q16211, U122/U126 level shifters, U131/U130 switches), which route the `EXP_*` nets either to the on-board USB/camera parts or to the connector. **On Rev D those parts should not exist, and the `EXP_*` nets should go straight from the OMAP to the connector.** This is inferred, not shown in a Rev D drawing. Before relying on it:
> - check the board for U134, U122 and U126 (they should be absent)
> - check continuity from a connector pin to a known test point or via, with the board **unpowered**

> **Electrical:** every OMAP signal here is **1.8 V** logic and **not 3.3 V tolerant**. Use level shifters or 1.8 V parts.
> - **P7 power pins:** A1–A2 / B1–B2 = **VBAT** (battery/main input rail, *not* a logic supply) and A3–A4 / B3–B4 = **VIO_1V8**.
> - **P18 power pins:** VBAT, and the TWL4030 LDO outputs VAUX1, VAUX2, VAUX4, VMMC2 and VSIM. Those are off unless Linux enables the regulator.
> - These power-pin positions are read from the drawing. **Measure them before connecting anything.**

## Connector P7 ("GP Expansion Connector 1", 2×60, CON_PMC_60X2_F)

| Pin | Net | OMAP pad / ball | GPIO | Status on your board (Rev D, no daughter card, no Wi-Fi) |
|---|---|---|---|---|
| A1–A2, B1–B2 | VBAT | – | – | power (measure) |
| A3–A4, B3–B4 | VIO_1V8 | – | – | **1.8 V supply for level shifters** |
| A5 | T2_REGEN | TWL4030 | – | PMIC control: don't touch |
| A6 | T2_nRESPWARM | TWL4030 | – | PMIC/reset: don't touch |
| A7 | T2_START.ADC | TWL4030 | – | MADC conversion trigger |
| A8, A9 | T2_PCM_BTDX / BTDR | TWL4030 | – | TWL voice/BT PCM port |
| **A10** | EXP_SPI2_CLK | mcspi2_clk / AA3 | **178** | **free: McSPI2 SPI bus.** Mainline DT muxes it to USB host; remove that for Rev D. |
| **A11** | EXP_SPI2_SIMO | mcspi2_simo / Y2 | **179** | **free: McSPI2** |
| **A12** | EXP_SPI2_SOMI | mcspi2_somi / Y3 | **180** | **free: McSPI2** |
| **A13** | EXP_SPI2_nCS0 | mcspi2_cs0 / Y4 | **181** | **free: McSPI2 CS0** |
| A14 | SYS_CLKREQ | sys_clkreq / AF25 | 1 | system clock request: leave alone |
| **A15** | EXP_McSPI2_CS1 | mcspi2_cs1 / V3 | **182** | **free: McSPI2 CS1** |
| A16 | MCBSP1_CLKR | mcbsp1_clkr / U19 | 156 | free (McBSP1 unused) |
| A17 | EXP_MCBSP1_FSR | mcbsp1_fsr / AA21 | 157 | free |
| A18 | MCBSP1_DX | mcbsp1_dx / V21 | 158 | free |
| A19 | MCBSP1_DR | mcbsp1_dr / U21 | 159 | free |
| A20 | MCBSP1_FSX | mcbsp1_fsx / K26 | 161 | free |
| A21 | MCBSP1_CLKX | mcbsp1_clkx / W21 | 162 | free |
| A22, A23 | UART1_TX / RX | uart1_tx / rx | 148 / 151 | **in use: serial console (RS-232 port, J8 1-2)** |
| A24 | UART1_CTS | uart1_cts / W8 | 150 | free once the Wi-Fi nodes are removed from the DT |
| A25 | UART1_RTS | uart1_rts / AA9 | 149 | free once the Wi-Fi nodes are removed from the DT |
| A26 | EXP_MCBSP3_CLKX | mcbsp3_clkx / AF5 | 142 | free |
| A27 | EXP_MCBSP3_DR | mcbsp3_dr / AE6 | 141 | free |
| A28 | EXP_MCBSP3_DX | mcbsp3_dx / AF6 | 140 | free |
| A29 | EXP_MCBSP3_FSX | mcbsp3_fsx / AE5 | 143 | free |
| **A30** | I2C2_SDA | i2c2_sda / AE15 | 183 | **I2C2 bus: free.** No pull-ups seen on the main board: add 1.8 V pull-ups (e.g. 4.7 kΩ to VIO_1V8) if the bus floats. |
| **A31** | I2C2_SCL | i2c2_scl / AF15 | 168 | **I2C2 bus: free** (same pull-up note) |
| A32 | EXP_UART3_RX | uart3_rx_irrx / H24 | 165 | UART3 also goes to the board's second serial port (sheet 10). Check that before reusing it. |
| A33 | T2_ADCIN7 | TWL4030 MADC | – | analog input (twl4030-madc, IIO) |
| A34 | EXP_UART3_RTS | uart3_rts_sd / F24 | 164 | see A32 |
| A35 | EXP_UART3_CTS | uart3_cts_rctx / H18 | 163 | see A32 |
| A36 | UART2_CTS | uart2_cts / AB26 | 144 | likely free on Rev D |
| A37 | UART2_RTS | uart2_rts / AB25 | 145 | likely free |
| A38 | UART2_TX | uart2_tx / AA25 | 146 | likely free (UART2 is a full spare UART) |
| A39 | UART2_RX | uart2_rx / AD25 | 147 | likely free |
| A40 | MMC2_CLKO_BUF | mmc2_clk via buffer U151 | (130) | buffered clock. On Rev G the U151 path is DNI. |
| A41 | MMC2_CMD | mmc2_cmd / R10 | 131 | **free (no Wi-Fi)**: GPIO or a second SD/SDIO |
| A42–A49 | MMC2_DAT7 … DAT0 | mmc2_dat7..0 | 139 … 132 | **free (no Wi-Fi)**: 8 GPIOs (A42 = 139 … A49 = 132) |
| A50 | SYSEN | TWL4030 | – | PMIC: don't touch |
| A51 | EXP_UART3_TX | uart3_tx_irtx / G24 | 166 | see A32 |
| A52 | REFCLK_EXP | clock out | – | reference clock |
| A53 | 32KHZ_EXP | 32 kHz clock | – | 32 kHz clock |
| B5 | T2_LEDSYNC | TWL4030 | – | |
| B6 | T2_GPIO.1_EXP | TWL4030 GPIO1 | twl 1 | TWL GPIO (slow, over I2C) |
| B7 | EXP_T2_GPIO.8 | TWL4030 GPIO8 | twl 8 | TWL GPIO. On Rev G it's also nCAM_VD_EN. |
| B8–B13 | T2_ADCIN0, 2, 3, 4, 5, 6 | TWL4030 MADC | – | **analog inputs** |
| B14–B37 | DSS_D0 … DSS_D23 | dss_data0..23 | – | **in use: LCD** |
| B38–B41 | DSS_ACBIAS / PCLK / VSYNC / HSYNC | dss_* | – | **in use: LCD** |
| B42–B51 | MMC1_CLKO, CMD, DAT7…DAT0 | mmc1_* | – | **in use: SD card slot** |
| B52 | SYS_CLKOUT2 | sys_clkout2 / AE22 | 186 | configurable clock output |
| B53 | SYS_CLKOUT1 | sys_clkout1 / AG25 | 10 | clock output |
| A55–A60, B55–B60 | GND | | | |

## Connector P18 ("GP Expansion Connector 2", 2×60)

Mostly the GPMC memory bus, camera port, ETK/trace and SYS_BOOT. **Don't use the GPMC address/data lines (A12–A24, B12–B24) as GPIO**: they're the live bus to OneNAND (CS0) and Ethernet (CS5).

| Pin | Net | Pad | GPIO | Status |
|---|---|---|---|---|
| A1 / B1 | VBAT | | | power (measure) |
| A2 / B2 / B3(?) | VAUX1_OUT / VAUX2_OUT / VAUX4_OUT | TWL4030 LDOs | | switchable supplies (measure) |
| A3 / A4 | VMMC2_OUT / VSIM | TWL4030 LDOs | | switchable supplies |
| A5 | SYS_nRESPWRON | | | power-on reset: don't touch |
| A6 / A8 / A9 / B6 / B7 / B8 / B9 | GPMC_WAIT0, nADV, nWE, nWP, nBE0, nOE, CLK | gpmc_* | | **live memory bus** |
| A7 | EXP_GPMC_nBE1 | gpmc_nbe1 / U3 | 61 | mainline DT hogs this low for Rev E+ USB: remove the hog for Rev D. Then free. |
| A10 | EXP_GPMC_nCS7 | gpmc_ncs7 / N8 | 58 | free |
| A11 | GPMC_nCS1 | gpmc_ncs1 / H3 | 52 | free |
| A25 | EXP_CAM_FLD | cam_fld / C23 | 98 | **free (no camera)** |
| A26 | EXP_VDIN_CAM_STROBE | cam_strobe / D26 | 126 | free |
| A27 | EXP_CAM_WEN | cam_wen / B23 | 167 | free |
| A28 | GPMC_nCS3 | gpmc_ncs3 / U8 | 54 | free |
| A29 / A30 | EXP_VDIN_XCLKB / XCLKA | cam_xclkb / cam_xclka | 111 / 96 | free (or clock outputs) |
| A31 / A32 / A33 | EXP_CAM_VS / HS / PCLK | cam_vs / cam_hs / cam_pclk | 95 / 94 / 97 | free |
| A34–A45 | EXP_CAM_D0 … D11 | cam_d0..11 | 99 … 110 | **free: 12 GPIOs** (or the parallel camera port) |
| A46 | GPMC_WAIT3 | gpmc_wait3 / J8 | 65 | free |
| A47 | EXP_McSPI1_CS3 | mcspi1_cs3 / AB2 | 177 | free on Rev D (on Rev E+ it's USB host data2) |
| A48–A51 | EXP_McBSP2_FSX / CLKX / DR / DX | mcbsp2_* | 116 / 117 / 118 / 119 | **in use: TWL4030 audio** |
| A52 | T2_MCBSP_CLKS | | | audio clock |
| A53 | CLK_REQ_OD | | | |
| B4 | GPMC_nCS6 | gpmc_ncs6 / P8 | 57 | free |
| B5 | SPARE6 | | | not connected |
| B10 | EXP_GPMC_nCS4 | gpmc_ncs4 / T8 | 55 | free |
| B11 | GPMC_nCS0 | | | **OneNAND chip select** |
| B25 / B26 | **I2C3_SCL / I2C3_SDA** | i2c3_scl / sda | 184 / 185 | **I2C3 bus: free (no daughter card).** Same pull-up note as I2C2. |
| B27–B33 | SYS_BOOT6 … SYS_BOOT0 | sys_boot* | 8 … 2 | boot straps, also LCD data in mainline DT: avoid |
| B34 / B35 | ETK_CLK / ETK_CTL | etk_clk / etk_ctl | 12 / 13 | also on the ETM/JTAG connector (sheet 11). Free if trace is unused. |
| B36–B42 | ETK_D0 … D6 | etk_d0..6 | 14 … 20 | same as B34/B35 |
| B43–B51 | EXP_ETK_D7 … D15 | etk_d7..15 | 21 … 29 | free on Rev D. The mainline DT uses 21/22 (USB PHY reset/VBUS) and 24–29 (USB host): remove them for Rev D. |
| B52 / B53 | T2_CLKEN2 / T2_CLKEN | TWL4030 | | PMIC: don't touch |
| A55–A60, B55–B60 | GND | | | |

## Summary: what to use for your C programs

| Need | Best choice | Pins |
|---|---|---|
| **I2C** | I2C2 (`/dev/i2c-2`) or I2C3 (`/dev/i2c-3`) | P7 A30/A31, or P18 B25/B26, plus VIO_1V8 and GND on P7 |
| **SPI** | McSPI2 with spidev, 2 chip selects | P7 A10 CLK, A11 MOSI, A12 MISO, A13 CS0, A15 CS1 |
| **Plain GPIO** | camera pads (12 data + 7 control), MMC2 pads (10), McBSP1 (6), McBSP3 (4), UART2 (4) | P18 A25–A45, P7 A16–A21, A26–A29, A36–A49 |
| **Analog in** | TWL4030 MADC ADCIN0, 2–7 via the IIO driver | P7 B8–B13, A33 |
| **UART** | UART2 (`ttyS1`) | P7 A36–A39 |

Every pad you use needs a `pinctrl-single` entry in a Rev D board `.dts` to select mode 4 (GPIO) or the function mode (I2C/SPI). See `04-linux-mainline/kernel-docs/pinctrl-single.yaml` and the `OMAP3_CORE1_IOPAD()` macro in `dt-bindings-pinctrl-omap.h`. The pad register offsets are in the TRM, chapter 7 (SCM, `CONTROL_PADCONF_*`).

## SW4 boot switch (sheet 9 + TRM Table 25-3/25-4 + Mistral errata)

SW4 positions 1–7 drive SYS_BOOT0–6 and position 8 drives BOOT_UART.

**Polarity: ON = 0.** This is inferred: with the opposite polarity, the errata's corrected NAND setting (`OFF ON OFF ON OFF OFF OFF OFF`) would decode to a reserved code. With ON = 0 it decodes to SYS_BOOT5 = 1, [4:0] = 0b10101, which is UART3 then NAND, a valid setting.

| Goal | sys_boot[5] / [4:0] | Boot order | SW4 1–8 |
|---|---|---|---|
| **SD card first, factory OneNAND as fallback (recommended)** | 1 / 0b10000 | USB → UART3 → **MMC1** → **OneNAND** | `ON ON ON ON OFF OFF OFF OFF` |
| SD card only, then UART3 | 0 / 0b11000 | **MMC1** → UART3 | `ON ON ON OFF OFF ON OFF OFF` |
| OneNAND first (likely the factory setting for a Samsung module) | 0 / 0b10110 | OneNAND → UART3 | `ON OFF OFF ON OFF ON OFF OFF` |

**Check before changing:**

1. Note the switch positions as they are now. Your board currently boots from OneNAND.
2. Decode them with ON = 0 using the table above. If they decode to a OneNAND-first entry, the polarity is confirmed.
3. Only then move to the SD setting.
4. Write down the original positions so you can always go back.
