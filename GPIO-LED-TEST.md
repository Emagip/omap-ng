# First GPIO test: blink an LED

Plan only. Nothing here has been built or run yet. It assumes the mainline kernel and U-Boot are booting from SD (see `FEASIBILITY.md`).

## Step 0: the on-board LED, no wiring

The mainline DT already declares the EVM's own LED, driven by the TWL4030 `LEDB` output, as `omap3evm::ledb`. The 2009 board file notes that it's on the **underside** of the board.

```sh
ls /sys/class/leds/
echo 0 > /sys/class/leds/omap3evm::ledb/brightness    # off
echo 1 > /sys/class/leds/omap3evm::ledb/brightness    # on
echo heartbeat > /sys/class/leds/omap3evm::ledb/trigger
```

This goes through the LED subsystem, not the GPIO chardev. It's still a good first sign that Linux, the TWL4030 and the I2C1 bus all work.

## Step 1: an external LED on a real OMAP GPIO

### Pin choice: `gpio_158` = McBSP1_DX pad, connector **P7 pin A18**

- It's wired **directly** to the connector: its net has no `EXP_` prefix, so it doesn't pass through any of the Rev E+ bus switches. This holds for every board revision.
- It isn't used by anything in the mainline DT (EVM audio uses McBSP2).
- In Linux it is bank `gpio5`, line **30** (158 = 4 × 32 + 30). The bank shows up as one of `/dev/gpiochip0…5`; check with `gpioinfo`. The TWL4030 GPIOs appear as an extra gpiochip.
- Nearby on P7: **A3/A4 = VIO_1V8** and **A55–A60 = GND**. Measure them before use.

### Hardware: drive the LED through a transistor

The pad is **1.8 V** and only good for a few mA. A typical LED needs about 2 V forward voltage, so it barely lights, if at all, when driven directly. Use an NPN transistor as a low-side switch, with the LED powered from a 3.3 V or 5 V supply that **shares ground** with the EVM:

```
  +3.3V (or +5V) ──[ R_led ]──►|── LED ──┐
                                          C
  P7 A18 (gpio_158) ──[ 2.2k ]──────── B  NPN (2N3904 / BC547 / BC337)
                            │             E
                         [100k]           │
                            │             │
  P7 GND ───────────────────┴─────────────┴──── supply GND
```

| Part | Value |
|---|---|
| **R_led** | (Vsupply − V_LED) / 10 mA: about **150 Ω at 3.3 V**, about **330 Ω at 5 V** (red LED) |
| **Base resistor** | 2.2 kΩ: (1.8 − 0.7) / 2.2 k ≈ 0.5 mA, enough to saturate the transistor for a 10 mA LED, and an easy load for the pad |
| **100 kΩ base pull-down** | keeps the LED off while the pad is still unconfigured during boot |

**Never** connect anything above 1.8 V to the GPIO pin itself.

### Kernel: mux the pad as GPIO

Pads have to be muxed in the device tree. Add this to the future Rev D board `.dts`, the one that includes `omap3-evm.dts`:

```dts
&omap3_pmx_core {
	led_test_pins: led-test-pins {
		pinctrl-single,pins = <
			OMAP3_CORE1_IOPAD(0x2190, PIN_OUTPUT | MUX_MODE4)	/* mcbsp1_dx.gpio_158, P7 A18 */
		>;
	};
};

&gpio5 {
	pinctrl-names = "default";
	pinctrl-0 = <&led_test_pins>;
};
```

How the address was derived: U-Boot's `CONTROL_PADCONF_MCBSP1_DX = 0x0190`, and `OMAP3_CORE1_IOPAD` takes `0x2000 + offset`. This was cross-checked against `mcspi1_cs3`, which is 0x01D4 in U-Boot and 0x21d4 in the EVM DT.

Kernel config: GPIO chardev support (`CONFIG_GPIO_CDEV`, on by default).

### User space, command line (libgpiod v2 tools)

```sh
gpiodetect                         # list the chips
gpioinfo | grep -n "line  30"      # find gpio5 line 30 on the right chip
gpioset -c gpiochip4 30=1          # LED on (chip name: whatever gpiodetect says is gpio5)
gpioset -c gpiochip4 30=0          # LED off
```

### User space, C (libgpiod v2 API)

```c
// blink.c: cross-compile with
//   arm-linux-gnueabihf-gcc -O2 blink.c -o blink -lgpiod
// (needs the libgpiod headers/library for armhf in the sysroot)
#include <gpiod.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	const char *chip_path = argc > 1 ? argv[1] : "/dev/gpiochip4"; /* gpio5 bank: check gpiodetect */
	unsigned int offset = 30;                                      /* gpio_158 */

	struct gpiod_chip *chip = gpiod_chip_open(chip_path);
	if (!chip) { perror("gpiod_chip_open"); return 1; }

	struct gpiod_line_settings *ls = gpiod_line_settings_new();
	gpiod_line_settings_set_direction(ls, GPIOD_LINE_DIRECTION_OUTPUT);
	gpiod_line_settings_set_output_value(ls, GPIOD_LINE_VALUE_INACTIVE);

	struct gpiod_line_config *lc = gpiod_line_config_new();
	gpiod_line_config_add_line_settings(lc, &offset, 1, ls);

	struct gpiod_request_config *rc = gpiod_request_config_new();
	gpiod_request_config_set_consumer(rc, "led-blink");

	struct gpiod_line_request *req = gpiod_chip_request_lines(chip, rc, lc);
	if (!req) { perror("gpiod_chip_request_lines"); return 1; }

	for (int i = 0; i < 20; i++) {
		gpiod_line_request_set_value(req, offset,
			(i & 1) ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE);
		usleep(250000);
	}

	gpiod_line_request_release(req);
	gpiod_request_config_free(rc);
	gpiod_line_config_free(lc);
	gpiod_line_settings_free(ls);
	gpiod_chip_close(chip);
	return 0;
}
```

The kernel's own chardev examples, which use no library, are in `doc/04-linux-mainline/kernel-docs/gpio-tools-examples/`. `gpio-hammer.c` is essentially this program.

## Other easy pins for later

These are wired directly on every revision (no `EXP_`), and are all on P7:

| Pin | Pad | GPIO |
|---|---|---|
| A16 | MCBSP1_CLKR | gpio_156 |
| A19 | MCBSP1_DR | gpio_159 |
| A20 | MCBSP1_FSX | gpio_161 |
| A21 | MCBSP1_CLKX | gpio_162 |
| A36 | UART2_CTS | gpio_144 |
| A37 | UART2_RTS | gpio_145 |

See `doc/EXPANSION-CONNECTORS.md` for the rest.
