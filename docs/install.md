# Install

This guide assumes an ANSI Rainy 75 Color/Standard (RGB) or Pro and a Mac with
Nix. ISO uses the same steps with `--iso`.

## Before you start

- Confirm the layout: ANSI (英字) or ISO. This repo was built for an ANSI unit.
- The stock firmware image is your only easy way back. Do not skip the stock-image step.
- Flashing can brick the keyboard. Read [recovery](recovery.md) first.
- Close VIA and any app that may hold the keyboard's HID interface.

## 1. Prerequisites

```bash
xcode-select --install        # if not already installed
# Nix: https://nixos.org/download/
nix --version
```

The first build downloads the Zephyr SDK, Zephyr, ZMK, MCUboot, and the Telink
HAL; allow several GB and 20-60 minutes.

## 2. Clone and build

```bash
git clone https://github.com/trkw/rainy75-zmk-macos.git
cd rainy75-zmk-macos

./setup.sh --ansi
```

`setup.sh`:

1. clones `scholzri/rainy75-zmk` at the commit in `upstream.lock` into `.work/rainy75-zmk`;
2. copies the macOS scripts into the work tree;
3. downloads Zephyr SDK 0.17.0 if needed;
4. creates `.venv`, installs west/CMake 3.31.6/protobuf/hidapi/dnfile;
5. runs `west init`/`west update`/`west zephyr-export`;
6. builds MCUboot, the ZMK app (ANSI), the combined image, and the OTA bridge.

Expected outputs:

```
.work/rainy75-zmk/build/combined.bin
.work/rainy75-zmk/build/zephyr/zmk.signed.bin
.work/rainy75-zmk/build-bridge/bridge_ota.bin
```

## 3. Save the stock restore image

```bash
./stock/fetch-stock.sh --ansi
```

This downloads the official Wobkey RGB updater and extracts
`.work/rainy75-zmk/reverse/firmware/firmware_ota.bin`. The updater and image are
proprietary and stay under `.work/` (gitignored). It needs the `.venv` created by
`setup.sh`.

Copy the extracted image somewhere outside the repository, for example:

```bash
cp .work/rainy75-zmk/reverse/firmware/firmware_ota.bin ~/Documents/rainy75-stock.bin
```

ISO:

```bash
./stock/fetch-stock.sh --iso
```

## 4. Flash

Keyboard:

1. power switch under CapsLock **on**;
2. USB-C connected (not Bluetooth);
3. `Fn + Tab` until **Esc lights up** (wired mode).

Then:

```bash
./flash.sh
```

It detects the current firmware:

- stock `320f:5055` → OTA bridge, then MCUboot + ZMK;
- bridge → finishes the `flash_mgmt` write;
- ZMK `1d50:615e` → mcumgr DFU update with `zmk.signed.bin`.

The first install takes about 1–2 minutes. When it succeeds, the keyboard
re-enumerates as `1d50:615e` and types immediately.

Non-interactive:

```bash
./flash.sh --yes
```

## 5. Configure

Open <https://zmk.studio> in Chrome or Edge.

- USB: two serial ports appear; choose the **Studio** port (USB interface 3).
- Press `Fn + Esc` to unlock editing.
- Over Bluetooth, use Connect → Bluetooth and `Fn + Esc`.

Fn-layer essentials:

| Combo | Action |
|---|---|
| `Fn + Esc` | ZMK Studio unlock |
| `Fn + F1/F2/F3` | Bluetooth profile 1/2/3 |
| `Fn + F4` | USB ↔ Bluetooth output |
| `Fn + Del` | clear the active Bluetooth pairing |
| `Fn + Backspace` | RGB on/off |
| `Fn + Enter` | next RGB effect |
| `Fn + ↑/↓` | RGB brightness |
| `Fn + ←/→` | RGB speed |

## 6. Update and restore

After a keymap change:

```bash
./setup.sh --ansi
./flash.sh
```

Most remapping can be done live in ZMK Studio, without rebuilding.

Back to stock:

```bash
./restore-stock.sh
```

It writes the saved stock image and resets to `320f:5055`.
