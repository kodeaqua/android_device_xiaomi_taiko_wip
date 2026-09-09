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
# in a LineageOS 23.2 (Android 16) tree, with this repo at device/xiaomi/taiko
source build/envsetup.sh
./device/xiaomi/taiko/extract-files.py <path-to-ota.zip>   # -> vendor/xiaomi/taiko
breakfast taiko && brunch taiko                            # 23.2: codename only
```

`breakfast taiko` builds `lunch lineage_taiko-bp4a-userdebug` (release token
`bp4a` from `vendor/lineage/vars/aosp_target_release`). Kernel = prebuilt
`boot.img` (`TARGET_NO_KERNEL`). `extract-files.py` runs with `check_elf=True`
and lists blobs with missing `NEEDED` libs — add `blob_fixups` and re-extract.
`./setup-makefiles.py` regenerates `Android.bp` from `proprietary-files.txt`
*without* re-copying blobs (use it after line removals).

## Status (2026-09-09)

Pushed to `kodeaqua/android_device_xiaomi_taiko_wip` `lineage-23.2`. Passed
soong bootstrap + kati + ninja (36 fix rounds, logged
below); at ~82% ninja (a check_elf_file on stale AEE dumper blobs, Round 36); Round 35 cleared OTA-time `checkvintf`
(`Package OTA` / `ota_from_target_files` → `check_target_files_vintf.py`).
Build runs on a separate machine — errors are pasted in and fixed here. Camera
enabled; `configs/audio|media|wifi` = taiko's own; `BOARD_SUPER_PARTITION_SIZE`
= 11 GiB from the scatter. See the workspace `../../../CLAUDE.md` "Build status"
for the fix-class cheat sheet.

## Verifying a build

After `brunch taiko`, from the build root:

```
./device/xiaomi/taiko/tools/verify-build.sh            # fast
./device/xiaomi/taiko/tools/verify-build.sh --deep     # + per-.so unresolved-NEEDED scan
./device/xiaomi/taiko/tools/verify-build.sh --flash    # print the fastboot recipe
```

Sections: build artifacts + **partition sizes vs the scatter** (won't overflow
on flash) · **generated-makefile hygiene** (no `.so`/`.apk` in
`PRODUCT_COPY_FILES` - the Round-49 regression) · **round-by-round drop
verification** (every blob dropped for a source module must exist in the built
image - FAIL = restore that `proprietary-files.txt` line) · kept MTK/Xiaomi
blobs + dropped-on-purpose absent · **MVPU island** (`libmvpu_wrapper` +
`libswtcc`/`libultrahdr_mtk`) · VINTF (device manifest HALs, the Round-35
proprietary-HAL FCM, `checkvintf --check-compat`) · kernel modules
(`modules.load` ↔ `.ko`, `modules.dep`) · fstab (dual-fs, metadata enc, SD-path
fix, checkpoint, `system_dlkm` AVB chain) · recovery-in-vendor_boot · AVB
(`avbtool`: flags=3, rollback locations, chained descriptors) · build.prop
(Round 29-30: SPL, `ro.product.vendor.name`, no `sdk_full` dup,
`ab_ota_partitions` full list) · SELinux (precompiled hash match) · APEX.
`avbtool` / `checkvintf` on `$PATH` unlock the AVB and check-compat sections.

## AOSP-core audit (source.android.com/docs/core)

Checked against: generic-boot, vendor-boot-partitions, gki-partitions,
dynamic-partitions, loadable-kernel-modules, vndk build-system, VINTF objects,
SELinux device policy.

### Round 49 - ELF in PRODUCT_COPY_FILES: revert `check_elf=False`

Past kati. ninja `Check non-ELF`:
`vendor/lib*/libmvpuop_mtk_cv.so: error: found ELF prebuilt in PRODUCT_COPY_FILES,
use cc_prebuilt_binary / cc_prebuilt_library_shared instead` (whole `libmvpu_*`
cluster).

`ExtractUtilsModule(check_elf=False)` (Round 45) doesn't only skip the check - it
also demotes inter-dependent `.so` clusters (the MTK MVPU OpenCL/NN-compiler
island - a 43-lib DAG, no cycles) from `cc_prebuilt_library_shared` modules to
raw `PRODUCT_COPY_FILES` entries, which A16 rejects.

**Reverted `check_elf` to `True`** and appended `;DISABLE_CHECKELF` to every ELF
line in `proprietary-files.txt` (1321 total). The per-line flag sets
`check_elf_files: false` on the generated module *without* the COPY_FILES
demotion - same "no check_elf grind", correct module shape. First tried dropping
the `libmvpu*` cluster (87 lines) but `libswtcc` / `libultrahdr_mtk` (VPP HDR
metadata / UltraHDR) hard-`DT_NEEDED` `libmvpu_wrapper`, so it's kept - it just
had to stay a module set, not COPY_FILES.

`./setup-makefiles.py` is enough (`check_elf` flag + line flags are makefile
regen, no re-copy).

### Round 48 — kati "overriding commands": batch of AOSP-source `/vendor` blobs

`installs-lineage_taiko.mk` vs a make-side (`build/make/core/Makefile:148`)
install rule. Ran on the build box:
`awk -F: '/\/vendor\// && / : /' installs-lineage_taiko.mk ... | comm -12` with
`proprietary-files.txt` install paths. Everything that turned out to be an
AOSP-source component HyperOS ships verbatim in `/vendor`:

- `vendor/lib*/soundfx/lib{aecsw,agc1sw,agc2sw,bassboostsw,bundleaidl,downmixaidl,
  dynamicsprocessingaidl,envreverbsw,equalizersw,extensioneffect,
  loudnessenhanceraidl,nssw,preprocessingaidl,presetreverbsw,reverbaidl,
  virtualizersw,visualizeraidl,volumesw}.so` — `hardware/interfaces/audio/aidl/
  default/*` DOES build & install these to `/vendor/lib*/soundfx/` after all
  (corrects the Round-38 "enabled:false" read).
- `vendor/lib*/mediadrm/lib{drmclearkeyplugin,mockdrmcryptoplugin}.so`,
  `vendor/lib*/mediacas/libclearkeycasplugin.so` — `frameworks/av` clearkey.
- `vendor/lib*/libwpa_client.so` — `external/wpa_supplicant_8` (source
  supplicant, since Round 28).
- `vendor/lib*/libkeystore-wifi-hidl.so` — `system/security` (Round 28 class).
- `vendor/lib*/libhidparser.so` — `frameworks/native`.
- `vendor/apex/com.android.hardware.cas.apex`,
  `com.google.android.widevine.nonupdatable.apex` — built APEXes.
- `vendor/app/{NetworkStack,Tethering}*ResOverlay/*.apk` (5) — mainline RROs.
- `vendor/framework/androidx.camera.extensions.impl.dummy.jar` — `frameworks/ex`.
- `vendor/etc/vintf/manifest/android.hardware.audio.effect.service-aidl.xml` —
  `audio/aidl/default` (same as Round 18's audio.core fragment). Dropped the
  blob; added the `audio.effect` / `IFactory/default` HAL to
  `configs/vintf/manifest_audio_aidl.xml` (2nd `DEVICE_MANIFEST_FILE`).

57 blob lines dropped. The MTK/Xiaomi `vintf/manifest/*.xml` fragments that also
showed in the raw `comm` are blob-only (single install rule) - false positives,
left alone.

Re-run: `./setup-makefiles.py`.

### Round 47 — kati "overriding commands": `sensors.dynamic_sensor_hal`

`overriding commands for target '.../vendor/lib/hw/sensors.dynamic_sensor_hal.so',
previously defined at installs-lineage_taiko.mk`. The
`android.hardware.sensors-service.multihal` source module we added in Round 18
`required`s `sensors.dynamic_sensor_hal` (from
`frameworks/native/services/sensorservice/dynamic_sensor`), which installs to
that exact path. Dropped the two blob lines - taiko's stock
`/vendor/etc/sensors/hals.conf` only lists
`android.hardware.sensors@2.X-subhal-mediatek.so` + `sensors.camera.light.so`,
so the dynamic-sensor sub-HAL is unused here anyway; source covers the install.

Re-run: `./setup-makefiles.py`.

### Round 46 — kati "overriding commands": CHRE / contexthub source vs blobs

Past ninja (`check_elf=False` was a warning, not an error - the build ran
through). kati: `overriding commands for target
'.../vendor/bin/hw/android.hardware.contexthub-service.tinysys', previously
defined at installs-lineage_taiko.mk:76665` - i.e. a soong **source** module
already installs it.

`system/chre` builds `android.hardware.contexthub-service.tinysys` plus its
`chre_atoms_log` / `chremetrics-cpp` (`vendor_available`) libs from source; the
HyperOS blobs at those exact paths collide (the service even DT_NEEDEDs the two
libs). Dropped all three from `proprietary-files.txt` - the source CHRE stack
provides them. Same class as Rounds 18-28 (HyperOS ships AOSP-source components
verbatim as `/vendor` blobs).

Re-run: `./setup-makefiles.py`.

### Round 45 — `check_elf=False` module-wide (end the check_elf tail)

`libneuron_adapter_mgvi` (NeuroPilot/APU adapter): undefined
`AHardwareBuffer_{describe,lock,unlock}@LIBNATIVEWINDOW` (versioned, arm64) +
`DT_NEEDED libnativewindow/libz/liblog not in shared_libs` + an unparseable
`DT_STRTAB` on the arm build. Same benign class as Rounds 38-44, now in the
NeuroPilot / APU / `libapusys` / `libneuron_runtime` / `libvpu` cluster - and
that cluster is as mutually-tangled as the camera one.

Rounds 36-44 disabled ~265 lines one/few at a time; the tail is clearly
open-ended (every large MTK vendor sub-cluster does this). Flipped
`ExtractUtilsModule(check_elf=False)` in `extract-files.py` - `check_elf_file` is
off for the whole `vendor/xiaomi/taiko` module now, the choice most MTK
LineageOS trees make for a blob set this size. The ~265 `;DISABLE_CHECKELF`
suffixes are left in place as no-op markers of the known-quirky blobs.
`blob_fixups` (the real AIDL-version-skew `replace_needed` patches) run at
extract time and are unaffected. A genuinely missing `DT_NEEDED` now surfaces as
a runtime `dlopen` failure in logcat instead of a build error - acceptable
trade for a bring-up.

Re-generate with `./setup-makefiles.py` (module-config change, no re-extract).

### Round 44 — blanket `DISABLE_CHECKELF` the camera blob cluster

Rounds 36-43 whittled `check_elf_file` failures one/few at a time; Round 44 was
another (`libmtkcam_custom.sensorprovider` -> undefined `NSCam::Thread::
getThisThreadId()`). The MTK ISP6s + Xiaomi MiCam blob set (~180 libs) is one
mutually-referencing web of `NSCam::` / `NS3Av3::` / `NSIspTuning::` symbols
spread across dozens of libs; `check_elf_file`'s per-module `--shared-lib`
closure never contains every sibling, so it will keep flagging cross-lib
`NSCam::` symbols indefinitely. Every MTK LineageOS tree blanket-disables its
camera cluster for exactly this (yunluo included).

`readelf`-swept + name-matched every camera lib in `proprietary-files.txt`
(`lib3a.*`, `libcam.*`, `libmtkcam*`, `libcameracustom*`, `libcamalgo*`,
`libfeature_*`, `libdip*`, `libimageio*`, `libanc_*`, `libmialgo*`, `hq_algo*`,
`*_imgsensor*`, `*mipi_raw*`, `*Pdaf*`, the MTK camera AIDL sub-HAL impls, …) and
`;DISABLE_CHECKELF`'d all 184. Verified the sweep touched **no** audio / wifi /
display / bluetooth / keymint / composer / gralloc core lib. Total
`DISABLE_CHECKELF` lines: 265.

This is purely a build-time check bypass - it doesn't change the blobs or the
Round 17 camera-common downgrade / Round 43 orphan drop. Camera correctness is
still a first-boot task.

### Round 43 — drop the 2 genuinely-orphaned camera libs (narrowed from Round 42)

Follow-up analysis of the Round 42 set: of the 52 libs with undefined
`NSCam::IMetadata` symbols, only **two** actually reference the *template* API
(`push_back<int,uchar>`, `getEntry<int>`, `setEntry<T>`, `itemAt<int>` — GLOBAL,
not WEAK, so hard `dlopen` failures): `libmtkcam.mcsspolicy.so` and
`libmtkcam_capture_request_monitor.so`. The other 50 use the plain overload API
that our `libmtkcam_metadata.so` blob provides — they're fine, the Round 42
`;DISABLE_CHECKELF` on them is just belt-and-braces (yunluo blanket-disables its
camera cluster too).

`readelf -d` across the whole extracted vendor tree: **nothing** DT_NEEDED-links
or even string-references those two — they're `dlopen`-by-name plugins (pipeline
MCSS policy / a capture-request debug monitor) with no in-vendor consumer (a
MiCam APK would load them). Dropped both from `proprietary-files.txt`. The core
camera stack is now metadata-ABI-consistent (old overload API throughout). No
`hardware/mediatek` camera source exists to relink against; this dump ships only
the old-API `libmtkcam_metadata`, so those two Xiaomi plugins (built against a
newer SDK-drop header) simply can't be carried.

### Round 42 — `check_elf_file`: MTK camera `NSCam::IMetadata` template ABI split (52 blobs)

`libmtkcam.mcsspolicy` / `libmtkcam_capture_request_monitor` (+ 50 more camera
libs): `error: Unresolved symbol: _ZN5NSCam9IMetadata6IEntry9push_backIihEE...`
= `NSCam::IMetadata::IEntry::push_back<int,unsigned char>(...)` etc.

Not a benign check_elf quirk this time: our `libmtkcam_metadata.so` blob exports
the **non-template** overloads (`push_back(int const*, size_t, Type2Type<int>)`),
while these consumers were compiled against a header where `push_back` /
`getEntry` / `setEntry` / `itemAt` are **templates** (`push_back<T0,T1>`). HyperOS
mixed a `libmtkcam_metadata` from one SDK drop with Xiaomi camera libs from
another. A genuine intra-vendor ABI split — but camera is deferred (Path A), so
`readelf`-swept every PF blob for undefined `NSCam::IMetadata` template syms and
`;DISABLE_CHECKELF`'d all 52 in one pass (vs ~50 more one-at-a-time rounds). The
provider `libmtkcam_metadata.so` is untouched. **Camera metadata read/write will
likely fail at runtime** until the camera stack is realigned (matching
`libmtkcam_metadata` blob / newer dump / drop `mcsspolicy`+`capture_request_
monitor`) - a post-boot camera task, not a boot blocker.

### Round 41 — proactively adopt yunluo's `DISABLE_CHECKELF` set

Rounds 36-40 were one-at-a-time `check_elf_file` failures on quirky MTK/Xiaomi
blobs. yunluo (the proven MT6789 23.0 template) `;DISABLE_CHECKELF`s 20 lines;
we had matched only the `.ca7` codec cluster. Applied the rest that exist in our
tree, un-disabled: `android.hardware.camera.provider@2.6-impl-mediatek.so`
(HIDL camera provider), `libmtkcam_stdutils.so` (lib+lib64), `libthha.so`
(lib+lib64, MTK thermal-HAL-helper used by the codec OAL), `libvcodec_oal.so`
(lib+lib64, MTK OMX abstraction), `libneuralnetworks_sl_driver_mtk_prebuilt.so`.
Same rationale as Round 38 - these are old MTK blobs whose ELF trips check_elf
(compiler-rt builtins, versioned syms, NDK STL soname) but resolve at runtime.

### Round 40 — `check_elf_file`: `libmialgo_*` NEEDED `libc++_shared.so`

`//vendor/xiaomi/taiko:libmialgo_{utils,sd,ai_vision} check elf file`:
`error: DT_NEEDED "libc++_shared.so" is not specified in shared_libs.`

The `extract-files.py` `lib_fixups` `("libc++_shared",) -> "libc++"` rewrites the
*generated `shared_libs`* list, but `check_elf_file` compares the blob's real
`DT_NEEDED` (still literally `libc++_shared.so`) against it, so `libc++` !=
`libc++_shared` still fails. `libc++_shared.so` is the NDK STL soname; neither
the dump nor our tree ships `vendor/lib*/libc++_shared.so` (only 3 blobs need it,
all Xiaomi MiAlgo camera-AI post-processing: `libmialgo_utils/sd/ai_vision`).
`;DISABLE_CHECKELF` on the three. **Runtime:** these dlopen only from the MiCam
algo path (night mode / AI scene / bokeh); if the vendor linker namespace can't
resolve `libc++_shared.so` they just don't load — no effect on core camera or
boot. Proper post-boot fix: `blob_fixup().replace_needed("libc++_shared.so",
"libc++.so")` + full re-extract, or ship a renamed `libc++_shared` vendor blob.

### Round 39 — `check_elf_file`: `libmcve` versioned `AHardwareBuffer_*@LIBNATIVEWINDOW`

`//vendor/xiaomi/taiko:libmcve check elf file`: `error: Unresolved symbol:
AHardwareBuffer_{allocate,lock,release,unlock}@LIBNATIVEWINDOW`.

`libmcve.so` (MTK video-encode lib) references these NDK gralloc APIs with the
bare `LIBNATIVEWINDOW` symbol-version tag; lineage-23.2's `libnativewindow.so`
(in the `--shared-lib` list) exports them under a newer version node, so
`check_elf_file`'s versioned lookup misses. The unversioned
`AHardwareBuffer_getNativeHandle` in the same lib resolves fine, as do all its
`@LIBC` refs. `AHardwareBuffer_*` are API-26 core NDK, present at runtime.
`;DISABLE_CHECKELF` on the one line. (`libmiXmlParser` in the same batch only has
`@LIBC`/`@LIBLOG` refs and passes.)

### Round 38 — `check_elf_file`: legacy `.ca7` SW video codecs, `__aeabi_*`

`//vendor/xiaomi/taiko:libHEVCdec_sa.ca7.android check elf file [arm]`:
`error: Unresolved symbol: __aeabi_idiv / __aeabi_idivmod / __aeabi_uidiv /
__aeabi_uidivmod`.

