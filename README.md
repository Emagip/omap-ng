# modern-linux

Work area for running mainline Linux on the TI TMDSEVM3530 (OMAP35x EVM).

- `FEASIBILITY.md`: the feasibility study. Start here.
- `GPIO-LED-TEST.md`: plan for the first GPIO test (on-board LED, then an external LED on P7 A18 / gpio_158 via a transistor).
- `doc/`: collected reference documentation (datasheets, TRM, errata, mainline/legacy board sources). Index in `doc/README.md`.
- `src/` (git-ignored): sparse reference checkouts of mainline Linux and U-Boot.

The surrounding folder (`../`) holds the original 2008–2009 TI SDKs, left untouched.
