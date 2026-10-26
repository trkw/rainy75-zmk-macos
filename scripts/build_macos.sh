#!/usr/bin/env bash
# Rebuild the Rainy 75 ZMK firmware natively on macOS.
#
# This is the toolchain used for the first successful ANSI build:
#   - Nix provides GNU bash/coreutils, ninja, dtc, protoc, Python 3.12
#   - CMake 3.31.6 comes from pip (CMake 4.x trips a Zephyr 4.1 if() bug)
#   - Zephyr SDK 0.17.0 (macOS arm64 or x86_64) in toolchain/
#
# Usage:
#   bash build_macos.sh [--ansi|--iso]
#
# Outputs:
#   build/combined.bin
#   build-bridge/bridge_ota.bin
#   build/zephyr/zmk.signed.bin
set -euo pipefail
cd "$(dirname "$0")"

LAYOUT="${1:---ansi}"
case "$LAYOUT" in
  --ansi|--iso) ;;
  *) echo "Usage: $0 [--ansi|--iso]" >&2; exit 2 ;;
esac

case "$(uname -m)" in
  arm64)  SDK_ARCH="macos-aarch64" ;;
  x86_64) SDK_ARCH="macos-x86_64" ;;
  *) echo "Unsupported Mac architecture: $(uname -m)" >&2; exit 2 ;;
esac

command -v nix >/dev/null 2>&1 || {
  echo "Nix is required: https://nixos.org/download/" >&2
  exit 2
}
xcode-select -p >/dev/null 2>&1 || {
  echo "Install Xcode Command Line Tools first: xcode-select --install" >&2
  exit 2
}

NIX_PKGS=(
  nixpkgs#bash nixpkgs#coreutils nixpkgs#gnused nixpkgs#gnugrep nixpkgs#gawk
  nixpkgs#findutils nixpkgs#cmake nixpkgs#ninja nixpkgs#dtc nixpkgs#python312
  nixpkgs#git nixpkgs#wget nixpkgs#curl nixpkgs#xz nixpkgs#pkg-config
  nixpkgs#ccache nixpkgs#protobuf
)

if [ ! -x toolchain/zephyr-sdk-0.17.0/setup.sh ]; then
  echo "==> Downloading Zephyr SDK 0.17.0 ($SDK_ARCH)"
  mkdir -p toolchain
  (
    cd toolchain
    curl -fL --retry 3 -o "zephyr-sdk-0.17.0_${SDK_ARCH}_minimal.tar.xz" \
      "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.17.0/zephyr-sdk-0.17.0_${SDK_ARCH}_minimal.tar.xz"
    tar xf "zephyr-sdk-0.17.0_${SDK_ARCH}_minimal.tar.xz"
  )
  nix shell "${NIX_PKGS[@]}" -c bash -c \
    'cd toolchain/zephyr-sdk-0.17.0 && ./setup.sh -t riscv64-zephyr-elf'
fi
xattr -dr com.apple.quarantine toolchain/zephyr-sdk-0.17.0 2>/dev/null || true

export LAYOUT
nix shell "${NIX_PKGS[@]}" -c bash -c '
set -e
if [ ! -x .venv/bin/python ]; then
  python3 -m venv .venv
fi
. .venv/bin/activate
python -m pip install -q --upgrade pip
python -m pip install -q west protobuf hidapi dnfile "cmake==3.31.6"
if [ ! -d .west ]; then
  west init -l zmk
fi
west update
python -m pip install -q -r zephyr/scripts/requirements.txt
west zephyr-export
bash build.sh -a "$LAYOUT"
'