These are ARM EABI integer-division compiler-runtime builtins. The `.ca7`
(Cortex-A7-era) MediaTek software video codecs were built with a toolchain that
pulled them from `libgcc`; `check_elf_file` for a prebuilt has no compiler-rt in
its `--shared-lib` list, so it flags them — but bionic `libc.so` exports
`__aeabi_*` on 32-bit arm, so they resolve fine at load time. This is the exact
cluster yunluo `;DISABLE_CHECKELF`s. Applied `;DISABLE_CHECKELF` to all 17
`.ca7` lines (`libHEVCdec_sa`, `libh264dec_s{a,d,e}`, `libhevce_sb`,
`libmp4enc_sa`, `libvp8dec/enc_sa`, `libvp9dec_sa` × lib/lib64). These are
fallback SW codecs for the MTK HW vcodec — kept, not dropped.

### Round 37 — `check_elf_file`: `audio.core-impl-mediatek` vs source `libaudioutils`

`//vendor/xiaomi/taiko:android.hardware.audio.core-impl-mediatek check elf file`
(arm + arm64): `error: Unresolved symbol:
_ZN7android11audio_utils21mutex_get_enable_flagEv` (+ `mutex_impl<AudioMutex
Attributes>::get_registry()` / `::get_mutex_stat_array()`).

