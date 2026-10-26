#!/usr/bin/env bash
# Restore the stock Evision firmware on a Rainy 75 running ZMK, from macOS.
#
# Uses the custom flash_mgmt mcumgr group (no lsusb / udev needed). The stock
# image is the one extracted with reverse/tools/extract_stock_firmware.py.
#
# Usage:
#   bash restore_stock_macos.sh
#   bash restore_stock_macos.sh path/to/firmware_ota.bin
set -euo pipefail
cd "$(dirname "$0")"

FIRMWARE="${1:-reverse/firmware/firmware_ota.bin}"
[[ -f "$FIRMWARE" ]] || {
    echo "Stock image not found: $FIRMWARE" >&2
    echo "Extract it first with reverse/tools/extract_stock_firmware.py." >&2
    exit 1
}

# shellcheck disable=SC1091
. .venv/bin/activate

PORT=$(python3 - <<'PY'
import sys
sys.path.insert(0, "reverse/tools")
import rainy75_rgb
print(rainy75_rgb.find_port() or "")
PY
)
if [[ -z "$PORT" ]]; then
    echo "No Rainy 75 serial port found. Connect USB and try again." >&2
    exit 1
fi

echo "==> Restoring stock firmware"
echo "    image: $FIRMWARE"
echo "    port:  $PORT"
python3 reverse/tools/restore_original.py --yes --port "$PORT" "$FIRMWARE"

echo
echo "==> Done. The keyboard should re-enumerate as stock (320f:5055)."
