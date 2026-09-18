#!/bin/sh
# Build Espressif QEMU (xtensa system) from source on ARM64 Linux.
# Why from source: the official aarch64 prebuilt aborts at startup
# (static ancient glib, g_quark_init assertion) under proot sandboxes,
# and cannot run Arduino-ESP32 guests without the patches in patches/.
# Sanitizes PATH first: Termux/proot environments leak bionic include/lib
# paths into meson detection otherwise.
set -eu
JOBS="${JOBS:-$(nproc)}"
SRC="${SRC:-/opt/qemu-src}"
TAG="${TAG:-esp-develop-9.2.2-20260417}"

if [ ! -d "$SRC" ]; then
  git clone --depth 1 --branch "$TAG" https://github.com/espressif/qemu "$SRC"
  (cd "$SRC" && git submodule update --init --depth 1)
fi
# Our flash-model fixes (RDID 0x90/0xAB + GD25Q64 SFDP). Re-apply cleanly:
for p in "$(dirname "$0")"/patches/*.patch; do
  (cd "$SRC" && git apply --check "$p" >/dev/null 2>&1 && git apply "$p" && echo "applied $(basename "$p")" || echo "skip $(basename "$p") (already applied?)")
done
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  ninja-build meson libpixman-1-dev zlib1g-dev libslirp-dev \
  libglib2.0-dev libgcrypt20-dev libgpg-error-dev pkg-config \
  python3 python3-venv git curl build-essential binutils
cd "$SRC"
rm -rf build
env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  ./configure --target-list=xtensa-softmmu \
  --disable-werror --disable-docs --disable-sdl --disable-gtk \
  --disable-spice --disable-vnc --disable-brlapi
env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  ninja -C build -j"$JOBS" qemu-system-xtensa
./build/qemu-system-xtensa --version