All three are `audio_utils` mutex deadlock-detection / lock-stats symbols. The
MTK AIDL audio-core HAL blob was built against HyperOS's `libaudioutils.so`,
which exports them; lineage-23.2's `system/media` `libaudioutils.so` (passed to
`check_elf_file` via `--shared-lib`) does not — the instrumentation is
header-inlined / static there, not a shared export. Not a version skew, an
export-surface change. `readelf` sweep: this is the **only** blob with these
UND syms (the sibling `audio.effect` / `bluetooth.audio` / `power` /
`soundtrigger3` MTK impls resolve cleanly).

`android.hardware.audio.core-impl-mediatek.so` provides `audio.core/IModule` —
essential, no source replacement — so `;DISABLE_CHECKELF` on both
`proprietary-files.txt` lines (same mechanism yunluo uses ~10×). **First-boot
risk:** if the inlined `audio_utils::mutex` ctor path actually calls
`mutex_get_enable_flag()`, the HAL fails to `dlopen` → no MTK audio core →
device still boots, audioserver just has no module. Post-boot fix options:
cherry-pick the `system/media` commit that keeps these exported, a stub shim
lib via `blob_fixup().add_needed()`, or a newer HyperOS audio HAL.

### Round 36 — `check_elf_file`: AEE v2 dumpers vs the 23.2 source `libaedv`

