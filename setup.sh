#!/usr/bin/env bash
# Set up a native macOS build tree for the Rainy 75 ZMK firmware.
#
#   ./setup.sh                 # ANSI layout (default)
#   ./setup.sh --iso           # ISO layout
#   ./setup.sh --ansi --no-build
#
# The upstream source is cloned into .work/rainy75-zmk at the commit pinned in
# upstream.lock. The macOS scripts are copied into that tree, then the firmware
# is built with Nix-provided GNU tools + Zephyr SDK 0.17.0.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(pwd)
# shellcheck source=upstream.lock
. ./upstream.lock

LAYOUT="--ansi"
NO_BUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ansi|--iso) LAYOUT="$1"; shift ;;
        --no-build)   NO_BUILD=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--ansi|--iso] [--no-build]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "this setup is macOS-only"
case "$(uname -m)" in
    arm64|x86_64) ;;
    *) die "unsupported Mac architecture: $(uname -m)" ;;
esac
command -v nix >/dev/null 2>&1 || die "Nix is required: https://nixos.org/download/"
xcode-select -p >/dev/null 2>&1 || die "install Xcode Command Line Tools first: xcode-select --install"

WORK="$ROOT/.work/rainy75-zmk"
mkdir -p "$ROOT/.work"

echo "==> Upstream: $UPSTREAM_REPO"
echo "    commit:   $UPSTREAM_COMMIT"

if [[ -d "$WORK/.git" ]]; then
    CURRENT=$(git -C "$WORK" rev-parse HEAD)
    if [[ "$CURRENT" != "$UPSTREAM_COMMIT" ]]; then
        echo "==> Moving work tree from $CURRENT to $UPSTREAM_COMMIT"
        git -C "$WORK" fetch origin
        git -C "$WORK" checkout "$UPSTREAM_COMMIT"
    fi
else
    echo "==> Cloning upstream into .work/rainy75-zmk"
    git clone "$UPSTREAM_REPO" "$WORK"
    git -C "$WORK" checkout "$UPSTREAM_COMMIT"
fi

echo "==> Installing macOS scripts into the work tree"
install -m 755 "$ROOT/scripts/build_macos.sh"        "$WORK/build_macos.sh"
install -m 755 "$ROOT/scripts/install_zmk_macos.sh"  "$WORK/install_zmk_macos.sh"
install -m 755 "$ROOT/scripts/restore_stock_macos.sh" "$WORK/restore_stock_macos.sh"
install -m 755 "$ROOT/scripts/ota_flasher_macos.py"  "$WORK/reverse/tools/ota_flasher_macos.py"

# The repo's keymap overlay is the source of truth. It is copied over the
# upstream default on every setup/build.
if [[ -f "$ROOT/keymap/rainy75.keymap" ]]; then
    echo "==> Installing keymap/rainy75.keymap"
    install -m 644 "$ROOT/keymap/rainy75.keymap" \
        "$WORK/zmk/boards/rainy75/rainy75.keymap"
fi

# Keep the managed files out of `git status` in the work tree.
EXCLUDE="$WORK/.git/info/exclude"
for f in /build_macos.sh /install_zmk_macos.sh /restore_stock_macos.sh \
         /reverse/tools/ota_flasher_macos.py; do
    grep -qxF "$f" "$EXCLUDE" 2>/dev/null || echo "$f" >> "$EXCLUDE"
done

if [[ "$NO_BUILD" -eq 1 ]]; then
    echo
    echo "==> Setup complete (build skipped)"
    echo "    build:  bash $WORK/build_macos.sh $LAYOUT"
    exit 0
fi

echo "==> Building ZMK ($LAYOUT)"
bash "$WORK/build_macos.sh" "$LAYOUT"

echo
echo "==> Build complete"
echo "    combined: $WORK/build/combined.bin"
echo "    bridge:   $WORK/build-bridge/bridge_ota.bin"
echo
echo "Next:"
echo "  1. Save a recovery image:  ./stock/fetch-stock.sh $LAYOUT"
echo "  2. Flash the keyboard:     ./flash.sh"
