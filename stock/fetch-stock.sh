#!/usr/bin/env bash
# Download the official Wobkey RGB updater and extract the stock restore image.
#
#   ./stock/fetch-stock.sh                 # ANSI / RGB Standard (Color) / Pro
#   ./stock/fetch-stock.sh --iso           # ISO
#   ./stock/fetch-stock.sh --local FILE    # use an updater you already downloaded
#   ./stock/fetch-stock.sh --force         # re-extract
#
# The .exe and the extracted image are proprietary and are written under
# .work/ (gitignored). Nothing is committed.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
# shellcheck source=upstream.lock
. ./upstream.lock
WORK="$ROOT/.work/rainy75-zmk"

LAYOUT="--ansi"
URL=""
LOCAL=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ansi|--iso) LAYOUT="$1"; shift ;;
        --url)   URL="$2"; shift 2 ;;
        --local) LOCAL="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--ansi|--iso] [--url URL] [--local FILE] [--force]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }

[[ -d "$WORK/.git" ]] || die "run ./setup.sh first (it creates .work/rainy75-zmk)"
[[ -x "$WORK/.venv/bin/python" ]] || die "run ./setup.sh first (it creates .venv)"

if [[ "$LAYOUT" == "--iso" ]]; then
    DEFAULT_URL="https://drivers.sfo3.digitaloceanspaces.com/Rainy75%20ISO%20firmware.exe"
    KNOWN_SHA=""
else
    DEFAULT_URL="https://drive.wobkey.com/f/OGBtJ/Rainy75-CSE057-V0116-20260606.exe"
    # Tested on a Rainy 75 Color/Standard (ANSI, RGB) in 2026-10.
    KNOWN_SHA="93c93519ac07b7589be192ad60121fff8a3d9007623df03262ad20f5b0e67ca0"
fi
URL="${URL:-$DEFAULT_URL}"
OUT="$WORK/reverse/firmware/firmware_ota.bin"

if [[ -f "$OUT" && "$FORCE" -eq 0 ]]; then
    echo "Stock restore image already exists:"
    echo "  $OUT"
    shasum -a 256 "$OUT"
    echo "Use --force to download/extract again."
    exit 0
fi

if [[ -z "$LOCAL" ]]; then
    mkdir -p "$WORK/reverse/reference"
    NAME=$(basename "${URL%%\?*}" | sed 's/%20/_/g')
    LOCAL="$WORK/reverse/reference/$NAME"
    echo "==> Downloading official updater"
    echo "    $URL"
    curl -fL --retry 3 -o "$LOCAL" "$URL"
fi

[[ -f "$LOCAL" ]] || die "updater not found: $LOCAL"
mkdir -p "$(dirname "$OUT")"
echo "==> Extracting the stock OTA image"
# shellcheck disable=SC1091
. "$WORK/.venv/bin/activate"
python -m pip install -q dnfile
python "$WORK/reverse/tools/extract_stock_firmware.py" "$LOCAL" -o "$OUT"

SHA=$(shasum -a 256 "$OUT" | awk '{print $1}')
echo
echo "Stock restore image: $OUT"
echo "sha256: $SHA"
if [[ -n "$KNOWN_SHA" && "$SHA" != "$KNOWN_SHA" ]]; then
    echo
    echo "WARNING: this is not the image tested by this repository." >&2
    echo "         Tested sha256: $KNOWN_SHA" >&2
    echo "         The vendor may have published a newer firmware; the" >&2
    echo "         extractor still produced a valid Telink image." >&2
fi
echo
echo "Back this file up outside the repository before flashing."
