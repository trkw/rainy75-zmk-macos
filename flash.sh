#!/usr/bin/env bash
# Flash the Rainy 75 from macOS.
#
# Auto-detects the current firmware:
#   stock (320f:5055)  -> OTA bridge + full ZMK install
#   bridge             -> finish the flash_mgmt stage
#   ZMK (1d50:615e)    -> mcumgr DFU update with the built image
#
#   ./flash.sh          # asks before writing
#   ./flash.sh --yes    # non-interactive
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(pwd)
# shellcheck source=upstream.lock
. ./upstream.lock
WORK="$ROOT/.work/rainy75-zmk"

YES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) YES=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--yes]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }
confirm() {
    [[ "$YES" -eq 1 ]] && return 0
    local answer
    read -rp "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

[[ -d "$WORK/.git" ]] || die "run ./setup.sh first"
[[ -f "$WORK/build/combined.bin" ]] || die "missing build/combined.bin — run ./setup.sh"
[[ -f "$WORK/build-bridge/bridge_ota.bin" ]] || die "missing bridge_ota.bin — run ./setup.sh"
[[ -f "$WORK/build/zephyr/zmk.signed.bin" ]] || die "missing zmk.signed.bin — run ./setup.sh"
[[ -f "$WORK/reverse/firmware/firmware_ota.bin" ]] || die \
    "stock restore image missing — run ./stock/fetch-stock.sh --ansi (or --iso) first"

# shellcheck disable=SC1091
. "$WORK/.venv/bin/activate"
export PYTHONPATH="$WORK/reverse/tools${PYTHONPATH:+:$PYTHONPATH}"

STOCK=$(python3 - <<'PY'
try:
    import hid
    print(1 if list(hid.enumerate(0x320F, 0x5055)) else 0)
except Exception:
    print(0)
PY
)

PORT=$(python3 - <<'PY'
try:
    import rainy75_rgb
    print(rainy75_rgb.find_port() or "")
except Exception:
    print("")
PY
)

if [[ "$STOCK" == "1" ]]; then
    echo "==> Stock Evision firmware detected (320f:5055)"
    confirm "Replace it with ZMK?" || { echo "Aborted."; exit 0; }
    bash "$WORK/install_zmk_macos.sh"
    exit 0
fi

if [[ -n "$PORT" ]]; then
    echo "==> Rainy 75 serial port detected: $PORT"

    # The full ZMK app answers mcumgr image management; the bridge does not.
    if python3 "$WORK/reverse/tools/rainy75_dfu.py" list >/dev/null 2>&1; then
        echo "==> ZMK firmware detected"
        confirm "Upload the built ZMK image and reset?" || { echo "Aborted."; exit 0; }
        python3 "$WORK/reverse/tools/rainy75_dfu.py" upload \
            "$WORK/build/zephyr/zmk.signed.bin" --test --reset
    else
        echo "==> Bridge firmware detected (flash_mgmt)"
        confirm "Write MCUboot + ZMK now?" || { echo "Aborted."; exit 0; }
        python3 "$WORK/reverse/tools/restore_original.py" --yes --port "$PORT" \
            "$WORK/build/combined.bin"
    fi

    echo
    echo "==> Done. Reconnect if needed; the keyboard should enumerate as 1d50:615e."
    exit 0
fi

cat >&2 <<'EOF'
No Rainy 75 found on USB.

Checklist:
  - USB-C cable connected (not just Bluetooth)
  - power switch under CapsLock is ON
  - wired mode: Fn + Tab until Esc lights up
  - close VIA / any app that may hold the HID interface
  - macOS: grant your terminal "Input Monitoring"
    (System Settings > Privacy & Security > Input Monitoring)
EOF
exit 1
