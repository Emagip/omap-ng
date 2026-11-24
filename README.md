# omap-ng

Work area for running mainline Linux on the TI TMDSEVM3530 (OMAP35x EVM).

- `FEASIBILITY.md`: the feasibility study. Start here.
- `GPIO-LED-TEST.md`: plan for the first GPIO test (on-board LED, then an external LED on P7 A18 / gpio_158 via a transistor).
- `doc/`: collected reference documentation (datasheets, TRM, errata, mainline/legacy board sources). Index in `doc/README.md`.
- `src/` (git-ignored): sparse reference checkouts of mainline Linux and U-Boot.

Locally, this repo sits in a `modern-linux/` folder next to the original 2008–2009 TI SDKs (OMAP35x PSP 02.01.01.08, SDK 1.0.2). Those SDKs aren't part of the repo.

## License

- **Code** (sources, scripts, device trees, patches): [GPL-2.0-only](LICENSES/GPL-2.0-only.txt)
- **Documentation** (`*.md`): [CC BY-SA 4.0](LICENSES/CC-BY-SA-4.0.txt)
- **Third-party material** (kernel/U-Boot excerpts, vendor PDFs in `doc/`) keeps its own license and copyright.

See [LICENSE](LICENSE) for details.
