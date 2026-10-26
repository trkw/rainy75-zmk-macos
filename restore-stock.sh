#!/usr/bin/env bash
# Restore the stock Evision firmware on a Rainy 75 running ZMK, from macOS.
#
#   ./restore-stock.sh          # asks before writing
#   ./restore-stock.sh --yes    # non-interactive
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

[[ -d "$WORK/.git" ]] || die "run ./setup.sh first"
[[ -f "$WORK/reverse/firmware/firmware_ota.bin" ]] || die \
    "stock image missing — run ./stock/fetch-stock.sh --ansi (or --iso) first"

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
if [[ "$STOCK" == "1" ]]; then
    echo "The keyboard is already running stock firmware (320f:5055)."
    exit 0
fi

PORT=$(python3 - <<'PY'
try:
    import rainy75_rgb
    print(rainy75_rgb.find_port() or "")
except Exception:
    print("")
PY
)
[[ -n "$PORT" ]] || die "no Rainy 75 serial port found (USB + wired mode?)"

echo "==> Stock restore"
echo "    image: $WORK/reverse/firmware/firmware_ota.bin"
echo "    port:  $PORT"
if [[ "$YES" -eq 0 ]]; then
    read -rp "Erase ZMK and write the stock image? [y/N] " a
    [[ "$a" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

bash "$WORK/restore_stock_macos.sh"