`//vendor/xiaomi/taiko:aee_dumpstatev_v2 check elf file` +
`:aee_aedv64_v2` (and `aeev_v2` has the same 32 unresolved syms):
`error: Unresolved symbol: aee_chmod / aee_fprintf / fop_file_write_string /
dop_create_dirs / rtt_dump_all_backtrace_by_name / ...`.

These MTK "AEE" (Android Exception Engine) crash-dump helper binaries were built
against HyperOS's `libaedv.so`, which exports a large `aee_*` / `fop_*` / `dop_*`
/ `rtt_*` utility surface. `libaedv` is one of the source-collision modules
(`device.mk` builds `hardware/mediatek/libaedv`), and the lineage-23.2 source
`libaedv` exports **none** of those symbols — a whole different API, not a
version skew. `check_elf_file` (`check_elf: true` on the extracted prebuilt)
fails hard.

Dropped `vendor/bin/{aee_aedv64_v2,aee_dumpstatev_v2,aeev_v2}` +
`vendor/etc/init/aee_aedv64_v2.rc` from `proprietary-files.txt`. Kept
`vendor.mediatek.hardware.aee@V1-service` (the AIDL AEE HAL - `readelf` shows it
links `libdumpstateutil`/`libbase`, **not** `libaedv`, so it builds and still
serves `IAee/AEE`), `libaedv`/`libladder` (source), `aee-commit`/`aee-config`.
`rootdir/etc/init.aee.rc`'s `start aee_aedv64_v2` becomes a no-op, exactly like
its already-dangling `start aee_aedv` / `start aee_aedv64` (host_init_verifier
does not error on `start` of an undefined service). Android's native
`tombstoned` / `crash_dump` cover crash forensics; MTK's proprietary AEE
extended dumps are debug-only.

### Round 35 — OTA-time `checkvintf --check-compat`: proprietary vendor HALs not in any FCM

Ninja finished the whole compile; `Package OTA` (`ota_from_target_files` →
`check_target_files_vintf.py` → `checkvintf --check-compat`) fails:

```
ERROR: files are incompatible: The following instances are in the device
manifest but not specified in framework compatibility matrix:
    vendor.dolby.dms.IDms/default (@1)
    vendor.mediatek.hardware.mtkpower.IMtkPowerService/default (@3)
    vendor.xiaomi.hardware.aidl.mtdservice.IMTService/default (@1)
    ... (22 instances total)
    vendor.xiaomi.sensor.citsensorservice.ICitSensorService/default (@1)
```

At FCM level 202504 `checkvintf` requires **every** device-manifest HAL instance
(here: `configs/vintf/manifest.xml` + the blob `vendor/etc/vintf/manifest/*.xml`
fragments — `power-mediatek.xml`, `dms-service.xml`, `vendor.xiaomi.hardware.*`,
`manifest_mtkblackbox.xml`, `vendor.xiaomi.hw.touchfeature-service.xml`, …) to be
matched by an entry in some framework compatibility matrix. The MediaTek
`vendor.mediatek.hardware.*` HALs are covered by
`hardware/mediatek/vintf/mediatek_framework_compatibility_matrix.xml` (already
wired), **except** `mtkpower/IMtkPowerService`: that FCM has it at `version 1-2`
while the `power-mediatek.xml` blob advertises `@3` (range max is enforced —
`3 > 2` ⇒ incompatible). The 21 proprietary `vendor.xiaomi.*` / `vendor.dolby.*`
HALs are in no shared matrix at all.

