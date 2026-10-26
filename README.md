# rainy75-zmk-macos

Native **macOS** build and flashing setup for the Wobkey Rainy 75 ZMK port
([scholzri/rainy75-zmk](https://github.com/scholzri/rainy75-zmk)).

No Linux VM, no Docker, no hardware debugger for the normal path. The upstream
source is cloned at a pinned commit, built with Nix-provided GNU tools and the
Zephyr SDK, then flashed over USB from macOS.

## Status

| Part | State |
|---|---|
| macOS native build (ANSI) | ✅ verified on macOS 27 / Apple Silicon |
| macOS stock-OTA bridge flash (hidapi) | ✅ verified on hardware (Rainy 75 Color ANSI, 2026-10) |
| ZMK DFU updates from macOS | ✅ upstream tool supports `/dev/cu.usbmodem*` |
| Restore to stock from macOS | 🧪 implemented, not yet hardware-tested |
| ISO build | ⚙️ supported by `--iso`, untested here |
| Rainy 75 Color / Standard (RGB) | ✅ verified on an ANSI Color unit |
| Rainy 75 Lite (non-RGB) | ⚠️ boots, but RGB/LED indicators do nothing |

Build and first flash are verified on an ANSI Rainy 75 Color (Standard RGB) with
macOS 27 / Apple Silicon. The restore-to-stock path is implemented but not yet
exercised; keep the stock image and read [recovery](docs/recovery.md).

## What it does

1. `setup.sh` clones the upstream repo at the commit in `upstream.lock` into
   `.work/rainy75-zmk`, copies the macOS scripts in, and builds:
   - MCUboot + ZMK app + combined image
   - the monolithic OTA bridge used for the stock → ZMK transition
2. `stock/fetch-stock.sh` downloads the official Wobkey updater and extracts the
   stock restore image **locally** (proprietary; never committed).
3. `flash.sh` detects the current firmware and either installs ZMK, finishes a
   bridge install, or updates an existing ZMK image.
4. `restore-stock.sh` writes the saved stock image back over USB.

## Requirements

- macOS on Apple Silicon (arm64 tested; x86_64 build path included but untested)
- Xcode Command Line Tools: `xcode-select --install`
- [Nix](https://nixos.org/download/) with flakes enabled
- USB-C cable, ~10 GB free disk, 8 GB RAM
- Rainy 75 in **wired mode** (`Fn + Tab`, Esc lights up) and the power switch
  under CapsLock **on**

The build uses:

- Zephyr SDK **0.17.0** (macOS arm64/x86_64)
- CMake **3.31.6** via pip (CMake 4.x trips a Zephyr 4.1 `if()` bug)
- GNU bash/coreutils, ninja, dtc, protoc via Nix
- Python 3.12, west, `hidapi`, `dnfile`

## Quick start (ANSI)

```bash
git clone https://github.com/trkw/rainy75-zmk-macos.git
cd rainy75-zmk-macos

# 1. Clone upstream + build (first run downloads several GB)
./setup.sh --ansi

# 2. Save the stock restore image (downloads the vendor updater locally)
./stock/fetch-stock.sh --ansi

# 3. Connect USB, power on, Fn+Tab to wired mode, then:
./flash.sh
```

For ISO, use `--iso` in both commands.

If the keyboard already runs ZMK, `./flash.sh` detects it and performs a normal
mcumgr DFU update with `build/zephyr/zmk.signed.bin`.

To go back:

```bash
./restore-stock.sh
```

## Web launcher

An experimental web configurator for the same ZMK firmware is available at
**<https://trkw.github.io/rainy75-launcher/>** (Chrome/Edge, USB). It is a
separate project: <https://github.com/trkw/rainy75-launcher>.

## Documentation

- [Install](docs/install.md) — step-by-step build and first flash
- [Keymap](keymap/README.md) — source keymap, Mac keys, Studio caveat
- [Recovery](docs/recovery.md) — stock restore, bridge recovery, SWS path
- [Troubleshooting](docs/troubleshooting.md) — Nix, CMake, HID permissions, ports

## macOS permissions

The stock OTA interface is a vendor-defined HID device. If `flash.sh` cannot
find it, grant your terminal **Input Monitoring** permission:

`System Settings > Privacy & Security > Input Monitoring`

Also close VIA and any other app that may hold the HID interface. If macOS still
refuses, the fallback is a Linux VM (the upstream project's documented path).

## Layouts and models

- **ANSI (US/英字)** — default, `--ansi`.
- **ISO (DE/UK)** — `--iso`.
- **Color / Standard (RGB)** — same PCB as Pro; expected to work. This repo was
  built for an ANSI Color unit.
- **Pro** — upstream target.
- **Lite (non-RGB)** — the firmware boots, but the LED chain is absent, so RGB
  and LED indicators do nothing. Use the Lite stock updater if you need to
  restore; `stock/fetch-stock.sh --url ...` accepts a custom URL.

## Known limitations

- **No 2.4 GHz dongle.** ZMK runs over USB and Bluetooth LE only.
- **Not Vial.** Configuration is ZMK Studio (Chrome/Edge) or the keymap in
  `zmk/boards/rainy75/rainy75.keymap`.
- **No prebuilt firmware.** Builds are local; the stock image is vendor
  proprietary and is not redistributed.
- **Unofficial.** No warranty. Flashing can brick the keyboard; recovery may
  need a Telink burning board on the SWS pads.

## Keymap editing

Two workflows, and they do not mix well:

- **ZMK Studio** — quick live remapping, no rebuild. Open
  [zmk.studio](https://zmk.studio), connect USB, press `Fn + Esc`, edit and save.
  Studio stores the changes **on the keyboard**, and it currently has no
  export/import.
- **Source keymap (recommended for a reproducible setup)** — edit
  [`keymap/rainy75.keymap`](keymap/rainy75.keymap), then:

  ```bash
  ./setup.sh --ansi     # or --iso
  ./flash.sh
  ```

  `setup.sh` copies `keymap/rainy75.keymap` over the upstream default before
  building. If you have already used Studio, press **Restore Stock Settings** in
  Studio after flashing; otherwise Studio's saved overrides mask the newly
  compiled keymap.

See [`keymap/README.md`](keymap/README.md) for Mac-specific notes, common ZMK
behaviors, and examples.

## Contributing

Hardware test reports are especially useful while the flash path is new. Please
include:

- Rainy 75 variant (Pro / Color / Standard / Lite) and layout (ANSI / ISO)
- macOS version and Mac architecture
- whether `./setup.sh`, `./stock/fetch-stock.sh`, and `./flash.sh` succeeded
- the first error line if something failed

Issues and pull requests are welcome. Do not attach the vendor updater, the
extracted stock image, or a `--blob` build; those are proprietary.

## Repository layout

```
setup.sh                 # clone upstream at the pinned commit + build
flash.sh                 # stock -> ZMK / bridge finish / ZMK update
restore-stock.sh         # ZMK -> stock
upstream.lock            # pinned upstream repo + commit
stock/fetch-stock.sh     # download vendor updater, extract restore image
keymap/
  rainy75.keymap         # source of truth, copied over the upstream default
  README.md
scripts/
  build_macos.sh         # Nix + Zephyr SDK build
  install_zmk_macos.sh   # OTA bridge + flash_mgmt two-stage install
  restore_stock_macos.sh # flash_mgmt restore
  ota_flasher_macos.py   # hidapi transport for the stock OTA protocol
docs/
  install.md
  recovery.md
  troubleshooting.md
```

Everything under `.work/` is local and gitignored.

## Upstream and licensing

This is an independent companion project, **not a fork** and not affiliated with
Wobkey, Telink, Evision, or the upstream author.

- Upstream firmware and reverse engineering:
  [scholzri/rainy75-zmk](https://github.com/scholzri/rainy75-zmk), Apache-2.0.
- The stock firmware and the vendor updater are proprietary (Wobkey / Evision /
  Telink); this repository does not contain them. `stock/fetch-stock.sh`
  downloads the updater from Wobkey at your request and extracts the image
  locally.
- The default ZMK build uses the open Bluetooth LE controller; no proprietary
  Telink BLE blob is included.
- This repository's scripts are Apache-2.0; see [LICENSE](LICENSE) and
  [NOTICE](NOTICE).

## Disclaimer

Flashing custom firmware is at your own risk. Keep the stock image, read
[docs/recovery.md](docs/recovery.md), and do not flash a layout/model image that
does not match your keyboard.
