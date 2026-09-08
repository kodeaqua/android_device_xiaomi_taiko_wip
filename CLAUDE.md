# CLAUDE.md — device/xiaomi/taiko

LineageOS device tree for the **Xiaomi Redmi Pad 2** (`taiko`), MediaTek
**MT6789** ("Helio G100"), Android 16 base, GKI `android16-6.12`, **no kernel
source**.

Workspace-level context (input dumps, how this tree was derived, verified
hardware facts) is in the parent `../../../CLAUDE.md`. This file is about
*editing the tree itself*.

**Target: LineageOS 23.2** (not 23.0). `hardware/mediatek` and
`device/mediatek/sepolicy_vndr` on `lineage-23.2`. The yunluo tree this was
seeded from is `lineage-23.0` — see "LineageOS 23.2 deltas" below.

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
composer@3.x, allocator, `gatekeeper.mitee`, `keymint@4.0.mitee`, usb,
sensors multihal, health (`example`), lights, media c2, `wifi-service-lazy`,
`wpa_supplicant`, `hostapd`, contexthub, `dumpstate.xiaomi`, mtkpower AIDL, …

`device.mk` adds source modules ONLY where there is no usable blob **or** where
the blob name collides with a `hardware/mediatek` source module (see next
section). Current source list: `power-service.pixel-libperfmgr`,
`vendor.lineage.health-service.default`, `PowerOffAlarm`, `create_pl_dev`,
`drm-service.clearkey`, `fastbootd`, `libmtkperf_client_vendor`,
`libperfctl_vendor`, `libpowerhalwrap_vendor`, `libaedv`, `libladder`,
`chipinfo`, `wlan_assistant`, `libwifi-hal-wrapper`,
`vendor.mediatek.hardware.mtkpower@1.2`,
`android.hardware.memtrack-service.mediatek`,
`android.hardware.thermal-service.mediatek`, `thermal_symlinks_mediatek`,
RRO overlays, init scripts, feature permission XMLs.

**Never** add a `hardware/mediatek` source HAL that a blob already covers with a
DIFFERENT name (bluetooth, boot, audio, usb, vibrator) — you'd run two.

## LineageOS 23.2 deltas (vs the yunluo 23.0 seed)

`hardware/mediatek` 23.2 is a big refactor:
- **gone**: `wpa_supplicant_8_lib` (⇒ `lib_driver_cmd_mt66xx` no longer exists —
  removed from `BoardConfig.mk`; supplicant/hostapd are blobs), `libfmjni`,
  `ims`, `BesLoudness`.
- **moved**: `PowerOffAlarm`/`InCallService` → `packages/`,
  `libwifi-hal-wrapper` → `wlan/`.
- **new**: `chipinfo`, `wlan/wlan_assistant`, `frameworks/` (`mediatek-common`
  boot jar, opt-in via `frameworks/mediatek-frameworks.mk` — not inherited yet),
  `overlay/mssi.mk` (Mssi* wifi/framework RROs — **inherited** in `device.mk`),
  `configs/properties/vendor_logtag.mk`.
- **renamed**: `memtrack-service.mediatek-mali` → `memtrack-service.mediatek`.

`device/mediatek/sepolicy_vndr` 23.2: flat `base/{vendor,private,public}` +
`debug/` (no more `basic/`+`bsp/`+`legacy/`+`modem/`). `SEPolicy.mk` does all
the wiring; `BoardConfig.mk` just `include`s it. `BOARD_MTK_SEPOLICY_IS_LEGACY`
is gone. The copied yunluo `sepolicy/vendor/` compiles against 23.2 base (types
verified) but still needs first-boot `avc` iteration.

### The blob-vs-source collision rule (why `proprietary-files.txt` was pruned)

Soong registers **every** module in the tree. If `vendor/xiaomi/taiko/Android.bp`
(generated by `extract-files.py`) defines a prebuilt named `libfoo` **and**
`hardware/mediatek` defines a source `libfoo` → `multiple modules named "libfoo"`
hard error, whether or not it is in `PRODUCT_PACKAGES`. So any blob whose
basename equals a 23.2 source module name is **deleted from
`proprietary-files.txt`** and rebuilt from source instead. To re-audit after a
`hardware/mediatek` bump:

```
grep -rhE '^\s*name:\s*"' hardware/mediatek --include='*.bp' | sed -E 's/.*"([^"]+)".*/\1/' | sort -u > /tmp/m.txt
grep -E '^[a-zA-Z]' proprietary-files.txt | sed 's/;.*//;s/|.*//' | awk -F/ '{print $NF}' | sed 's/\.so$//' | sort -u > /tmp/b.txt
comm -12 /tmp/m.txt /tmp/b.txt      # <- must be empty
```

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