Fix (same philosophy as Round 16 — keep it in the device tree, don't touch the
shared MTK/Lineage matrices): new
`configs/vintf/device_framework_matrix.xml` (`<compatibility-matrix
type="framework">`), one `<hal format="aidl" optional="true">` per HAL with the
exact interface names + versions from the error (19 `<hal>` blocks, 22
`<interface>` — `mrm` has 3, `misys.common` has 2), plus a
`vendor.mediatek.hardware.mtkpower` / `IMtkPowerService` `version 1-3` entry that
widens the accepted range. Wired via `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE
+=` in `BoardConfig.mk`, listed before the MediaTek FCM. `optional="true"`
everywhere — these are device-specific HALs, the check only needs them *allowed*,
not *mandated*. Versions use `1-N` ranges (N = advertised version) for headroom.

### Round 34 — drop the legacy HIDL AEE service (kept the AIDL one)

`host_init_verifier: vendor.mediatek.hardware.aee@1.1-service.rc: invalid
interface in service 'aee.log-1-1': Interface is not in the known set of
hidl_interfaces: 'vendor.mediatek.hardware.aee@1.0::IAee' / '@1.1::IAee'.`

`host_init_verifier` validates every `interface <pkg>@<v>::<I>` line in an
installed `.rc` against a `hidl_interface` module in the tree. On Android 16 MTK
migrated AEE from HIDL to AIDL, and `hardware/mediatek` 23.2 ships no
`vendor.mediatek.hardware.aee` HIDL. HyperOS still bundled **both** services:

| kept (AIDL) | dropped (HIDL) |
|---|---|
| `vendor/bin/hw/vendor.mediatek.hardware.aee@V1-service` | `…aee@1.1-service` |
| `…aee@V1-service.rc` (`interface aidl …aee.IAee/AEE`) | `…aee@1.1-service.rc` (`@1.0::IAee` / `@1.1::IAee`) |
| `vendor/lib64/vendor.mediatek.hardware.aee-V1-ndk.so` | `…aee@1.0.so`, `…aee@1.1.so` |

`configs/vintf/manifest.xml` already declares only the AIDL AEE
(`format="aidl"`, `IAee/AEE`). ELF reverse-dep scan: the HIDL cluster
(`aee@1.1-service` → `aee@1.0.so`/`aee@1.1.so`; `aee@1.0.so` → `aee@1.1.so`) is
fully self-contained — nothing else in the blob set links it. The AIDL
`@V1-service.rc` passes host_init_verifier (its `IAee` shows in the build's
"Couldn't find AIDL metadata … expected for prebuilt interfaces" INFO list,
which is non-fatal).

Removed the 4 HIDL lines from `proprietary-files.txt`, ran `./setup-makefiles.py`,
and deleted the orphaned files from the extracted tree. A full-tree scan of the
blob `.rc` set for `interface <pkg>@<v>::` found `aee@1.1-service.rc` was the
only one.

### Round 33 — `host_init_verifier`: blob service with no `user`

`Copy init script ... vendor.xiaomi.hw.touchfeature-service.rc`:
`host_init_verifier: ... 149: No user specified for service
'touch-kmsg-init-sh', so it would have been root. Failed to parse init
scripts with 1 error(s).`

Android 16's `host_init_verifier` (run on every installed `*.rc` via the
`prebuilt_etc` copy rule) **errors** on a service with no explicit `user` line
(older releases only warned). The stock touchfeature rc leaves
`touch-kmsg-init-sh` implicit-root; its sibling `panel-info-sh` (same file, same
`seclabel u:r:vendor_touch_init_shell:s0`) sets `user root`.

`extract-files.py` `blob_fixups` `regex_replace` on
`vendor/etc/init/vendor.xiaomi.hw.touchfeature-service.rc` inserts `user root`
into that one service block. A full-tree scan of the extracted blob `.rc` set
(services with no `user:` line) found this as the only one. The already-extracted
`vendor/xiaomi/taiko/...` copy was patched in place too so the in-flight build
continues without a re-extract; a fresh `./extract-files.py <ota.zip>` reproduces
it from the fixup.

### Round 32 — device `file_contexts` re-labels an MTK-base path

`//system/sepolicy:file_contexts.device.sorted.tmp`:
`Multiple different specifications for
/(vendor|system/vendor)/bin/hw/android\.hardware\.lights-service\.mediatek
(u:object_r:hal_light_default_exec:s0 and u:object_r:mtk_hal_light_exec:s0)`.

The `file_contexts.device.tmp` genrule concatenates every
`BOARD_VENDOR_SEPOLICY_DIRS` + AOSP `file_contexts` and rejects two rows for the
same path regex with different types (byte-identical is fine; different is a hard
error, and `checkpolicy`/`sefcontext_compile` aborts on the first one).

`device/mediatek/sepolicy_vndr/base/vendor/file_contexts:871` already labels
`android.hardware.lights-service.mediatek` -> `mtk_hal_light_exec` (a full domain
- `base/vendor/mtk_hal_light.te`: `hal_server_domain(mtk_hal_light, hal_light)`
+ `init_daemon_domain`). The Round-2 device `file_contexts` re-declared the same
binary as the generic `hal_light_default_exec`. Dropped the device line (comment
kept as a do-not-re-add marker).

Re-checked the other Round-2 device `file_contexts` additions vs the MTK base:
`keymint@4.0-service.mitee` (base only has `@3.0`/`@1.0`, and to the same
`hal_keymint_default_exec` type anyway - no clash), `dumpstate-service.xiaomi`,
`mi_thermald`, the `mi_display` + touch-gesture sysfs nodes - none are in the
base, no conflict.

### Round 31 — `generated_kernel_includes` vs no kernel source

`//vendor/lineage/build/soong:generated_kernel_includes generate` fails:
`make: *** kernel/xiaomi/taiko: No such file or directory.  Stop.`

LineageOS' `generated_kernel_includes` `lineage_generator` (a Soong genrule)
runs `make -C $(TARGET_KERNEL_SOURCE) O=<genDir> ARCH=arm64 headers_install`
whenever a built module lists the `generated_kernel_headers` `header_lib`. It is
**not** gated by `TARGET_NO_KERNEL` (that only gates the make-side
`vendor/lineage/build/tasks/kernel.mk`). `TARGET_KERNEL_SOURCE` defaults to
`kernel/$(TARGET_DEVICE_DIR)` = `kernel/xiaomi/taiko`, which doesn't exist on a
prebuilt-kernel tree.

