# device/xiaomi/taiko — Xiaomi Redmi Pad 2 (LineageOS bring-up)

Codename **taiko**. First bring-up skeleton, generated against the stock
`OS3.0.304.0.WOVMIXM` (Android 16) OTA dump.

## Hardware / firmware summary (from the dump)

| Item | Value | Source |
|------|-------|--------|
| SoC | MediaTek **MT6789** (marketed "Helio G100" on this SKU) | `ro.board.platform`, `ro.vendor.mediatek.platform` |
| CPU | 2× Cortex-A76 + 6× Cortex-A55 | MT6789 |
| GPU | Mali-G57 MC2 | MT6789 |
| Kernel | **GKI android16-6.12** — stock `6.12.30-android16-5`, **no public source** | `strings boot/kernel` |
| Android | 16 (SDK 36), build `BP2A.250605.031.A3` | `system/build.prop` |
| Vendor SPL | 2026-06-05 · System SPL 2026-08-01 | `*/build.prop` |
| Slotting | **Virtual A/B (compressed)** | `ro.virtual_ab.*` |
| Partitions | dynamic (super): system, system_ext, product, vendor, vendor_dlkm, odm_dlkm, system_dlkm, mi_ext | fstab + payload list |
| boot.img | header v4, **kernel only** (no ramdisk) | parsed header |
| init_boot | **does not exist** on this device | OTA payload partition list |
| vendor_boot.img | header v4, **2 ramdisk fragments**: `[0] PLATFORM` (default) + `[1] RECOVERY` ("recovery") | parsed vendor ramdisk table |
| TEE / keystore | **Microtrust "mitee"** (`keymint@4.0-service.mitee`, `gatekeeper-service.mitee`) — *not* beanpod | `proprietary-files.txt`, `modules.load` |
| Modem | none — **Wi-Fi only** (`ro.radio.noril=true`) | `product/build.prop` |
| Density | 360 | `ro.sf.lcd_density` / `persist.miui.density_v2` |
| Display panels | o84-3x / o84-42 DSC VDO (see `modules.load.vendor_ramdisk`) | dump |

## Boot architecture (important — differs from the earlier claude-web draft)

```
boot.img         = stock GKI kernel, NO ramdisk        -> used AS-IS (BOARD_PREBUILT_BOOTIMAGE)
(no init_boot)
vendor_boot.img  = generic ramdisk + vendor first-stage + kernel modules   -> REBUILT
                 + recovery ramdisk fragment (LineageOS recovery)          -> REBUILT
dtbo.img         = stock overlays                       -> used AS-IS (BOARD_PREBUILT_DTBOIMAGE)
```

`taiko_referensi_BoardConfig.mk` / `taiko_referensi_device.mk` (the claude-web
drafts in the parent dir) were used as a starting point. Four things in them were
wrong against the actual dump and are fixed here:

1. **A/B** — the device *is* Virtual A/B (`ro.virtual_ab.enabled=true`,
   `update_engine` present). The draft set `AB_OTA_UPDATER := false`.
2. **2nd vendor_boot ramdisk** — it is a **RECOVERY** fragment, a normal
   `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT` layout, **not** a "dlkm"
   prebuilt fragment.
3. **init_boot** — correctly absent; the draft's reasoning was right, kept.
4. **keystore** — backend is `mitee`, not `beanpod` (affects `extract-files.py`
   blob fixups, not this file).

The structural template is the proven **`dt_xiaomi_yunluo_redmipad1`** tree
(Redmi Pad 1, same MT6789 platform, same vendor), updated for Android 16 /
GKI 6.12 / system_dlkm / mi_ext.

**Target branch: LineageOS 23.2.** yunluo is 23.0. `hardware/mediatek` 23.2 is a
large refactor — see `CLAUDE.md` "LineageOS 23.2 deltas". Key consequences here:
`proprietary-files.txt` had all `*.hbtf` sidecars and every source-colliding
blob removed (those are rebuilt from `hardware/mediatek` via `device.mk`);
`lib_driver_cmd_mt66xx` dropped from `BoardConfig.mk`; `overlay/mssi.mk`
inherited.

## Layout

```
BoardConfig.mk          board-level config (partitions, AVB, kernel, modules)
device.mk               product packages / copy files (BLOB-FIRST — see header)
lineage_taiko.mk        product definition (identity, inherits)
AndroidProducts.mk      lunch combos
extract-files.py        blob extractor (adapt fixups on first run)
setup-makefiles.py
proprietary-files.txt   3.5k blobs, from aospdtgen on this exact build
proprietary-firmware.txt non-super firmware partitions
configs/
  props/               *.prop split per partition (from aospdtgen)
  vintf/               device manifest + compat matrix
  audio/ media/ wifi/ seccomp/  MT6789-generic (from yunluo — refine from dump)
  hals.conf powerhint.json thermal_info_config.json
rootdir/
  etc/fstab.mt6789     first-stage + recovery fstab (erofs+ext4 fallback lines)
  etc/*.rc bin/*.sh    MTK init scripts (from the stock vendor ramdisk)
sepolicy/vendor/       starting point from yunluo — REGENERATE from first-boot avc
overlay/ overlay-lineage/  RRO overlays (renamed Yunluo -> Taiko)
prebuilt/
  boot.img             stock, used as-is
  vendor_boot.img      stock, kept for reference/fallback (build regenerates it)
  dtbo.img             stock, used as-is
  dtb/mt6789.dtb       dtb carved out of stock vendor_boot, packed into new vendor_boot
  kernel.lz4           stock GKI Image (lz4) — reference only
  modules/             210 vendor_boot ramdisk .ko  + modules.load.vendor_ramdisk
  vendor_dlkm/         199 .ko + modules.load
  system_dlkm/          82 GKI .ko + modules.load
```

