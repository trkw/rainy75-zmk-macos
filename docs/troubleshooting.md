# Troubleshooting

## `nix: command not found`

Install Nix from <https://nixos.org/download/> and make sure flakes are enabled:

```ini
# ~/.config/nix/nix.conf
experimental-features = nix-command flakes
```

## `xcode-select: error`

```bash
xcode-select --install
```

## CMake errors during configure

CMake 4.x trips an `if()` bug in Zephyr 4.1's `FindZephyr-sdk.cmake`. This repo
pins **CMake 3.31.6** in `.venv`; do not put a Nix/Homebrew CMake 4.x ahead of
it. `build_macos.sh` activates `.venv` before invoking `west build`.

If you have a stale build directory from a failed CMake 4 run:

```bash
rm -rf .work/rainy75-zmk/build .work/rainy75-zmk/build-mcuboot
./setup.sh --ansi
```

## `protoc: command not found` or `No module named 'google'`

`setup.sh` installs `protobuf` (Nix, for `protoc`) and the `protobuf` Python
package (venv, for nanopb). If you built by hand, install both.

## macOS cannot open the HID interface

Symptoms: `Keyboard not found`, `open failed`, or no OTA interface answers.

1. Connect USB, power on, `Fn + Tab` until Esc lights up.
2. Close VIA / any browser tab or app that may hold the HID interface.
3. Grant your terminal **Input Monitoring**:
   `System Settings > Privacy & Security > Input Monitoring`.
4. Replug the keyboard and retry:

```bash
cd .work/rainy75-zmk
. .venv/bin/activate
python3 reverse/tools/ota_flasher_macos.py --version
```

If it still fails, use a Linux VM for the first flash; subsequent ZMK updates
work from macOS.

## `Bridge serial port not found`

The OTA stage succeeded but macOS did not see the CDC-ACM port yet.

- Wait a few seconds and replug.
- Check `ls /dev/cu.usbmodem*`.
- Run stage 2 manually:

```bash
.work/rainy75-zmk/.venv/bin/python \
  .work/rainy75-zmk/reverse/tools/restore_original.py --yes \
  --port /dev/cu.usbmodemXXXX \
  .work/rainy75-zmk/build/combined.bin
```

## `Keyboard not found (VID=320F PID=5055)`

- The keyboard may be in Bluetooth or 2.4 GHz mode; use `Fn + Tab` to select
  wired mode.
- The power switch under CapsLock may be off.
- Use a data-capable USB-C cable, not a charge-only cable.
- On macOS, check `system_profiler SPUSBDataType` for `320F:5055`.

## `west update` fails

- Check network access to GitHub.
- Retry; `west update` is resumable.
- If a fetched tree is dirty, move it aside (the work tree is disposable):

```bash
rm -rf .work/rainy75-zmk
./setup.sh --ansi
```

Do not delete `.work/rainy75-zmk/reverse/firmware/firmware_ota.bin` without
copying it somewhere first.

## The build succeeds but the keyboard does not type

- Check that the correct layout was built (`--ansi` vs `--iso`).
- Open the serial console at 115200 baud and look for boot logs:

```bash
ls /dev/cu.usbmodem*
screen /dev/cu.usbmodemXXXX 115200
```

- Try `Fn + F4` to toggle USB/Bluetooth.
- If USB is dead, see [recovery](recovery.md).

## ZMK Studio cannot connect

- Use Chrome or Edge; Firefox lacks Web Serial/Web Bluetooth.
- Choose the **Studio** serial port (USB interface 3), not the console port.
- Press `Fn + Esc` to unlock.
- After switching USB ↔ Bluetooth, Studio locks again; press `Fn + Esc`.
