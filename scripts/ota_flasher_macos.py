#!/usr/bin/env python3
"""Flash the Rainy 75 stock OTA image from macOS via hidapi.

`ota_flasher.py` talks to Linux hidraw. This file reuses its protocol code and
only replaces the transport with hidapi (IOKit on macOS). Use it for the first
install, when the keyboard still runs the stock Evision firmware:

    python3 reverse/tools/ota_flasher_macos.py --version
    python3 reverse/tools/ota_flasher_macos.py --force --yes build-bridge/bridge_ota.bin

After the bridge has booted, write the full ZMK image with
`restore_original.py` (its SMP serial transport already works on macOS), or use
`install_zmk_macos.sh` which does both stages.

The stock OTA protocol is write-only and the bridge is normally installed over
USB HID. If macOS refuses to open the vendor interface, grant your terminal
"Input Monitoring" in System Settings > Privacy & Security, or use a Linux VM.
"""
import argparse
import sys
import time

try:
    import hid
except ImportError:
    sys.exit("Missing hidapi. Install it with:  pip install hidapi")

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import ota_flasher as ota  # noqa: E402


class HidDevice:
    """The small surface ota_flasher's protocol functions need."""

    def __init__(self, info):
        self.info = info
        self.dev = hid.device()
        self.dev.open_path(info["path"])
        self.dev.set_nonblocking(0)

    def send_packet(self, data):
        packet = bytes([ota.REPORT_ID]) + data + bytes([0xFF] * (63 - len(data)))
        if self.dev.write(packet) < 0:
            raise OSError("hidapi write failed")

    def read_response(self, timeout_ms=2000):
        data = self.dev.read(64, timeout_ms)
        if not data:
            return None
        # hidapi normally includes the report ID. Some macOS builds return the
        # 63 data bytes only; put the report ID back in that case.
        if len(data) == 63 and data[0] != ota.REPORT_ID:
            data = [ota.REPORT_ID] + data
        return bytes(data)

    def close(self):
        self.dev.close()


# ota_flasher's protocol helpers call module-level send_packet/read_response.
# Route them to the hidapi device object.
ota.send_packet = lambda dev, data: dev.send_packet(data)
ota.read_response = lambda dev, timeout_ms=2000: dev.read_response(timeout_ms)


def _describe(d):
    return (f"interface={d.get('interface_number')} "
            f"usage_page=0x{d.get('usage_page', 0):04X} "
            f"usage=0x{d.get('usage', 0):04X} "
            f"product={d.get('product_string')!r}")


def open_device(verbose=True):
    infos = list(hid.enumerate(ota.VID, ota.PID))
    if not infos:
        sys.exit(f"Keyboard not found (VID={ota.VID:04X} PID={ota.PID:04X}). "
                 "Connect it via USB and switch to wired mode (Fn+Tab).")
    if verbose:
        print(f"Found {len(infos)} HID interface(s):")
        for d in infos:
            print("  " + _describe(d))

    preferred = [d for d in infos
                 if d.get("usage_page") == ota.USAGE_PAGE
                 or d.get("interface_number") == ota.INTERFACE]
    ordered = preferred + [d for d in infos if d not in preferred]

    for d in ordered:
        try:
            dev = HidDevice(d)
        except OSError as e:
            if verbose:
                print(f"  skip {_describe(d)}: {e}")
            continue
        try:
            ver, crc = ota.get_fw_version(dev)
            if ver is not None:
                if verbose:
                    print(f"  OTA interface: {_describe(d)}")
                    print(f"  Firmware version: 0x{ver:08X}  CRC: 0x{crc:08X}")
                return dev
        except Exception as e:
            if verbose:
                print(f"  probe {_describe(d)} failed: {e}")
        dev.close()

    sys.exit(
        "No OTA interface answered. Make sure the keyboard is in wired mode "
        "(Fn+Tab). On macOS, also grant your terminal 'Input Monitoring' in "
        "System Settings > Privacy & Security, or use a Linux VM."
    )


def main():
    ap = argparse.ArgumentParser(
        description="Flash Rainy 75 stock OTA firmware from macOS (hidapi)")
    ap.add_argument("firmware", nargs="?", help="firmware .bin to flash")
    ap.add_argument("--version", action="store_true",
                    help="query the keyboard's firmware version")
    ap.add_argument("--info", action="store_true",
                    help="show firmware file info without a device")
    ap.add_argument("--dry-run", action="store_true",
                    help="simulate without sending")
    ap.add_argument("--force", action="store_true",
                    help="skip TLNK/CRC safety checks")
    ap.add_argument("-y", "--yes", action="store_true",
                    help="skip the confirmation prompt")
    args = ap.parse_args()

    if args.version:
        dev = open_device()
        try:
            ver, crc = ota.get_fw_version(dev)
            if ver is None:
                sys.exit("No firmware version response")
            print(f"Firmware version: 0x{ver:08X}")
            print(f"Firmware CRC: 0x{crc:08X}")
        finally:
            dev.close()
        return

    if not args.firmware:
        ap.print_help()
        return

    with open(args.firmware, "rb") as f:
        fw_data = f.read()

    info = ota.parse_telink_ota_firmware(fw_data)
    print(f"Firmware: {args.firmware} ({info['total_size']} bytes, "
          f"OTA 0x{info['ota_size']:X})")
    if args.info:
        print(f"  TLNK header: {'Yes' if info['has_tlnk'] else 'No'}")
        print(f"  FW version: 0x{info.get('fw_version', 0):04X}")
        print(f"  CRC32: 0x{info.get('crc32', 0):08X} "
              f"({'valid' if info.get('crc_valid') else 'invalid'})")
        return

    if not info["has_tlnk"] and not args.force:
        sys.exit("ERROR: no TLNK header; this is not a Telink OTA image "
                 "(use --force to override).")
    if not info.get("crc_valid") and not args.force:
        sys.exit("ERROR: firmware CRC is invalid (use --force to override).")

    if not args.dry_run and not args.yes:
        print("\n" + "=" * 60)
        print("WARNING: you are about to flash firmware over USB HID.")
        print("Make sure you have the stock firmware image saved.")
        print("=" * 60)
        if input("\nType 'YES' to proceed: ") != "YES":
            print("Aborted.")
            return

    if args.dry_run:
        print("\n[DRY RUN - no data will be sent]")
        ota.flash_firmware(None, fw_data, dry_run=True)
        return

    dev = open_device()
    try:
        if not ota.flash_firmware(dev, fw_data):
            sys.exit(1)
    finally:
        dev.close()


if __name__ == "__main__":
    main()
