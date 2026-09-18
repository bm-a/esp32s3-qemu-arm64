#!/bin/sh
# Boot an ESP32-S3 firmware image on the locally built QEMU.
# Usage: sh run-qemu-esp32s3.sh <bootloader.bin> <partitions.bin> <firmware.bin> [tcp_port]
# Needs a REAL Linux/mac host (QEMU JIT does not run inside proot).
set -eu
QEMU_BIN="${QEMU_BIN:-/opt/qemu-src/build/qemu-system-xtensa}"
PORT="${4:-5555}"
python3 -m esptool --chip esp32s3 merge_bin --fill-flash-size 8MB \
  -o /tmp/s3_flash_image.bin 0x0 "$1" 0x8000 "$2" 0x10000 "$3" >/dev/null
"$QEMU_BIN" -nographic -machine esp32s3 \
  -drive file=/tmp/s3_flash_image.bin,if=mtd,format=raw \
  -serial "tcp::$PORT,server,nowait"