## Building

```
# in a LineageOS 23 (Android 16) tree
source build/envsetup.sh
# device tree  -> device/xiaomi/taiko   (this dir)
# kernel       -> none (prebuilt boot.img)
# vendor blobs -> vendor/xiaomi/taiko   (run ./extract-files.py <path-to-dump> first)
lunch lineage_taiko-userdebug
mka bacon
```

`extract-files.py` runs with `check_elf=True`; it will list any blob whose
`NEEDED` libs are missing — add targeted fixups to the `blob_fixups` map and
re-run.

## AOSP-core audit (source.android.com/docs/core)

Checked against: generic-boot, vendor-boot-partitions, gki-partitions,
dynamic-partitions, loadable-kernel-modules, vndk build-system.

Fixed:
- `BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true` added — required
  (with header v4 + `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT`) to emit the
  standalone `recovery` fragment (ramdisk_type RECOVERY) that stock has.
- `TARGET_COPY_OUT_ODM := vendor/odm` — taiko has no `odm` partition (only
  `odm_dlkm`); 19 blobs + `odm.prop` target `odm/` and would otherwise try to
  build a non-existent `odm.img`.
- Dropped `BOARD_AVB_RECOVERY_*` (no recovery partition) and
  `BOARD_KERNEL_SEPARATED_DTBO` (build-from-source-only flag; we ship a prebuilt
  dtbo).
- `BOARD_SUPER_PARTITION_METADATA_DEVICE := super` made explicit.

Verified OK:
- boot.img kernel-only + no init_boot + `BOARD_USES_GENERIC_KERNEL_IMAGE` ⇒ the
  generic ramdisk is concatenated into vendor_boot by the build (AOSP behaviour),
  so `TARGET_NO_KERNEL` + `BOARD_PREBUILT_BOOTIMAGE` is sufficient.
- Virtual A/B (not legacy A/B): super holds ONE copy of the logical set, so
  `BOARD_<group>_SIZE ≈ BOARD_SUPER_PARTITION_SIZE` is correct (not `/2`).
- fstab logical partitions == dynamic-partition list (7/7).
- `BOARD_AVB_VBMETA_SYSTEM` / `_VENDOR` groups match every `avb=` tag in fstab.
- No VNDK (`BOARD_VNDK_VERSION`) — correct, VNDK is deprecated on Android 16.
- `system_dlkm` modules are the stock GKI set (KMI-locked to `6.12.30-android16-5`).

- Dalvik heap: device is **4 GB RAM**; switched to
  `phone-xhdpi-4096-dalvik-heap.mk` (heapgrowthlimit 256m / heapsize 512m),
  which matches the stock `vendor/build.prop` values exactly.

Still open: see TODO.

## TODO before a flashable build

- [ ] `BOARD_SUPER_PARTITION_SIZE` / group size — confirm from a real
      `fastboot getvar all` or the stock `super_map.pb` (placeholder = yunluo's).
- [ ] `extract-files.py` blob fixups — iterate against `check_elf` output.
- [ ] `sepolicy/vendor` — rebuild from `dmesg | grep 'avc: denied'` on first boot;
      the copied yunluo rules only partially match.
- [ ] `configs/audio|media|wifi` — diff against `vendor/etc/*` in the dump and
      replace where the MT6789-generic yunluo copies differ.
- [ ] `configs/vintf/manifest.xml` + `compatibility_matrix.xml` — verify against
      `vendor/etc/vintf/*` from the dump.
- [ ] `modules.load.recovery` currently mirrors `modules.load.vendor_ramdisk`;
      carve the real recovery fragment with `unpack_bootimg --format=mkbootimg`
      if recovery misbehaves.
- [ ] Trim HyperOS-only `persist.miui.*` / `persist.sys.stability.*` from
      `configs/props/product.prop` once the device boots.
- [ ] Decide `mi_ext` fate — kept mountable+nofail in fstab; a pure-AOSP build
      ships no mi_ext image.
- [ ] `overlay/` + `overlay-lineage/` values are still yunluo's — fix panel
      resolution / refresh-rate in `FrameworksResOverlay/res/values/config.xml`,
      `power_profile.xml` (Redmi Pad 2 ~9000 mAh), Wi-Fi country, Settings
      config, from the taiko dump / panel dtsi.
- [ ] Re-sign with real AVB keys once unlocked-and-booting (currently AOSP test
      keys everywhere).
```
