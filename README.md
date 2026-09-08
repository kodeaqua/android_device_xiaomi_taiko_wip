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
dynamic-partitions, loadable-kernel-modules, vndk build-system, VINTF objects,
SELinux device policy.

### Round 19 — more kati "already defined": AOSP test/passthrough/legacy blobs

`hardware/libhardware/tests/nusensors: MODULE.TARGET.EXECUTABLES.test-nusensors
already defined by vendor/xiaomi/taiko`. Same class as Round 18 - HyperOS left a
pile of AOSP-built binaries/libs in `/vendor`. Dropped from
`proprietary-files.txt` (soong builds each from source, or they are dead on
Android 16):

- `test-nusensor` / `test-nusensors` - `hardware/libhardware` test binaries.
- Legacy HW-module passthrough libs (dead under full-AIDL A16, every name
  collides with `hardware/libhardware`/`libhardware_legacy`): `gralloc.default`,
  `power.default`, `vibrator.default`, `local_time.default`,
  `sound_trigger.primary.default`, `audio_policy.stub`. Kept
  `displayfeature.default` (Xiaomi's real HAL).
- `libbluetooth_audio_session` / `libbluetooth_audio_session_aidl` - `vendor:
  true` libs from `hardware/interfaces/bluetooth/audio/utils`, pulled into the
  graph by the AIDL BT-audio HAL. MTK's impl links the `_mtk` / `_mediatek`
  variants, which stay.
- `android.hardware.bluetooth.audio@2.0-impl` / `@2.1-impl`,
  `android.hardware.renderscript@1.0-impl`, `audio.bluetooth.default` - legacy
  HIDL / RenderScript, unused on A16 (AIDL BT audio + no RS HAL).

The bare SW audio-effect libs (`libbassboostsw`, `libequalizersw`, ...) also
share names with `audio/aidl/default/*` but those are plain `cc_library_shared`
with visibility limited to that package and only pulled by the AOSP `.example`
effect service (which we don't run), so the MTK blobs stand - MTK's
`audio_effects_config.xml` needs them.

### Round 18 — kati "MODULE ... already defined" (stock ships AOSP reference impls)

Past soong bootstrap now; kati fails
`vendor/xiaomi/taiko: MODULE.TARGET.ETC.android.hardware.audio.service-aidl.xml
already defined by hardware/interfaces/audio/aidl/default`. HyperOS ships several
`hardware/interfaces` reference implementations **verbatim as blobs** (their file
headers literally say `Input: hardware/interfaces/...`), and `extract-utils`
registers each as a module that collides with the AOSP source module of the same
name. Fixed:

- **audio core AIDL vintf** (`android.hardware.audio.service-aidl.xml`): needed
  for `android.hardware.audio.core/IModule` registration, but the name is taken
  by `audio/aidl/default`. VINTF dir-scans `manifest/*.xml`, so ship the same
  content from the tree via `PRODUCT_COPY_FILES` (no module) as
  `...service-aidl.mediatek.xml`.
- **health** (`android.hardware.health-service.example` bin/rc/xml +
  `filterPowerSupplyEvents.o`): drop blobs, `PRODUCT_PACKAGES +=
  android.hardware.health-service.example` (source). `filterPowerSupplyEvents.o`
  is force-added by `base_vendor.mk` so the blob always collided.
- **sensors** (`android.hardware.sensors-service.multihal` bin/rc/xml): drop
  blobs, `PRODUCT_PACKAGES += android.hardware.sensors-service.multihal`
  (source). Added the real primary sub-HAL blob
  `android.hardware.sensors@2.X-subhal-mediatek.so` (aospdtgen missed it) and
  dropped the stale yunluo `configs/hals.conf` copy from `device.mk` - the stock
  `/vendor/etc/sensors/hals.conf` blob (subhal-mediatek + sensors.camera.light)
  is the correct one.

`audio_effects_config.xml` also shares a name with `audio/aidl/default` but that
module is `enabled: false` unless `use_default_audio_effects_config` soong var is
set, so the MTK blob stands.

### Round 17 — camera re-enabled (MTK ISP6s + MiCam)

Camera was dropped in the Path-A batches (81cffce et al) on the belief that
"the MTK AIDL camera glue is built against camera.common V1, no drop-in fix".
Re-audited: `readelf -d` on the whole stock camera set shows the live AIDL glue
(`libmtkcam_hal_aidl_{common,device,provider,utils}`, `camerahalserver`) links
`camera.device-V3` / `camera.provider-V3` / `camera.metadata-V3` — all of which
lineage-23.2 `hardware/interfaces` provides (frozen V3/V3/V4). The *only* real
skew is `libmtkcam_hal_aidl_common` -> `camera.common-V2`, while the tree has
`camera.common` frozen at **V1** (no V2 module). That lib has **0 undefined
`camera::common` symbols** (the V2 NEEDED is a stale link artifact), and
`camera.device-V3` itself imports `camera.common-V1`, so `extract-files.py`
down-patches the NEEDED V2 -> V1. Plus three trailing skews on satellite libs:
`libmtkcam_grallocutils` graphics.common V5 -> V7, `camera.isphal-V1-ndk`
graphics.common V6 -> V7, `libcam.utils.sensorprovider` sensors V2 -> V3.

465 blob lines restored to `proprietary-files.txt` (libmtkcam*, lib3a.*,
libcam.*, libcamalgo.*, libcameracustom*, MTK camera AIDL/HIDL interface libs,
`camerahalserver` + `.rc`, `manifest_cameraprovider/isphal.xml`, all
`vendor/etc/camera/*` tuning/resources). The two `android.hardware.wifi.*.xml`
VINTF fragments that got swept into the same commits stay dropped (supplicant/
hostapd are built from source and ship their own). `Android.mk`
`MTK_SOC_SYMLINKS` regenerated: 265 `/vendor/lib*/mt6789 -> ..` symlinks (every
stock mt6789 lib has one). No blob-vs-source name collisions
(`hardware/mediatek` 23.2 has no camera source). Full re-extract required.

### Round 16 — framework compat matrix path

`module "framework_compatibility_matrix.device.xml" ... source path
"vendor/lineage/config/device_framework_matrix.xml" does not exist`. The seed
`BoardConfig.mk` (copied from yunluo) hard-listed the Lineage-internal matrix in
`DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` with `:=`. `vendor/lineage/config/
common.mk` already appends that file itself; re-listing it (a) breaks bootstrap
if the path moves and (b) `:=` clobbers the Lineage + AOSP defaults. Fix: `+=`
with only `hardware/mediatek/vintf/mediatek_framework_compatibility_matrix.xml`.

### Round 15 — graphics.common V6 -> V7 AIDL skew

`module "libgpud" / "hwcomposer.mtk_common" ... depends on multiple versions of
the same aidl_interface: android.hardware.graphics.common-V6-ndk vs -V7-ndk`.
HyperOS Android 16 froze `graphics.common` at V6; LineageOS 23.2 trunk is at V7.
Source `libgralloctypes` / `libui` / `graphics.allocator-V2-ndk` pull V7, the MTK
gralloc/mapper/allocator/HWC/GPU/codec2/pq blobs pull V6. `graphics.common` is a
types-only package and V7 is a backward-compatible superset, so `extract-files.py`
`blob_fixups` `replace_needed` V6 -> V7 on every consumer blob
(`android.hardware.graphics.allocator-V2-mediatek`, `mapper.mediatek`,
`hwcomposer.mtk_common`, `libgpud`, `libcodec2_fsr`, `libaimemc`,
`libcodec2_vpp_AIMEMC/AISR_plugin`, `vendor.mediatek.hardware.pq_aidl-V3/V7-ndk`).
Same technique as the libmt_mitee keymint V3 -> V4 fix. Second pass added the
`allocator-V2-service-mediatek.mt6789` binary itself (direct graphics.common-V6
NEEDED) and bumped `pq_aidl-impl` sensors-V2 -> V3 (source
`android.frameworks.sensorservice-V1-ndk` pulls sensors-V3).

### Rounds 12-14 — trailing AOSP vendor_available collisions

More one-at-a-time `partition is different`, removed as they surfaced:
- keymint/keystore: `lib_android_keymaster_keymint_utils`, `libcppbor`,
  `libcppbor_external`, `libkeymint`, `libkeymint_remote_prov_support`,
  `libkeymint_support` (mitee keymint service links the source vendor variants).
- `libsensorndkbridge`, `libmediautils_vendor`, `libcamera2ndk_vendor`.
MediaTek's own `lib*_vendor.so` (audio/gpu/camera) are kept - the `_vendor`
suffix there is just MTK's naming, not the AOSP vendor-variant leak.

### Round 11 — dmabuf_dump + AOSP tool bins

`module "dmabuf_dump" ... partition is different`. AOSP `system/memory/libmeminfo`.
Removed the AOSP `vendor_available` tools/lib aospdtgen had grabbed as blobs:
`dmabuf_dump`, `dumpsys`, `boringssl_self_test32/64`, `getfattr`, `setfattr`,
`getopt`, `blkdiscard` (vendor/bin) and `libmeminfo.so`.

### Round 10 — libalsautils

`module "libalsautils" ... partition is different: system(libalsautils) !=
vendor(prebuilt_libalsautils)`. AOSP `system/media/alsa_utils`. Removed
`vendor/lib{,64}/libalsautils.so`. `libalsautilsv2.so` also AOSP (`system/media/alsa_utils` builds v1 + v2) - removed too.
A scan of the blob list against ~90 common AOSP `vendor_available` lib names
found only this one still wrong.

Note: the recurring kati warning
`One culprit glob (may be more): device/xiaomi/taiko-kernel/...` is harmless -
a stale glob cache for the removed dir; `rm -f out/.kati_stamp-lineage_taiko*`
silences it. It is not the build failure.

### Round 9 — more "partition is different" (hw/mediatek interface libs)

`vendor.mediatek.hardware.audio-V1-ndk` (built by `hardware/mediatek/interfaces/
hardware/audio/aidl`) and `libbinderdebug` (AOSP) collided with vendor prebuilts.
Removed `vendor.mediatek.hardware.audio-V1-ndk.so`, `...audio@6.1.so` (dead HIDL
audio), `libbinderdebug.so`. Kept `...audio-impl.so` (the real HAL impl).
`hardware/mediatek` only defines 63 soong modules — cross-checked the blob list
against them; only these hit.

### Round 8 — "partition is different" (AOSP libs listed as vendor blobs)

`module "libgrallocusage" ... partition is different: system(libgrallocusage) !=
vendor(prebuilt_libgrallocusage)`. aospdtgen listed AOSP `frameworks/av` /
`system/core` libs as vendor blobs; their `prebuilt_*` fights the source
module's vendor variant. Removed 17: `libgrallocusage`, `libcodec2_aidl`,
`libcodec2_hal_common`, `libcodec2_hidl_plugin`, `libcodec2_soft_common`,
`libcodec2_hidl@1.1/1.2`, `libsfplugin_ccodec_utils`,
`libstagefright_aidl_bufferpool2`, `libstagefright_bufferpool@2.0.1`
(lib + lib64). MediaTek's own `libcodec2_mtk_*` / dolby / vpp / fsr blobs kept.

Also: `rm -rf device/xiaomi/taiko-kernel/` on the build machine — a stale dir
from an earlier attempt (soong "One culprit glob" warning).

### Round 7 — libwifi-hal-mediatek undefined

`"libwifi_hal_vendor_impl_defaults" depends on undefined module "libwifi-hal-mediatek"`.
`BOARD_WLAN_DEVICE := MediaTek` (added in round 2) makes LineageOS' frameworks
wifi HAL select a `libwifi-hal-mediatek` module that doesn't exist on 23.2 —
`hardware/mediatek/wlan` provides `libwifi-hal-wrapper`. Removed
`BOARD_WLAN_DEVICE`; unset uses the wrapper path (same as yunluo).

### Round 6 — soong namespace / dependency repos

`vendor/xiaomi/taiko/Android.bp:5: namespace hardware/lineage/compat does not exist`.
- On lineage-23.2 **`hardware/lineage/compat` has no `soong_namespace {}`**
  (flat modules in the default namespace) — it must NOT be in
  `extract-files.py` `namespace_imports`. Removed it; the `*_shim` libs are
  still usable by plain name in `blob_fixups`. (`hardware/mediatek`,
  `hardware/mediatek/libmtkperf_client`, `hardware/xiaomi` DO declare
  namespaces — kept.)
- Added `lineage.dependencies` for the real device deps (`hardware/mediatek`,
  `device/mediatek/sepolicy_vndr`, `hardware/xiaomi`). `hardware/lineage/compat`
  is in the LineageOS base manifest already — don't list it (roomservice would
  write a duplicate project).
- Dropped the unused `hardware/google/pixel` soong namespace (pixel-libperfmgr
  was dropped in round 2).

### Round 5 — soong "module already defined" (proprietary-files dupes)

`vendor/xiaomi/taiko/Android.bp` had ~300 `prebuilt_* already defined` errors.
extract-utils derives a soong module name from the file **basename**, so any two
listed files with the same basename collide. Deduped `proprietary-files.txt`
(-538 lines):
- **`vendor/lib*/foo.so` + `vendor/lib*/mt6789/foo.so`** — the bare one is a
  symlink in the stock image; kept only the real `mt6789/` file. `Android.mk`
  now recreates all 280 `/vendor/<dir>/foo.so -> mt6789/foo.so` symlinks (same
  mechanism as the yunluo tree). Same for `bin/`, `bin/hw/`, `hw/`, `egl/`,
  `mtkcam/` SoC subdirs.
- **`binShaders32/` camera shaders** — dropped (64-bit-only device, `binShaders64/`
  is used).
- **`system_ext/lib*/` + `system_ext/etc/`** copies whose `vendor/` twin is kept
  (MTK HIDL/AIDL interface `.so`s: pq@2.x, mtkpower, camera.atms/isphal,
  composer_ext; audio-policy XMLs).
- **`vendor/etc/imgsensor/mt699{1,3}/`, `vendor/etc/mt699{1,3}/`** — flagship-SoC
  camera calibration, wrong platform, dropped.
- **`vendor/etc/rsc/`** and all `build_taiko_*.prop` — HyperOS regional runtime
  config, not used by LineageOS.
- **`vendor/etc/camera/resources/render/Effect/`** — Xiaomi beautify resources,
  duplicate filenames across effect subdirs; dropped (camera capture works
  without them).

### Round 4 — proprietary-files.txt (extract-files.py failures)

First `./extract-files.py` run on the build machine exited with 53 "file not
found" lines. Fixed:
- **bare `lib/` `lib64/` `etc/` entries** (no partition prefix): these files
  live on the AOSP-built `system` partition. `libstagefright_*`,
  `libmedia_codeclist_*`, `graphicbuffersource-aidl-ndk`,
  `libaconfig_storage_read_api_cc` are built from source by LineageOS → removed.
  `libdolby*` / `audio_effects.*` / `mediacodec.policy` are optional → removed
  (re-add as `system/lib*/…` if Dolby Atmos is wanted).
- **`vendor/odm/…` entries**: wrong form. odm is folded into `/vendor/odm`
  (`TARGET_COPY_OUT_ODM := vendor/odm`), so the correct extract-utils prefix is
  `odm/…` (already in the file). The 7 unique `vendor/odm/etc/selinux/*`
  (precompiled `odm_sepolicy.cil` etc.) were dropped — policy is built from
  source, never shipped precompiled.

Re-run `./extract-files.py <path-to-OTA.zip>`; expect a second pass of
`check_elf` fixups (add to `blob_fixups` in `extract-files.py`).

### Round 3 — kernel VINTF / OTA / DTO / fstab

- `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` added. `PRODUCT_SHIPPING_API_LEVEL := 36`
  auto-enables strict `check_vintf`, but `TARGET_NO_KERNEL` means there is no
  `$(PRODUCT_OUT)/kernel` for it to match the FCM `<kernel>` section (version +
  `CONFIG_*`) against — the check has no input and would error. The stock GKI
  kernel satisfies android16-6.12 by definition.
- `AB_OTA_POSTINSTALL_CONFIG` — added the `vendor` / `checkpoint_gc` entry
  (was `system` / dexopt only); standard for Virtual A/B F2FS checkpoint GC.
- DTO: reusing **stock `dtbo.img` + stock vendor_boot DTB** as prebuilts is the
  lowest-risk overlay setup — base and overlays are guaranteed to match. No
  `BOARD_DTBO_CFG` (not building dtbo from source); `BOARD_INCLUDE_DTB_IN_BOOTIMG`
  empty (DTB lives in vendor_boot). Verified OK.
- fstab checked against the stock `vendor/etc/fstab.mt6789`: `/data` f2fs flags
  match stock (+ `fscompress`, paired with `PRODUCT_FS_COMPRESSION := 1`);
  `/metadata` carries an extra `data=journal,commit=1` (yunluo hardening, kept);
  metadata-encryption / checkpoint / fileencryption / fsverity all match.

### Round 2 — VINTF / SELinux

- `configs/vintf/manifest.xml` replaced with the **stock** device manifest
  (aospdtgen's copy dropped `<sepolicy><version>202504</version>` and the HAL
  `<version>` tags — omitting `<sepolicy>` is a documented VINTF mistake).
- `DEVICE_MATRIX_FILE` **removed** (deleted `compatibility_matrix.xml`). The
  stock device matrix mandates `vendor.mediatek.framework.mtksf_ext` /
  `vendor.mediatek.hardware.mbrainj` (need the `mediatek-common` framework jar,
  not built) and the seeded yunluo copy mandated dead HIDL `sensorservice@1.0`
  — either would fail the boot-time VINTF check. LineageOS' default device
  matrix is used.
- **Power HAL kept as the stock MediaTek blob**, `pixel-libperfmgr` dropped:
  `power-mediatek.xml` already declares `android.hardware.power/IPower/default`,
  so adding pixel-libperfmgr would double-declare IPower and race two services.
- `sepolicy/vendor/file_contexts` rewritten to taiko's real blob names:
  added `keymint@4.0-service.mitee` (mtk base only labels `@3.0` → keystore
  would run unlabeled), `lights-service.mediatek`, `dumpstate-service.xiaomi`;
  dropped the yunluo-only `light-service.xiaomi` / `sensors-service.xiaomi-multihal`
  / `power-service.pixel-libperfmgr` lines.
- `genfs_contexts` is still yunluo's hardware — sysfs paths (charger i2c, wakeup
  nodes, GPU) will mismatch and must be regenerated from first-boot denials.

### Round 1

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

- Dalvik heap: device is **4 GB RAM**. LineageOS `frameworks/native` has no
  `tablet-*-4096` profile (Lineage tablet presets stop at 2048), so `device.mk`
  inherits Lineage's `phone-xhdpi-4096-dalvik-heap.mk` (growthlimit 192m,
  util 0.6 — tighter than HyperOS stock's 256m/0.75).

Still open: see TODO.

## TODO before a flashable build

- [x] `BOARD_SUPER_PARTITION_SIZE` — from `MT6789_Android_scatter.txt`:
      `super partition_size = 0x2c0000000` = 11811160064 (11 GiB). Group =
      super − 4 MiB = 11806965760.
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