Consumer trace (`grep -rn generated_kernel_headers device/ hardware/`):
`libjni_poweroffalarm` (`hardware/mediatek/packages/PowerOffAlarm`, pulled by
`PRODUCT_PACKAGES += PowerOffAlarm` in `device.mk`) and
`hardware/xiaomi/fingerprint` (not built - taiko has no fingerprint). So
`PowerOffAlarm` is the trigger. Its JNI includes only `<linux/ioctl.h>`,
`<linux/rtc.h>`, `<sys/timerfd.h>` - all from the bionic sysroot, no device
kernel headers needed. `TARGET_PREBUILT_KERNEL_HEADERS` only feeds the sibling
`prebuilt_kernel_includes` module, which `PowerOffAlarm` does not reference, so
it can't redirect this.

Fix: `TARGET_KERNEL_SOURCE := $(DEVICE_PATH)/kernel-headers` (BoardConfig.mk) ->
a stub `kernel-headers/Makefile` whose `headers_install` target just
`mkdir -p "$(O)/usr/include"`. The genrule succeeds with an empty export dir;
`clean_headers.sh`'s `clean_header.py -u .../asm/signal.h` scrub only *warns*
(non-fatal) in update mode when the tree is bare (`print_error` panics only when
`no_update`). `VERSION = 6` / `PATCHLEVEL = 12` in the stub keep
`BoardConfigKernel.mk`'s `TARGET_KERNEL_VERSION` derivation = `6.12` (stock GKI),
so `TARGET_KERNEL_NO_GCC` stays auto-true and no GCC-prebuilt toolchain paths
are wired for a build that never compiles a kernel.

### Round 30 — dump props colliding with Soong `gen_build_prop` output

`gen_build_prop --partition=product ...` → `post_process_props`:
`error: found duplicate sysprop assignments: ro.product.build.version.sdk_full=36.1
/ =36.0` and `ro.config.notification_sound=unknown / =Argon.ogg`.

`build/make/tools/post_process_props.py` `override_optional_props()` hard-errors
when a prop has >1 non-optional (`=`, not `?=`) assignment **with differing
values** (identical values are silently deduped, `?=` defers). The
`configs/props/*.prop` files are HyperOS-dump output, and on Android 16 Soong's
`gen_build_prop.py` now *generates* a swathe of `ro.*.build.*` / `ro.product.*`
keys itself — feeding the dump's copies back in as input collides. Same class as
Round 29.

Removed the stale dump lines the build now owns:

| prop | in | dump value | build (`gen_build_prop.py`) |
|---|---|---|---|
| `ro.build.version.sdk_full` | system.prop | `36.0` | `36.1` (trunk minor SDK) |
| `ro.system.build.version.sdk_full` | system.prop | `36.0` | `36.1` |
| `ro.system_ext.build.version.sdk_full` | system_ext.prop | `36.0` | `36.1` |
| `ro.product.build.version.sdk_full` | product.prop | `36.0` | `36.1` |
| `ro.vendor.build.version.sdk_full` | vendor.prop | `36.0` | `36.1` |
| `ro.odm.build.version.sdk_full` | odm.prop | `36.0` | `36.1` |
| `ro.config.notification_sound` | product.prop | `unknown` | `Argon.ogg` (`vendor/lineage/config/common_mobile.mk:13`, hard `=`, file copied to `/product`) |
| `ro.vendor.build.ab_ota_partitions` | vendor.prop | `boot,product,system,vendor` | sorted 13-entry list from `AB_OTA_PARTITIONS` (`gen_build_prop.py:499`) — would fail at `vendor-build.prop` |

Cross-checked every dump prop key against `gen_build_prop.py` +
`sysprop_config.mk`. **Left alone** (build emits the *same* value → deduped, no
error): `ro.product.page_size=4096`, `ro.product.build.16k_page.enabled=false`,
`ro.product.cpu.pagesize.max=16384`, `ro.product.build.no_bionic_page_size_macro`,
`ro.vendor.build.dont_use_vabc=true` (only emitted if `DontUseVabcOta`, which
taiko doesn't set — the dump line is the sole provider; deliberate keep per
Round 26). `ro.config.ringtone=unknown` stays: `full_base.mk` only sets it `?=`,
so our `=` wins with no conflict (candidate for the post-boot MIUI-prop trim).

### Round 29 — legacy `PRODUCT_BUILD_PROP_OVERRIDES` keys

`//build/soong:ramdisk-build.prop ... Key "PRODUCT_NAME" isn't a valid prop
override` from `gen_build_prop`.

Android 16 generates `build.prop` in Soong. `build/soong/scripts/gen_build_prop.py`
`override_config()` iterates `PRODUCT_BUILD_PROP_OVERRIDES` and **hard-exits** if
a key is not already a field in the product-config dict — the legacy make-var
names (`PRODUCT_NAME`, `TARGET_DEVICE`, `PRIVATE_BUILD_DESC`) are not. The seed
`lineage_taiko.mk` carried the pre-A15 idiom. Mapped to the current field names
(cf. `device/google_car/tangorpro_car`):

| old | new | prop |
|---|---|---|
| `PRODUCT_NAME=taiko` | `DeviceProduct=taiko` | `ro.product.<part>.name` |
| `TARGET_DEVICE=taiko` | *(dropped)* | `DeviceName` is already `taiko` |
| `PRIVATE_BUILD_DESC=…` | `BuildDesc=…` | `ro.build.description` |

`BUILD_FINGERPRINT :=` is untouched — still honored (`build/make/core/config.mk`
writes it to `build_fingerprint-$(TARGET_PRODUCT).txt`, which `gen_build_prop`
reads via `--build-fingerprint-file`).

### Round 28 — `prefer: true` blob shadowing the source `libwifi-hal`

`hardware/interfaces/wifi/aidl/default/wifi_legacy_hal.h:20:10: fatal error:
'hardware_legacy/wifi_hal.h' file not found` while compiling
`android.hardware.wifi-service-lib` (`aidl_struct_util.o`).

