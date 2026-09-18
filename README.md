# ESP32-S3 QEMU on ARM64 — build, run, and flash-model fixes

## Contents

- `build-qemu-esp32s3.sh` — deps + clone + patch + build.
- `run-qemu-esp32s3.sh` — merge flash image + boot any ESP32-S3 firmware, UART0 on TCP.
- `patches/qemu-m25p80-rdid-sfdp-gd25q64.patch` — generic RDID 0x90/0xAB + GD25Q64
  SFDP table for QEMU's M25P80 flash model.
- `patches/pyserial-android-listports.patch` — one-line fix so pyserial (and
  therefore PlatformIO) works on Termux/Android.
- `LICENSE` (MIT).

Run Espressif's QEMU ESP32-S3 machine on ARM64 Linux (servers, Raspberry Pi,
phone proot distros) and boot real firmware in it. Includes two flash-model
fixes without which Arduino-ESP32 guests cannot get past flash init.

## Quick start (real Debian/Ubuntu ARM64, 6+ cores)

```sh
sudo sh build-qemu-esp32s3.sh     # deps + clone + patch + build (~20-40 min)
sh run-qemu-esp32s3.sh firmware.bin  # boot it, UART0 on TCP :5555
```

`build-qemu-esp32s3.sh` respects `JOBS`, `SRC`, `TAG` env vars.

## The two patches (`patches/`)

QEMU's M25P80 SPI-flash model was missing pieces the ESP32 boot path needs.
Found by tracing `guest_errors` while an Arduino-ESP32 app reboot-looped in
`esp_flash_init_default_chip` (`assert(flash_ret == ESP_OK)`):

1. **Generic RDID 0x90/0xAB responses** (`hw/block/m25p80.c`) — the model only
   answered them for SST parts and logged `Read id ... is not supported` for
   everything else. Now returns manufacturer/device ID (0x90) and electronic
   signature (0xAB) from the part's JEDEC ID, like real NOR flash.
2. **GD25Q64 SFDP table** (`hw/block/m25p80_sfdp.[ch]`, part entry) — the 8 MB
   part QEMU selects for 8 MB images had no SFDP, so RDSFDP (`0x5A`) failed.
   Adds a correct 256-byte table (Winbond-style layout, 64 Mbit density
   `0x03FFFFFF`, same 20/52/D8 erase set).

Both are candidate upstream contributions to espressif/qemu.

## Phone/proot notes (Termux)

- The official `aarch64-linux-gnu` prebuilt **aborts at startup** (`g_quark_init:
  assertion failed (quark_seq_id == 0)`, proven via gdb backtrace) — its
  statically linked ancient glib misbehaves under proot. Building from source
  (dynamic system glib, verified working) is the fix.
- Meson auto-detection picks up Termux's bionic headers/libs (`libgcrypt-config`
  on PATH, stray `-I.../termux/files/usr/include` baked into `build.ninja`).
  Fix: configure **and** build with a sanitized
  `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
  (the build script does this).
- PIO's `toolchain-xtensa-esp32s3` package fails to install under proot
  (`rename` → `EINVAL` on toolchain hardlinks). Workaround: extract the cached
  tarball directly with `tar` into the package dir (`.piopm` marker is already
  written by then).
- QEMU's JIT cannot run *inside* proot at all — build there, run on real Linux.
  (Also why Arduino guests + QEMU-S3 + DIO flash still assert: open question,
  see below.)

## Known open issue

Arduino-ESP32 (2.0.x/IDF 4.4) guests still assert in `esp_flash_init_default_chip`
even with both fixes; remaining trace shows an undecodable `cmd 0x77`
(hypothesis: dual-line DIO command bytes hitting the single-line SSI model)
plus rejected reads at `0x10200C`. IDF-based guests are unaffected per Espressif
CI. Next step for a contributor: DIO-aware command decode in the SSI path, or
confirm against a GD25Q64 datasheet capture. The Wokwi S3 simulator remains the
practical Arduino-emulation path today.
