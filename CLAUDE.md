# CLAUDE.md — device/xiaomi/taiko

LineageOS device tree for the **Xiaomi Redmi Pad 2** (`taiko`), MediaTek
**MT6789** ("Helio G100"), Android 16 base, GKI `android16-6.12`, **no kernel
source**.

Workspace-level context (input dumps, how this tree was derived, verified
hardware facts) is in the parent `../../../CLAUDE.md`. This file is about
*editing the tree itself*.

## File responsibilities

| File | Owns |
|---|---|
| `BoardConfig.mk` | partitions, filesystem types, AVB, boot/vendor_boot layout, kernel-module wiring, SELinux/Wi-Fi board flags |
| `device.mk` | `PRODUCT_PACKAGES` / `PRODUCT_COPY_FILES` — **blob-first**, only non-blob HALs + Lineage extras |
| `lineage_taiko.mk` | product identity, `inherit-product` chain (`core_64_bit_only` + `full_base` + `common_full_tablet_wifionly`) |
| `AndroidProducts.mk` | lunch combos |
| `extract-files.py` / `setup-makefiles.py` | blob extractor; `blob_fixups` map is tuned against `check_elf` output |
| `proprietary-files.txt` | ~3.5k blobs (aospdtgen, this exact build) |
| `proprietary-firmware.txt` | non-super firmware partitions (`dpm`, `gz`, `lk`, `md1img`, `tee`, …) |
| `configs/props/*.prop` | per-partition props, wired via `TARGET_*_PROP` in `BoardConfig.mk` |
| `configs/vintf/` | device manifest + compat matrix |
| `configs/audio\|media\|wifi\|seccomp/` | MT6789-generic, **copied from yunluo — refine from `dump-ota/vendor/etc`** |
| `rootdir/etc/fstab.mt6789` | first-stage **and** recovery fstab (erofs+ext4 fallback lines) |
| `rootdir/etc/*.rc`, `rootdir/bin/*.sh` | MTK init scripts from the stock vendor ramdisk; each has a `prebuilt_etc`/`sh_binary` in `rootdir/Android.bp` **and** a line in `device.mk` `PRODUCT_PACKAGES` — keep both in sync |
| `sepolicy/vendor/` | **yunluo starting point** — regenerate from first-boot `avc: denied` |
| `overlay/`, `overlay-lineage/` | RRO packages (in `PRODUCT_PACKAGES`, **not** `DEVICE_PACKAGE_OVERLAYS`); values still yunluo's |
| `prebuilt/` | `boot.img`/`dtbo.img` (used as-is), `vendor_boot.img` (reference), `dtb/mt6789.dtb`, `modules/`, `vendor_dlkm/`, `system_dlkm/` |

## Boot / kernel model (do not "fix" this into a normal kernel build)

- `boot.img`: stock GKI, **kernel-only**, consumed via `TARGET_NO_KERNEL := true` + `BOARD_PREBUILT_BOOTIMAGE`. Build only rewrites its AVB footer.
- No `init_boot` partition — do **not** add `BOARD_PREBUILT_INIT_BOOT_IMAGE`.
- `vendor_boot.img`: **rebuilt** from `prebuilt/dtb/` + `prebuilt/modules/` + Lineage recovery. Header v4, `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true`. The "2 ramdisks" people mention = PLATFORM + RECOVERY fragments, nothing else.
- `dtbo.img`: stock, `BOARD_PREBUILT_DTBOIMAGE` (no source to regenerate overlays).
- All `.ko` are prebuilt and KMI-locked to stock GKI `6.12.30-android16-5`. If you swap the kernel/GKI build, re-extract every module set.

## Kernel module wiring

```
prebuilt/modules/            + modules.load.vendor_ramdisk  -> BOARD_VENDOR_RAMDISK_KERNEL_MODULES[_LOAD]
                             + modules.load.recovery        -> BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD
prebuilt/vendor_dlkm/*.ko    + vendor_dlkm/modules.load     -> BOARD_VENDOR_KERNEL_MODULES[_LOAD]
prebuilt/system_dlkm/*.ko    + system_dlkm/modules.load     -> BOARD_SYSTEM_KERNEL_MODULES[_LOAD]
```

`modules.load.recovery` currently mirrors `modules.load.vendor_ramdisk` (the
dump merged the two fragments). Only split it if recovery misbehaves.

Validate after any module change:
```
cd prebuilt && while read m; do [ -f modules/$m ] || echo "missing $m"; done < modules.load.vendor_ramdisk
```

## HAL rule

Blob-first. `proprietary-files.txt` provides audio, bluetooth, camera,
composer@3.x, allocator, `gatekeeper.mitee`, `keymint@4.0.mitee`, thermal, usb,
memtrack, sensors multihal, health, lights, media c2, `wifi-service-lazy`,
`wpa_supplicant`, `hostapd`, contexthub, `dumpstate.xiaomi`, …

`device.mk` adds ONLY: `power-service.pixel-libperfmgr`, `vendor.lineage.health-service.default`,
`PowerOffAlarm`, `drm-service.clearkey`, `fastbootd`, RRO overlays, init scripts,
feature permission XMLs. **Never** add `android.hardware.*-service.mediatek`
source packages — collision with blobs.

## Build

```
lunch lineage_taiko-userdebug
mka bacon      # after ./extract-files.py <dump> -> vendor/xiaomi/taiko
```

## When editing

- Values come from `../../../dump-ota/`, not from the yunluo tree.
- Keep SPDX headers: `SPDX-FileCopyrightText: 2026 The LineageOS Project`.
- Adding/removing an init `.rc`: update `rootdir/Android.bp` **and** `device.mk`.
- Adding a blob: `proprietary-files.txt` + (if ELF-broken) a `blob_fixups` entry.
- Don't silently replace a `TODO`/placeholder with a guess — see `README.md`.
