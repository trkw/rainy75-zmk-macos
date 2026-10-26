#!/usr/bin/env bash
# Install ZMK on a Rainy 75 Pro / Standard (Color) from macOS.
#
# Two stages, no Linux VM and no debugger:
#   1. OTA-flash the bridge firmware over the stock USB HID interface
#   2. Wait for the bridge CDC-ACM port and write MCUboot + ZMK via flash_mgmt
#
# Prereqs:
#   - stock firmware on the keyboard (VID 320f:5055), USB, wired mode (Fn+Tab)
#   - build/combined.bin and build-bridge/bridge_ota.bin
#     (bash build.sh -a --ansi)
#   - .venv with hidapi:  python -m pip install hidapi
#
# Usage:
#   bash install_zmk_macos.sh
#   bash install_zmk_macos.sh --bridge build-bridge/bridge_ota.bin --zmk build/combined.bin
set -euo pipefail
cd "$(dirname "$0")"

BRIDGE="build-bridge/bridge_ota.bin"
ZMK="build/combined.bin"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bridge) BRIDGE="$2"; shift 2 ;;
        --zmk)    ZMK="$2";    shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--bridge OTA] [--zmk COMBINED]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

for f in "$BRIDGE" "$ZMK"; do
    [[ -f "$f" ]] || {
        echo "Missing $f — build first:  bash build_macos.sh --ansi" >&2
        exit 1
    }
done

# shellcheck disable=SC1091
. .venv/bin/activate
python3 -c 'import hid' 2>/dev/null || {
    echo "hidapi is missing from .venv:  python3 -m pip install hidapi" >&2
    exit 1
}
if [[ ! -f reverse/firmware/firmware_ota.bin ]]; then
    echo "WARNING: no stock restore image at reverse/firmware/firmware_ota.bin." >&2
    echo "         Run ./stock/fetch-stock.sh --ansi from the setup repo first." >&2
fi

echo "==> Stage 1/2: OTA-flash the bridge (stock HID)"
python3 reverse/tools/ota_flasher_macos.py --force --yes "$BRIDGE"

echo
echo "==> Waiting for the bridge serial port..."
PORT=""
for _ in $(seq 1 40); do
    PORT=$(python3 - <<'PY'
import sys
sys.path.insert(0, "reverse/tools")
import rainy75_rgb
print(rainy75_rgb.find_port() or "")
PY
)
    [[ -n "$PORT" ]] && break
    sleep 1
done

if [[ -z "$PORT" ]]; then
    echo "Bridge serial port not found." >&2
    echo "Re-plug the keyboard and run stage 2 manually:" >&2
    echo "  python3 reverse/tools/restore_original.py --yes --port /dev/cu.usbmodemXXXX $ZMK" >&2
    exit 1
fi
echo "    $PORT"

echo
echo "==> Stage 2/2: write MCUboot + ZMK via flash_mgmt"
python3 reverse/tools/restore_original.py --yes --port "$PORT" "$ZMK"

echo
echo "==> Done. The keyboard should re-enumerate as ZMK (1d50:615e)."
echo "    Open https://zmk.studio in Chrome/Edge, connect USB, press Fn+Esc to unlock."
