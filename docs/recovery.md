# Recovery

## First: restore the stock image

If the keyboard still enumerates over USB (ZMK or bridge), the normal recovery
is:

```bash
./restore-stock.sh
```

This uses the `flash_mgmt` group over the CDC-ACM port and writes
`.work/rainy75-zmk/reverse/firmware/firmware_ota.bin` to flash offset 0. It does
not touch the RF/ADC calibration or Bluetooth MAC at `0xFE000`/`0xFF000`.

If the stock image is missing, run:

```bash
./stock/fetch-stock.sh --ansi
```

## Stuck in the bridge

The bridge is the small firmware used between stock and ZMK. It also enumerates
as `1d50:615e` and provides a serial port. `./flash.sh` detects it (mcumgr image
management does not answer) and finishes the write:

```bash
./flash.sh
```

Manual equivalent:

```bash
.work/rainy75-zmk/.venv/bin/python \
  .work/rainy75-zmk/reverse/tools/restore_original.py --yes \
  --port /dev/cu.usbmodemXXXX \
  .work/rainy75-zmk/build/combined.bin
```

## USB does not enumerate at all

If the bootloader is intact but the app is broken, a test image normally reverts
on its own (MCUboot + watchdog). If USB is completely gone, recovery needs the
hardware SWS path:

- Telink burning board / EVK wired to the keyboard's SWS, GND, and 3.3V pads;
- Telink BDT to write the stock image or a known-good combined image.

Follow the upstream guide, including the photos and pinout:

- <https://github.com/scholzri/rainy75-zmk/blob/main/docs/recovery.md>
- <https://github.com/scholzri/rainy75-zmk/blob/main/docs/hardware-probing.md>

The SWS pads are on the bottom of the PCB. Do not attempt this unless the USB
path is unavailable; a wrong image or wiring can make things worse.

## Do not flash the wrong layout/model image

- ANSI build: `--ansi`
- ISO build: `--iso`
- Stock restore image must match the model/layout (RGB Standard/Color/Pro vs
  Lite vs ISO).

If you are unsure, stop and ask before writing. The upstream issue tracker and
Discord are good places to confirm the variant.

## Known limitations after recovery

- No 2.4 GHz dongle support in ZMK; USB + Bluetooth LE only.
- Lite (non-RGB) has no LED chain; RGB features are no-ops.
- Bluetooth bonds may need to be removed and re-paired after a firmware change.