Commit 4277d60 switched the wifi HAL to the source `android.hardware.wifi-service`
(V4) + source `libwifi-hal` (`frameworks/opt/net/wifi/libwifi_hal`), which
re-exports `wifi_legacy_headers` (→ `hardware_legacy/wifi_hal.h`). But
`proprietary-files.txt` still listed `vendor/lib64/libwifi-hal.so` — HyperOS's
verbatim copy of that same AOSP lib. `extract-utils` emits every generated
prebuilt with `prefer: true`, and Soong's prebuilt/source mutator lets a
`prefer: true` prebuilt replace the same-named source module **globally, across
namespaces**. So `android.hardware.wifi-service-lib` linked the bare prebuilt,
which carries no `export_include_dirs` and no `wifi_legacy_headers` re-export —
verified from the ninja `cFlags1`: neither
`-Iframeworks/opt/net/wifi/libwifi_hal/include` nor
`-Ihardware/interfaces/wifi/legacy_headers/include` was on the compile line
(while `libwifi-system-iface`'s exported include *was*).

Dropped `vendor/lib64/libwifi-hal.so`. Dropped
`vendor/lib64/libkeystore-engine-wifi-hidl.so` in the same pass — identical
class (a `vendor_available` source module of the same name in
`system/security/keystore-engine`, already built as a vendor variant, silently
`prefer`-overridden by the blob). Both source modules build fine.
`./setup-makefiles.py` regenerated `vendor/xiaomi/taiko/Android.bp`.

Lesson: a blob whose basename equals a source `cc_library` name does **not**
always hard-error with "multiple modules named" — with `prefer: true` it wins
silently and you only find out when its missing `export_*` breaks a consumer.
Same fix class as Rounds 8-14 (HyperOS ships AOSP-built libs as `/vendor` blobs).

### Round 27 — duplicate genfscon entries vs the MediaTek base

`device/xiaomi/taiko/sepolicy/vendor/genfs_contexts:7:ERROR 'duplicate entry for
genfs entry (sysfs, /devices/platform/soc/10228000.gce/wakeup)'` from
`checkpolicy` while building `vendor_sepolicy.cil.raw`. Unlike `type` /
`typeattribute`, `genfscon` rejects a duplicate `(fs, path)` even when the
context is byte-identical, and `checkpolicy` aborts on the first one. The
yunluo-seeded `genfs_contexts` re-declared 15 wakeup/extcon sysfs paths that
`device/mediatek/sepolicy_vndr/base/vendor/genfs_contexts` already labels
`sysfs_wakeup` / `sysfs_extcon`. Dropped all 15; kept only the taiko-specific
paths not in the base (charger/panel/touch i2c wakeups, `extcon_usb1`, the mali
gpu node, the two `vendor_sysfs_usb_supply` health nodes). Still yunluo-derived
and needs first-boot `avc` iteration for the remaining paths.

### Round 26 — AOSP-core re-audit (dynamic partitions / VAB / AVB / fstab)

Re-checked BoardConfig.mk + device.mk + fstab against source.android.com
(dynamic-partitions/implement, virtual_ab/implement, verifiedboot) + the stock
`vendor/etc/fstab.mt6789` + `MT6789_Android_scatter.txt`:

- **fstab bug fixed**: the external-SD rule was
  `/devices/platform/soc/11230000.msdc*` but the real uevent path (stock fstab)
  is `/devices/platform/soc/soc:odm/11230000.msdc*` — SD card would not have
  mounted. `11240000.mmc*` was already correct.
- Verified OK: `PRODUCT_USE_DYNAMIC_PARTITIONS := true` (device.mk),
  `BOARD_SUPER_PARTITION_METADATA_DEVICE := super` (launch device, real super),
  no `BOARD_SUPER_PARTITION_BLOCK_DEVICES` (retrofit-only), group size =
  `BOARD_SUPER_PARTITION_SIZE − 4 MiB` (Virtual A/B launch rule, not `/2`).
  VAB via `virtual_ab_ota/launch_with_vendor_ramdisk.mk` (same as yunluo);
  `ro.virtual_ab.*` props match the dump. AVB `--flags 3` + test keys +
  chained `vbmeta_system`/`vbmeta_vendor` (rollback locations 1/2/3/4 unique) =
  the proven yunluo pattern, with our A16 additions (`system_dlkm` under
  `vbmeta_system`, `vendor_dlkm`+`odm_dlkm` under `vbmeta_vendor`).
- `ro.vendor.build.dont_use_vabc=true` in `configs/props/vendor.prop` IS a real
  stock prop (`dump-ota/vendor/build.prop:231`) — kept; it just makes OTAs use
  uncompressed snapshots. First flash is fastboot so it doesn't matter for
  bring-up. Candidate for the post-boot HyperOS-prop trim.
- Stock fstab lists `init_boot` but the scatter + OTA payload do not have that
  partition (the fstab is a MT6789-generic template) — our omission is correct,
  CLAUDE.md "no init_boot" stands.

### Round 25 — double-defined modules.load

`Makefile:712: error: overriding commands for target
'.../vendor_dlkm/lib/modules/modules.load', previously defined at
build/make/core/Makefile:148`. `device.mk` both (a) wired
`BOARD_VENDOR_KERNEL_MODULES_LOAD` / `BOARD_SYSTEM_KERNEL_MODULES_LOAD` (which
makes the build run `depmod` and emit `lib/modules/modules.{load,dep,alias,...}`)
**and** (b) `PRODUCT_COPY_FILES`-copied `prebuilt/*/modules.load` onto the same
path. Dropped (b) - the BOARD_* wiring is the correct one and preserves our
curated load order.

### Round 24 — mkshrc + linker.config.pb

`Makefile:148: error: overriding commands for target '.../vendor/etc/mkshrc'`.
`vendor/etc/mkshrc` is installed by `external/mksh`; `vendor/etc/linker.config.pb`
is generated by `build/make/core/Makefile` from the tree's linker-config
fragments. Both dropped. Kept `vendor/etc/{cgroups,task_profiles}.json` (they are
MTK-tuned vendor overrides that `libprocessgroup` merges - nothing else writes
those paths), `public.libraries.txt`, and `ueventd.rc`.

### Round 23 — more install-path clashes: boringssl rc + vndservicemanager rc

`Makefile:148: error: overriding commands for target
'.../vendor/etc/boringssl_self_test.no_zygote.rc'`. `external/boringssl` builds
the self-test binaries **and** installs all five
`boringssl_self_test{,.no_zygote,.zygote32,.zygote64,.zygote64_32}.rc` files -
HyperOS ships them verbatim as blobs. Dropped all five. Also dropped
`vendor/etc/init/vndservicemanager.rc` while here: no `vndservicemanager` binary
in the blob list, no `BOARD_VNDK_VERSION` set, VNDK is deprecated on A16 - the
rc was dead weight and a latent clash with `frameworks/native/cmds/servicemanager`.

### Round 22 — stock fstab blobs vs our rootdir fstab

`device.mk` installs `rootdir/etc/fstab.mt6789` to `vendor/etc/fstab.mt6789` and
`rootdir/Android.bp` names its module `fstab.mt6789` - so the stock
`vendor/etc/fstab.mt6789` blob is both a module-name and an install-path clash,
and it would overwrite our erofs+ext4 / Lineage-recovery fstab with HyperOS's.
Dropped `vendor/etc/fstab.{mt6789,emmc,enableswap}` from `proprietary-files.txt`
(LineageOS init only ever reads `fstab.$(ro.hardware)` = `fstab.mt6789`; the
`by-name` paths in our fstab resolve on both the eMMC `11230000.msdc` and UFS
SKUs).

### Round 21 — build-generated aconfig / release-flag files

`Makefile:148: error: overriding commands for target
'.../vendor/etc/aconfig/flag.info', previously defined at
build/make/core/packaging/flags.mk:168`. The aconfig feature-flag files and the
release-config flag dump are **generated per partition by the build** from the
tree's `.aconfig` declarations - never blobs. Dropped:
`vendor/etc/aconfig/{flag.info,flag.map,flag.val,package.map}`,
`vendor/etc/aconfig_flags.pb`, `vendor/etc/build_flags.json`.

### Round 20 — kati "overriding commands for target" (same install path)

`installs-lineage_taiko.mk: error: overriding commands for target
'.../vendor/etc/vintf/manifest/bluetooth_audio.xml', previously defined at ...`.
Not a module-name clash (Rounds 18-19) but an **install-path** clash - a blob
`prebuilt_etc` and an AOSP `hardware/interfaces` `prebuilt_etc`/`vintf_fragment`
(`vendor: true`) both emit the same `out/.../vendor/etc/...` file. HyperOS ships
these AOSP config files verbatim. Dropped from `proprietary-files.txt` (AOSP
source installs identical content to the same path):

- `vintf/manifest/bluetooth_audio.xml` (`android.hardware.bluetooth.audio` V5
  `IBluetoothAudioProviderFactory/default` - byte-identical to
  `bluetooth/audio/aidl/default/bluetooth_audio.xml`).
- `aidl/hfp/hfp_codec_capabilities.xml`,
  `aidl/le_audio/aidl_audio_set_{configurations,scenarios}.bfbs`,
  `aidl/le_audio/aidl_default_audio_set_{configurations,scenarios}.json` - from
  `bluetooth/audio/utils`. Kept the `*_mtk` copies (distinct install names).

A full-tree scan of every `prebuilt_etc`/`vintf_fragment` install path in
`hardware/interfaces` + `hardware/mediatek` vs the blob list found no other
install-path collisions (`audio_effects_config.xml` shares a path but the AOSP
module is `enabled: false` by default).

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
  by `audio/aidl/default`. Merge the 4 `<hal>` entries in as a second
  `DEVICE_MANIFEST_FILE` (`configs/vintf/manifest_audio_aidl.xml`) - the build
  rejects VINTF xml in `PRODUCT_COPY_FILES` ("VINTF metadata found in
  PRODUCT_COPY_FILES ... use DEVICE_MANIFEST_FILE / ... / vintf_fragments").
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
- [x] `configs/audio|media|wifi` — replaced the yunluo copies with taiko's own
      from `dump-ota/vendor/etc/` (audio_policy_configuration, audio_effects,
      audio_device, audio_em, aurisys_config, media_codecs_c2,
      media_codecs_performance, media_profiles_V1_0, mtk_platform_codecs_config,
      wpa_supplicant.conf, p2p_supplicant_overlay.conf). `configs/hals.conf`
      deleted (the `vendor/etc/sensors/hals.conf` blob owns that path since the
      Round-18 sensors rework). Still parked/not-in-dump: `powerhint.json`,
      `aurisys_config_rv.xml`, `passpointProfile.conf`, `thermal_info_config.json`.
- [x] `configs/vintf/manifest.xml` — verified: the `<hal>` name set is identical
      to `dump-ota/vendor/etc/vintf/manifest.xml` (only the header comment
      differs). No `DEVICE_MATRIX_FILE` by design (stock's needs the unbuilt
      `mediatek-common` jar).
- [ ] `modules.load.recovery` currently mirrors `modules.load.vendor_ramdisk`;
      carve the real recovery fragment with `unpack_bootimg --format=mkbootimg`
      if recovery misbehaves.
- [ ] Trim HyperOS-only `persist.miui.*` / `persist.sys.stability.*` from
      `configs/props/product.prop` once the device boots.
- [x] `mi_ext` fate — resolved: not in any `BOARD_*_PARTITION_LIST` (the build
      never creates the logical partition) and the fstab entry is `nofail`
      +`logical`, so a Lineage build that ships no mi_ext just skips the mount.
- [~] `overlay/` + `overlay-lineage/` — `power_profile.xml` battery.capacity set
      to 9000 (Redmi Pad 2 spec; no full power curve in the dump so the yunluo
      per-component numbers stand). `config_defaultPeakRefreshRate` = 90 already
      matches the 90 Hz panel. `TARGET_SCREEN_DENSITY` = 360 kept: the dump has
      `ro.sf.lcd_density=480` in vendor/build.prop but `=360` in the vendor_boot
      default and `persist.miui.density_v2=360` — 360 is the HyperOS user-facing
      density and gives sw711dp on the 2560x1600 panel. Still yunluo's: the
      auto-brightness nits/backlight curves, Wi-Fi country.
- [ ] Re-sign with real AVB keys once unlocked-and-booting (currently AOSP test
      keys everywhere).
```
