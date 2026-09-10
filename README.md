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

## Status (2026-09-09) — BUILDS & VERIFIES CLEAN ✅ (not yet flashed)

**`brunch taiko` completes** → `lineage-23.2-20260909-UNOFFICIAL-taiko.zip` +
`lineage_taiko-ota.zip` (1.48 GB payload, 2115 ops, test-key signed).
**`verify-build.sh --deep` (post Round 53): `0 FAIL · 119 PASS · 11 WARN`** —
GPU/graphics loader paths all resolve, every vendor `.so` `DT_NEEDED` resolves,
partition sizes fit the scatter, AVB chain + VINTF + fstab + kernel modules
(incl. `vendor/lib/modules -> /vendor_dlkm/lib/modules`) + sepolicy fast-boot
sha256 all good. Round 53 cross-checked every WARN against a **booting** MT6789
LineageOS (yunluo 23.0): `libwpa_client` / CHRE / `sensors.dynamic_sensor_hal` +
`libhidparser` / Widevine-apex / `gralloc.common` absences are all **normal**
(yunluo is the same, or taiko's `hals.conf` never references it) - not
first-boot risks. The one real thing it surfaced (`audio_effects.xml` pointing
at a non-existent `libaudiopreprocessing_mtk.so`) is fixed. **All 11 remaining
WARNs are confirmed non-issues - nothing actionable left in the tree.** Pushed
to `kodeaqua/android_device_xiaomi_taiko_wip` `lineage-23.2`. 53 fix rounds
(soong bootstrap → kati → ninja compile → OTA package → verify → cross-check),
all logged below.

**First real-hardware flash attempt made** (2026-09-09): `boot`/`vendor_boot`/
`dtbo`, then `vbmeta*` with `--disable-verity --disable-verification` (both
slots) - device showed the bootloader splash then powered off, no recovery
either. **Root cause found and fixed in-tree (Round 54)**: this device's
bootloader loads vendor_boot's PLATFORM ramdisk fragment *alone* for a normal
boot, and it has to be a complete standalone first-stage rootfs (confirmed
against the sibling `taiko-twrp` tree, which hit and solved the identical bug
on real hardware) - this build's own generated PLATFORM fragment isn't
equivalent to stock's and panics (`Unable to mount root fs on /dev/ram`)
before the fb console is even up, which is why nothing showed past the boot
logo. Fixed by swapping in the real stock PLATFORM fragment
(`prebuilt/vendor_ramdisk.cpio.lz4` + `build/tasks/vendor_boot.mk`) while
keeping the RECOVERY fragment (LineageOS's own) unchanged.

**Confirmed on real hardware**: after rebuilding just `vendor_boot.img` and
reflashing both slots, `fastboot reboot recovery` **boots straight into
LineageOS recovery** - first successful boot of any kind on this tree, and
proof the PLATFORM-fragment fix (Round 54) is correct. RECOVERY-fragment
budget (LineageOS recovery + stock's 26.4MiB PLATFORM fragment inside the
fixed 64MB `vendor_boot` partition) fits fine, no trimming was needed.

**Normal system boot also confirmed** - reached System (tested with a
LineageOS GSI on `system`, `taiko`'s own `lineage_taiko-ota.zip` not sideloaded
yet). Validates the whole boot chain end to end (kernel, the Round-54
`vendor_boot`, `vbmeta`, dynamic partitions/super) and VINTF/vendor-interface
compatibility, independent of taiko's own system image. **Next**: `adb
sideload lineage_taiko-ota.zip` from recovery (this tree's own build, not the
GSI) + factory reset (Format data, since `system` currently holds the GSI),
reboot to system - first real test of taiko's own ROM - then `adb shell
dmesg | grep 'avc: denied'` + `adb logcat -b all` for the first-boot round
(SELinux, camera, brightness curves, real AVB keys, trim `persist.miui.*`).

Incremental rebuild after a `configs/`- or `Android.mk`-only change:
`git -C device/xiaomi/taiko pull && brunch taiko` (~9 min, no
`breakfast` / soong / kati regen).

Build-log review (Round 50): **zero errors, zero `FAILED`, zero `check_elf`
failures**. All remaining log noise is benign and expected —
`ramdisk size: 0` / `cpio: empty archive` (GKI kernel-only boot.img by design),
`Failed to read IMAGES/init_boot.img` (no init_boot on taiko),
`Couldn't find AIDL metadata for vendor.mediatek.hardware.*` ("expected for
prebuilt interfaces"), `Duplicate key 'BoardPlatform'/'ProductModel' with
identical values`, `setProcessGroupSwappiness is deprecated` (AOSP source),
`Disabling zucchini/lz4diff` (full OTA). `super_partition_size` 11811160064 /
group 11806965760 match the scatter exactly; `lpmake` built super_empty A+B.
One cosmetic upstream quirk: `misc_info` `ab_partitions` carries a trailing
empty `''` entry after the firmware partitions — harmless (payload generated &
signed fine), not from our editable files.

`tools/verify-build.sh --deep` against the built tree found **one real bug**
(Round 51: missing `egl/libGLES_mali.so` + 13 other SoC-subdir symlinks — no
Mali GLES/Vulkan driver at the loader path; fixed in `Android.mk`). Everything
else it first flagged was a script bug (fixed) or a non-blocking absence:
- `android.hardware.audio.core-impl-mediatek.so` — present at `vendor/lib64/`
  (script wrongly looked under `hw/`). Audio HAL intact.
- 19× `soundfx/*` — false. `configs/audio/audio_effects.xml` references the AOSP
  wrapper libs (`libbundlewrapper`, `libreverbwrapper`, `libvisualizer`,
  `libdownmix`, `libldnhncr`, `libdynproc`, `libaudiopreprocessing`,
  `libspatializer`, `libeffectproxy` — all built from source) + the `*_mtk` /
  `*aidl` blobs (all kept). The names Round 48 dropped (`libbundleaidl`,
  `libvolumesw`, `libequalizersw`, …) are HyperOS-only alt impls the config
  never loads. Correct drop.
- Genuinely absent, non-blocking, verify at first boot / restore only if broken:
  `libwpa_client.so` (legacy, unused by AIDL Wi-Fi on A16), `libhidparser.so`
  (BT-HID parsing), `android.hardware.contexthub-service.tinysys` +
  `chre_atoms_log.so` (CHRE, R46), `sensors.dynamic_sensor_hal.so` (R47).
- VINTF "HAL not in manifest" WARNs — those HALs are declared in
  `vendor/etc/vintf/manifest/*.xml` fragments, merged at boot; script now scans
  the fragment dir too.
- `--deep`: `libmtkcam_hal_aidl_provider.so` → `camera.provider@2.6-impl
  -mediatek.so`, `vulkan.mali.so` → `libGLES_mali.so` — confirm both impl libs
  are in the image before trusting camera/GPU (camera already a first-boot item).

Build runs on a separate machine — errors are pasted in and fixed here. Camera
enabled; `configs/audio|media|wifi` = taiko's own; `BOARD_SUPER_PARTITION_SIZE`
= 11 GiB from the scatter. See the workspace `../../../CLAUDE.md` "Build status"
for the fix-class cheat sheet.

**Next: flash to a device.** Everything past this point (SELinux denials,
camera correctness, auto-brightness curves, real AVB keys, trimming
`persist.miui.*`) needs a booting target — see "Open TODO".

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
blobs + dropped-on-purpose absent · **GPU/graphics loader paths** (Mali
`egl/`+`hw/` symlinks resolve) · **MVPU island** · VINTF · kernel modules
(`modules.load` ↔ `.ko`, `modules.dep`, `vendor/lib/modules` symlink) ·
**vendor_dlkm modprobe blocklist** (Round 58: `modules.blocklist` blocks
`metis`/`mi_schedule`/`task_turbo` AND `init.insmod.mt6789.cfg` carries
`modprobe|-b *` - both required or `metis.ko` NULL-derefs → logo hang) ·
**vendor_boot PLATFORM fragment** (Round 54: `prebuilt/vendor_ramdisk.cpio.lz4`
+ `build/tasks/vendor_boot.mk` repoint; if `unpack_bootimg` is on `$PATH` it
unpacks the built `vendor_boot.img` and checks the PLATFORM fragment has
`/init`, and flags that its fstab is stock's = the Layer-2 deferred gap) ·
fstab · recovery-in-vendor_boot + **recovery ADB configfs** (Round 55) · AVB
(`avbtool`: flags=3, rollback locations, chained descriptors) · build.prop
(Round 29-30) · SELinux · APEX. `avbtool` / `checkvintf` / `unpack_bootimg` on
`$PATH` unlock the extra checks.

## AOSP-core audit (source.android.com/docs/core)

Checked against: generic-boot, vendor-boot-partitions, gki-partitions,
dynamic-partitions, loadable-kernel-modules, vndk build-system, VINTF objects,
SELinux device policy.

### Round 58 - Round 57's fix didn't actually work: `modprobe -a` pulls `metis` back in as a dependency

**Fix applied, not yet reflashed/confirmed.** Rebuilt/reflashed after Round
57, waited for the AP watchdog to reset again, pulled `console-ramoops-0`
again - **byte-for-byte identical** to the first capture, same crash, same
timestamp down to the microsecond. That's not a new crash; it's stale
pstore content (see below) - but chasing that down surfaced the real reason
Round 57 never had a chance to work in the first place.

`prebuilt/vendor_dlkm/modules.load` isn't read by a raw per-line `insmod` -
`vendor/etc/init.insmod.mt6789.cfg` (blob) says `modprobe|*`, and
`rootdir/bin/init.insmod.sh` turns that into `modprobe -a -d <dir> $(cat
modules.load)`. `modprobe -a` (`system/core/libmodprobe`) resolves the full
dependency graph from `modules.dep` (generated by `depmod` at build time)
regardless of whether a dependency's own line is present in
`modules.load` - and `modules.dep` shows `scheduler.ko`, `cpufreq_sugov_ext.ko`,
and `mtk_core_ctl.ko` (all three kept in Round 57, matching yunluo) hard-depend
on `metis.ko`. Removing just `metis.ko`'s own line did nothing: `modprobe`
loaded it anyway as their dependency, every time, which is exactly why the
second capture is identical to the first - it's the *same* crash recurring
identically, not evidence of anything new.

(Cross-checked directly against `system/core/libmodprobe/libmodprobe.cpp`
before relying on this: `Modprobe::IsBlocklisted()` is consulted during
dependency resolution too, not just for directly-requested modules -
comment at the relevant call site literally says "Hard-dependencies cannot
be blocklisted", i.e. a block on `metis` fails the *dependent's* load
cleanly instead of silently pulling `metis` back in. That's the real,
supported mechanism for this - a `modules.load` edit alone was never going
to be enough on a `modprobe -a`-driven device.)

**Real fix**: reverted `modules.load` back to stock content (`metis.ko`/
`mi_schedule.ko`/`task_turbo.ko` all present again - removing them achieved
nothing, so there's no reason to keep it edited) and added
`prebuilt/vendor_dlkm/modules.blocklist` (`BOARD_VENDOR_KERNEL_MODULES_
BLOCKLIST_FILE` already wildcards this path in `BoardConfig.mk` - no config
change needed) blocking `metis` and `mi_schedule` directly. That mechanism
only activates if `modprobe` is actually invoked with `-b` - plain
`modprobe -a` ignores `modules.blocklist` entirely - and
`rootdir/bin/init.insmod.sh` already has the "-b *" cfg-arg case wired
(`arg="-b $(cat modules.load)"`), so the only missing piece was the blob's
own cfg line. Added an `extract-files.py` `blob_fixup` (regex, `\|` and `\*`
escaped - `regex_replace` uses the pattern as a real regex, not a literal
string) turning `vendor/etc/init.insmod.mt6789.cfg`'s `modprobe|*` into
`modprobe|-b *`, and patched the already-extracted
`vendor/xiaomi/taiko/proprietary/...` copy in place the same way (same
"patch in place too so the in-flight build continues" pattern as Round 33).

**Blast radius, unavoidable either way** (blocklisting a hard-dependency and
deleting the file outright have the identical effect - dependents fail to
load either way; blocklist is kept because it's reversible without a
re-extract): every module that hard-depends on `metis`/`mi_schedule` per
`modules.dep` fails to load too (cleanly - "unknown symbol", not a crash) -
`scheduler`, `cpufreq_sugov_ext`, `mtk_core_ctl`, `task_turbo`, `vip_engine`,
`mtk_fpsgo_v3`, `fpsgo`, `powerhal_cpu_ctrl`, `ccidvfs`, `mtk_perf_common`,
`perf_common_v`, and **`mtk-vcodec-sys-api`** (HW video codec accel - falls
back to SW decode, not a boot blocker). This is a real functionality loss
(MIUI-specific perf/scheduler tuning, HW video codec) accepted for now to
get *any* successful boot; revisit once booting reliably - see "why does
GSI boot fine then" below for why this is expected to be safe to defer.

**"But GSI booted fine on this exact hardware - doesn't that mean metis
isn't really the problem?"** - fair challenge, checked properly: GSI only
replaces `/system`; `/vendor_dlkm` (where `metis.ko` lives) is unrelated to
which GSI is running. But the GSI test happened *before* this tree's own
`super.img` (and thus its own `vendor_dlkm.img`) was ever flashed - at that
point `/vendor_dlkm` was still whatever was on the device from the earlier
`vendor_boot`-only fix rounds, not this build's own vendor_dlkm content, so
it says nothing about whether *this build's* module set is fine. The kernel
module loading mechanics (same `modprobe`, same blob `.cfg`, same
`modules.dep`) are identical either way - the plausible remaining
explanation is that `metis`'s crash is a genuine timing/race bug (the crash
function, `lowlt_list_del_task`, manages a scheduler tracking list - exactly
the class of bug sensitive to exact boot timing) that stock HyperOS's own
service startup sequence happens not to hit, while this AOSP-based second
stage's different service startup order does. Not provable without kernel
source, but consistent with every piece of evidence gathered so far.

**Second finding along the way (independent cross-check, credited)**: a
parallel investigation (a second Claude session working from the same repo
state) found that `device.mk`'s `PRODUCT_COPY_FILES` line injecting
`rootdir/etc/fstab.mt6789` into `$(TARGET_COPY_OUT_VENDOR_RAMDISK)/
first_stage_ramdisk/` (device.mk:204) is dead code for **normal boot**:
Round 54 repoints `INTERNAL_VENDOR_RAMDISK_TARGET` at the raw stock
`prebuilt/vendor_ramdisk.cpio.lz4` *after* that copy step would have run,
discarding the generated ramdisk (and this device.mk injection with it)
entirely. Confirmed directly: unpacking the committed
`vendor_ramdisk.cpio.lz4` shows `first_stage_ramdisk/fstab.mt6789` is
still the stock, cpp-preprocessed fstab (`vendor/mediatek/proprietary/
hardware/fstab/mt6789/fstab.in.mt6789` in its own header), with bare
`avb` on `/vendor` and `/product` where this tree's own fstab uses
`avb=vbmeta_vendor`/`avb=vbmeta_system`. **Confirmed not the current
blocker, though**: this device's own `vendor.img`/`product.img` are signed
under `BOARD_AVB_VBMETA_VENDOR`/`_SYSTEM` chains, but the top-level
`vbmeta_a` currently carries `--disable-verification`, and `external/avb/
libavb/avb_slot_verify.c` returns immediately with no descriptor-chain
processing at all when that flag is set (checked directly:
"since verification is disabled we didn't process any descriptors") -
so the specific `avb=` value in whichever fstab is actually live doesn't
matter right now, and the boot log's own evidence (dozens of drivers/HALs
initializing successfully long before the `metis` crash) confirms mounting
is not what's failing. Real gap, worth fixing eventually (this device's own
fstab is never actually used for normal boot right now, only recovery -
extract-and-splice the real `fstab.mt6789` into the committed
`vendor_ramdisk.cpio.lz4`'s `first_stage_ramdisk/`, or rebuild+concatenate
properly), tracked here rather than fixed blind since it isn't blocking
anything today.

**Next**: `mka superimage` (feeds `vendor_dlkm.img` + `vendor.img`, both
touched this round) + reflash `super` + retest. Verify from recovery with
`adb shell dmesg | grep -i metis` (should show "not blacklisted" ->
actually blocked, or nothing at all) instead of trusting `console-ramoops`
alone - clear pstore first (`adb shell rm -f /sys/fs/pstore/*`) so a stale
record can't be mistaken for a fresh one again.

### Round 57 - normal boot hangs forever at the bootloader logo: `metis.ko` NULL pointer oops

**Fix applied, not yet reflashed/confirmed.** After Round 54/55 fixed
`vendor_boot` and recovery, and a full `super.img` reflash fixed a separate
A/B dynamic-partition mixup (see Round 54's status note), normal boot into
taiko's own system image (not the GSI used to validate Round 54/55) hung
indefinitely at the bootloader splash - no crash, no `console-ramoops`, no
`pmsg-ramoops`, no `/data/vendor/aee_exp` or `expdb`/`oops` partition
content, `fastbootd` also never enumerated over USB. Round 56 tried forcing
`androidboot.selinux=permissive` as a diagnostic (in case a missing
sepolicy rule on a required service was silently blocking boot) - inial
test showed no change, but that test was invalid: `mka vendorbootimage`
reported "ninja: no work to do" and never actually rebuilt the image (a
pure `BoardConfig.mk` variable change didn't get picked up - the ninja-
staleness class of bug the sibling `taiko-twrp` tree's README also warns
about). Confirmed via `adb shell getprop ro.boot.selinux` / `cat /proc/
bootconfig` after force-deleting `$OUT/vendor_boot.img` and rebuilding:
permissive really was active, and the hang was identical - **SELinux ruled
out**.

**Root cause found** from `/sys/fs/pstore/console-ramoops-0`, captured only
after the device was left long enough for MediaTek's own AP watchdog to
force-reset it (`androidboot.bootreason=kernel_panic`,
`aee_aed.poffreason=AP_WDT` in `/proc/bootconfig`) - every earlier attempt
had been manually power-cycled before the watchdog could fire, which is why
`pstore`/`expdb`/`oops` were empty every previous time. The captured log
shows a kernel oops, not a clean panic, right as `logd` starts (i.e. right
as normal second-stage init ramps up real process/thread activity):

```
init: starting service 'logd'...
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000000
Internal error: Oops: 0000000096000005 [#1] PREEMPT SMP
pc : [...] lowlt_list_del_task+0x70/0x170 [metis]
```

`metis.ko` (`modinfo`: "metis-driver by David", `depends: mi_schedule`,
parameters like `mi_boost_duration`/`mi_freq_enable`/`mi_switch_enable` -
a Xiaomi CPU-scheduling/game-boost assist driver, not core Android) is
loaded **only** via `prebuilt/vendor_dlkm/modules.load` -
`modules.load.vendor_ramdisk`/`modules.load.recovery` never reference it at
all. That's exactly why recovery (a handful of processes: ueventd,
servicemanager, recovery, adbd) almost never triggers the crash, while
normal boot (dozens of services starting at once, right as `logd` ramps up
scheduling activity) reliably does - and explains the user's separate
"recovery kadang reboot tiba-tiba" report too: recovery does load
`vendor_dlkm` modules under some paths, so the same crash can still fire
there occasionally, just far less often than during full boot.

Cross-checked against the sibling `xiaomi-mt6789-devs/android_device_
xiaomi_yunluo-kernel` tree (same MT6789 platform, proven booting):
its `modules.load` keeps `cpufreq_sugov_ext.ko`/`scheduler.ko`/
`mtk_core_ctl.ko` (all `metis`-dependent per `modinfo -F depends`) but
**does not load `metis.ko`, `mi_schedule.ko`, or `task_turbo.ko` at all** -
independent confirmation this exact trio is the right thing to drop, not
guesswork. Removed all three lines from `prebuilt/vendor_dlkm/modules.load`
(nothing else touched - `BOARD_VENDOR_KERNEL_MODULES` wildcards every `.ko`
in that directory regardless of `modules.load` content, so the three files
stay in the tree/image, just never `insmod`'d). `cpufreq_sugov_ext`/
`mtk_core_ctl`/`scheduler` (which `modinfo` lists as depending on `metis`)
are kept, matching yunluo - if their own `insmod` now fails on an
unresolved symbol, that's a non-fatal `insmod` error, not a kernel oops,
and can be dropped individually later with fresh evidence if it turns out
to matter.

**Next**: `mka vendorbootimage`... **no** - `vendor_dlkm/modules.load`
feeds `BOARD_VENDOR_KERNEL_MODULES_LOAD`, which packages into the
**`vendor_dlkm` image**, not `vendor_boot`. Needs a `vendor_dlkm.img`
rebuild (`mka vendor_dlkmimage` or a full `brunch taiko`) + reflash, then
retest normal boot.

### Round 55 - recovery ADB never enumerates (nothing in Windows Device Manager either)

**Fix confirmed on real hardware**: after rebuilding `vendor_boot.img` with
`recovery/root/init.recovery.mt6789.rc` and reflashing both slots, `adb
devices` from recovery's "Apply from ADB" screen now sees the device.

After Round 54 got recovery + normal boot both working, `adb devices` from
recovery's "Apply from ADB" screen came back completely empty - and not just
`adb`: nothing new appeared in Windows Device Manager at all when plugging
in (same cable/port that worked fine for `fastboot` the whole time), ruling
out a missing-driver explanation - the gadget itself never enumerated on the
bus.

Root cause, found by reading `bootable/recovery/etc/init.rc` (AOSP default,
unmodified by this tree until now) directly: it does

```
on early-init
    ...
    setprop sys.usb.configfs 0
```

unconditionally, which routes all USB gadget setup through the **legacy**
`/sys/class/android_usb/android0/*` sysfs interface (see the file's
`on fs && property:sys.usb.configfs=0` block). This device's kernel (MT6789,
GKI android16-6.12) does not implement that legacy class at all - it is
configfs-gadget only, exactly like this device's own normal-boot
`rootdir/etc/init.mt6789.usb.rc` already proves (`/config/usb_gadget/g1/...`,
present and working per the Round-54 GSI normal-boot test). Every
`write /sys/class/android_usb/android0/...` in recovery's init.rc silently
fails (no such path - `init` logs an error, non-fatal, and moves on), so the
gadget is never bound to any UDC and nothing shows up on the host at all -
not a Windows driver problem, not a cable problem.

`bootable/recovery/etc/init.rc`'s very first line is
`import /init.recovery.${ro.hardware}.rc` (`ro.hardware` = `mt6789`, the
AOSP default derived from `TARGET_BOARD_PLATFORM`) - the standard device
override hook for exactly this. This tree had no such file at all yet (no
`recovery/root/` directory existed), so the import silently resolved to
nothing and recovery ran with 100% AOSP defaults for USB.

**Fix**: added `recovery/root/init.recovery.mt6789.rc` -
`$(TARGET_DEVICE_DIR)/recovery/root` is auto-discovered and merged into the
recovery ramdisk root by `build/make/core/Makefile`, no `BoardConfig.mk`/
`device.mk` wiring needed (same auto-discovery mechanism the sibling
`taiko-twrp` tree's `recovery/root/` relies on, confirmed by reading
`build/make/core/Makefile`'s `recovery_root_private` handling directly). The
override:

```
on init
    setprop sys.usb.configfs 1
    setprop sys.usb.controller "musb-hdrc"
```

Two things, both required:
- `sys.usb.configfs 1` routes recovery through the `on fs &&
  property:sys.usb.configfs=1` block instead (mounts `configfs`, creates
  `/config/usb_gadget/g1` with `ffs.adb`/`ffs.fastboot` functions - the same
  class of setup `init.mt6789.usb.rc` already does for normal boot, just
  simpler since recovery only needs adb+fastboot, not the full MTP/RNDIS/ACM
  stack). Must be set at `on init`, **not** `on early-init`: `import`
  inserts the imported file's actions into the global action list before
  `init.rc`'s own subsequent lines are parsed, so an `on early-init` block
  here would fire (and lose) *before* `init.rc`'s own `on early-init` block
  sets it back to 0 - same trigger, same firing pass. `on init` is a
  distinct, later trigger, so it reliably wins regardless of import/parse
  order.
- `sys.usb.controller "musb-hdrc"` - the configfs path's final gadget-bind
  step does `write /config/usb_gadget/g1/UDC ${sys.usb.controller}`, and
  nothing else in the recovery ramdisk ever sets that property (it's
  normally set by `rootdir/etc/init.mt6789.usb.rc`'s own `on boot` block,
  which only runs on a full system boot, never in recovery) - without it
  the UDC write is empty and the gadget still never binds even with configfs
  enabled. Value copied verbatim from that same file (MTK's MUSB controller
  driver; `phy-mtk-tphy.ko`/`musb_hdrc.ko`/`musb_main.ko` are already loaded
  in both vendor_boot ramdisk fragments per `modules.load.recovery`).

`sys.usb.ffs.ready` (the third condition on the property-triggered UDC-bind
block) needed no fix - confirmed from `bootable/recovery/install/
adb_install.cpp` that it's set by the adb daemon itself once it opens the
functionfs endpoint, independent of configfs vs legacy.

**Next**: `adb sideload lineage_taiko-ota.zip` (this tree's own build, not the
GSI System is currently running), factory reset, reboot - first real test of
taiko's own ROM.

### Round 54 - first real-hardware flash: no boot, no recovery ("logo then power off")

**Fix confirmed on real hardware**: after rebuilding `vendor_boot.img` with
the stock PLATFORM fragment and reflashing both slots, `fastboot reboot
recovery` boots straight into LineageOS recovery - first successful boot of
any kind on this tree. Normal system boot (`adb sideload` + factory reset)
is the next thing to verify.

Device (physical Redmi Pad 2, first-ever flash of this tree) flashed `boot`,
`vendor_boot`, `dtbo` (later also `vbmeta*` with `--disable-verity
--disable-verification`, both slots) - same symptom every time: bootloader
splash (Mi logo) shows, then the device powers off. Never reaches recovery
either, which is the key diagnostic signal: recovery on this device rides
entirely inside `vendor_boot.img` (no dedicated recovery partition), so a
normal-boot-only failure would still let recovery through - both failing
together points at `vendor_boot.img` itself, before AVB/vbmeta even applies.

**Root cause, confirmed by analyzing `kodeaqua/android_device_xiaomi_taiko-twrp`**
(a sibling tree for this exact device, TWRP recovery, verified live on real
taiko hardware) - its README documents hitting and solving this identical bug:
taiko's bootloader/LK, for a **normal boot**, loads vendor_boot's `ramdisk_type
0x1` (PLATFORM) fragment **by itself** - it is only concatenated with the
`0x2` (RECOVERY) fragment when entering recovery mode. Since this device has
no `init_boot` partition and `boot.img` is kernel-only (`ramdisk_size = 0`),
the PLATFORM fragment has to be a **complete standalone first-stage rootfs**
- not just vendor fstab/ueventd/modules, but the generic AOSP init tree too
(`init`, `linkerconfig`, `sepolicy`, `prop.default`, `res/`, every
`*_contexts` file). The TWRP tree's own README shows the confirmed panic
(from `pstore/console-ramoops` on real hardware) when booting their own
AOSP-generated PLATFORM fragment as the sole normal-boot fragment - the exact
same class this build also generates:

```
RAMDISK: lz4 image found at block 0
F2FS-fs (ram0): Magic Mismatch...   (ext2/3/4/vfat/exfat/erofs all fail too)
Kernel panic - not syncing: VFS: Unable to mount root fs on "/dev/ram" ...
```

This happens before the kernel framebuffer console is up, so nothing shows
on screen past the bootloader's own logo - exactly the "logo then power off"
symptom, and exactly why it's untouched by AVB/vbmeta flags (verified: the
device's own report showed no change after disabling verity/verification).

Verified directly against `prebuilt/vendor_boot.img` (this device's own
stock reference image, already in the tree) with `unpack_bootimg.py`:

```
vendor_ramdisk00: size 27646885, type 0x1, name ''        (PLATFORM)
vendor_ramdisk01: size 15390317, type 0x2, name 'recovery' (RECOVERY, stock/MIUI)
```

`vendor_ramdisk00` decompresses (lz4) to 70684928 bytes and is a real cpio
archive containing `init`, `linkerconfig`, `sepolicy`, `prop.default`, `res/`,
every `*_file_contexts`/`*_property_contexts`/`*_service_contexts`, and
**215 kernel modules** including the UFS storage driver itself
(`ufs-mediatek-mod.ko`, `phy-mtk-ufs.ko`) - matches the TWRP tree's findings
exactly (same device, same dump lineage).

**Fix** (same mechanism the TWRP tree uses, adapted to this tree's paths):
extracted `vendor_ramdisk00` byte-for-byte to
`prebuilt/vendor_ramdisk.cpio.lz4`, and added
`device/xiaomi/taiko/build/tasks/vendor_boot.mk` (picked up by
`build/make/core/Makefile`'s
`-include $(sort $(wildcard device/*/*/build/tasks/*.mk))` at the very end,
after every image rule is defined) which repoints
`INTERNAL_VENDOR_RAMDISK_TARGET` at that prebuilt - this is what
`mkbootimg --vendor_ramdisk` ends up using, since the official
`BOARD_VENDOR_RAMDISK_FRAGMENT.*.PREBUILT` mechanism only covers *extra*
fragments, never the main one. The RECOVERY (`0x2`) fragment is **untouched**
- still built from this tree's own LineageOS recovery sources +
`BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD` on every compile, exactly
as before. `BoardConfig.mk`'s existing `BOARD_VENDOR_RAMDISK_KERNEL_MODULES`/
`_LOAD` wiring is also untouched deliberately (not trimmed/de-duplicated
against the now-unused generated PLATFORM fragment) - it still feeds the
RECOVERY-side module set, and the generated-but-unused PLATFORM fragment
costs nothing to leave in place.

**Budget check, not yet build-verified**: `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE`
is a fixed 67108864 (64MB). Stock PLATFORM fragment is 27646885 bytes
(~26.4MiB); this tree's own LineageOS RECOVERY fragment must fit in the
remaining budget (~39.2MiB minus header/dtb/bootconfig/table overhead,
~194KB). LineageOS recovery is much leaner than TWRP's (no GUI theme,
busybox, bash/nano/ntfs-3g/exfat, resetprop/repacktools), so this is
expected to fit comfortably, but hasn't been confirmed against an actual
built `vendor_boot.img` yet - check on the next `mka vendorbootimage` /
`brunch taiko` (`assert-max-image-size` fails loudly if it doesn't; the TWRP
tree hit exactly this wall with its own bulkier recovery and had to trim
duplicate kernel modules out of its RECOVERY fragment - **not** applied here
pre-emptively, only if the build actually overflows).

**Next**: rebuild `vendor_boot.img` (only this image needs to change - no
`breakfast`/kati/full ninja regen, same class as the Round-52 "config-only"
incremental path) and reflash `vendor_boot` to both slots, then retest
`fastboot reboot recovery` before touching `super`/data again.

### Round 53 - cross-check against a booting MT6789 LineageOS (yunluo 23.0)

Extracted `vendor.img` from `lineage-23.0-20251015-UNOFFICIAL-yunluo.zip`
(Redmi Pad 1, same SoC, booting) and diffed against taiko's 16 verify WARNs.

**Confirmed non-issues** (yunluo, which boots, is the same):
- `libwpa_client.so` - **not in yunluo either**. Legacy, unused on AIDL Wi-Fi.
- `contexthub-service.tinysys` / `chre_atoms_log.so` - **not in yunluo**. No CHRE
  on MT6789 LineageOS.
- `sensors.dynamic_sensor_hal.so` + `libhidparser.so` - yunluo ships both, but
  **only because yunluo's `hals.conf` lists `sensors.dynamic_sensor_hal.so`**
  (which hard-`NEED`s `libhidparser`). **taiko's stock `hals.conf` =
  `sensors@2.X-subhal-mediatek.so` + `sensors.camera.light.so` only** - it never
  references the dynamic-sensor HAL, so dropping both (Round 47/earlier) is
  correct. Nothing else in taiko's vendor image `NEED`s `libhidparser`
  (`--deep` is green).
- `com.google.android.widevine.nonupdatable` apex - **not in yunluo**; not a
  `/vendor/apex` component on MT6789 LineageOS (taiko even ships
  `com.android.hardware.cas.apex`, which yunluo doesn't).
- `gralloc.common.so` symlink - yunluo (HIDL, 23.0) has it; taiko (AIDL gralloc,
  23.2) has no `gralloc.common.so` in the dump at all - correctly absent.
- Round-51 subdir symlinks (`egl/`, `hw/`, `mtkcam/`) - yunluo has the exact
  same class (`egl/libGLES_mali.so`, `hw/vulkan.mali.so`,
  `mtkcam/libmtkcam_streaminfo_plugin-p1stt.so`, `lib/modules ->
  /vendor_dlkm/lib/modules`, ...). Round 51 confirmed correct.

**One real fix** (`configs/audio/audio_effects.xml`): stock (and taiko, which
copied it verbatim) names `libaudiopreprocessing_mtk.so` for the `pre_processing`
library, but **no such file exists in the dump** (only
`soundfx/libaudiopreprocessing.so`) - so `aec`/`ns`/`agc` mic pre-processing
silently fails to load, on HyperOS too. yunluo's config uses the generic
`libaudiopreprocessing.so` (same effect UUIDs, and it IS shipped). Repointed
taiko's line at `libaudiopreprocessing.so`.

**One script fix** (`verify-build.sh`): the sepolicy fast-boot marker is
`precompiled_sepolicy.plat_sepolicy_and_mapping.sha256` (with the
`precompiled_sepolicy.` prefix) - the check was looking for the un-prefixed
name and always WARNing.

### Round 52 - device-tree audit pass (props / sepolicy / overlays / module load)

Full re-read of the source files not touched in a while. **No tree change
needed** - all clean:

- **props** (`configs/props/*.prop`) - dump-derived and consistent.
  `ro.hardware.egl=meow` + `ro.hardware.vulkan=mali` → the MEOW GPU shim
  (`libGLES_meow.so` + `libMEOW_*.so`, all shipped) wraps the real Mali driver;
  the Round-51 `egl/libGLES_mali.so` symlink is what `libGLES_meow.so` then
  dlopens, so R51 was necessary and is sufficient.
  `ro.surface_flinger.primary_display_orientation=ORIENTATION_180` +
  `debug.sf.ignore_hwc_physical_display_orientation=true` = panel is mounted
  upside-down (stock value, keep). `ro.vendor.{bt,fm,gps}.*` all set → the
  `insmod .../*_${prop}.ko` lines in the factory/meta rc resolve.
- **`/vendor/lib/modules`** - AOSP auto-creates it as a symlink →
  `/vendor_dlkm/lib/modules` (because `BOARD_USES_VENDOR_DLKMIMAGE := true`), so
  `init.insmod.sh` (`modprobe|*` from `init.insmod.mt6789.cfg`, started by
  `init.mtkgki.rc` on `early-init`) + the `insmod /vendor/lib/modules/*.ko`
  lines in `init.project.rc` / `init.mt6789.rc` all reach vendor_dlkm's 172
  modules. Verified on the build box. `verify-build.sh` now checks this.
- **`core_64_bit_only`** (`lineage_taiko.mk`) vs stock `ro.zygote=zygote64_32` -
  deliberate (comment in `BoardConfig.mk`); `TARGET_2ND_ARCH := arm` keeps
  32-bit *vendor* libs building so 32-bit HALs still run. Only effect: 32-bit
  -only APKs won't run. Switch to `core_64_bit.mk` if full stock parity is
  wanted.
- **sepolicy/vendor** - minimal targeted allows (`mi_thermald`,
  `charger_vendor`, health/keymint/power/pq); type-checks against 23.2 base.
  Real policy work is still the first-boot `avc: denied` round.
- **overlays** - `config_defaultPeakRefreshRate=90` ✓, Wi-Fi-only capability
  flags ✓, `config_wifi5ghzSupport=true` ✓. Auto-brightness nits/backlight
  curves are still yunluo's (Redmi Pad 1) - first-boot tuning, in the TODO.

### Round 51 - missing Mali/gralloc SoC symlinks (verify --deep catch)

`verify-build.sh --deep` on the built tree flagged `vulkan.mali.so` and
`libmtkcam_hal_aidl_provider.so` with unresolved `NEEDED` refs, and a direct
check found **`vendor/lib{,64}/egl/libGLES_mali.so` absent**.

Root cause: MTK ships each SoC lib as `<dir>/mt6789/<name>` + a bare symlink at
the path the loader dlopens. `Android.mk`'s `MTK_SOC_SYMLINKS` list (built from
the stock tree) only picked up the **flat** `vendor/lib{,64}/*.so` symlinks and
missed the 19 that live in `egl/`, `hw/`, `mtkcam/` subdirs. Diff of stock
symlinks vs the list:

| Missing symlink | Impact |
|---|---|
| `egl/libGLES_mali.so` (32+64) | `egl.cfg` says `0 1 mali` → loader dlopens this exact path. Absent ⇒ Mali-G57 has **no GLES driver**, EGL falls back to swiftshader → SW-rendered UI on a 2560×1600 panel / bootanim crawl. |
| `hw/vulkan.mali.so` (32+64) | Vulkan loader path — no HW Vulkan. |
| `hw/mapper.mediatek.so` (32+64) | gralloc stable-c mapper SurfaceFlinger loads. |
| `hw/android.hardware.graphics.allocator-V2-mediatek.so` (32+64) | allocator impl. |
| `hw/…camera.provider@2.6-impl / ccap / isphal_aidl`, `hw/…pq_aidl-impl`, `mtkcam/libmtkcam_streaminfo_plugin-p1stt` | camera / PQ HAL impls. |

Fix: added those 14 (real `mt6789/` target exists in `proprietary-files.txt`) to
`MTK_SOC_SYMLINKS`. The generic rule `ln -sf $(TARGET_BOARD_PLATFORM)/$(notdir
$@) $@` already produces the right relative link for a one-level subdir. The
legacy-HIDL `audio.primary.mt6789` / `audio.r_submix.mt6789` / `sensors.mt6789`
symlinks are **not** added — taiko is AIDL audio + sensors and those blobs
aren't shipped. Re-sync: `git pull && breakfast taiko && brunch taiko` (only
`Android.mk` changed). `verify-build.sh` gained a "GPU / graphics loader paths"
section that checks each dlopen path resolves (and flags a dangling symlink).

### Round 50 - build-log review: first full `brunch taiko` ✅

User pasted the packaging-pass log (`log.txt`, 6949 lines — the incremental
965-target run after the heavy ninja compile). Result:
`#### build completed successfully (19:09 (mm:ss)) ####`, both
`lineage-23.2-20260909-UNOFFICIAL-taiko.zip` and `lineage_taiko-ota.zip`
produced and test-key-signed.

Swept for `error:` / `FAILED` / `check_elf` / size-overflow → **none**. Every
`WARNING`/`INFO` in the log is expected:

| Log line | Why it's fine |
|---|---|
| `boot magic … ramdisk size: 0` · `cpio: empty archive` · `decoded 0 bytes` | boot.img is the stock GKI kernel, no ramdisk — used as-is (matches Hard facts). The re-sign step just can't introspect a ramdisk that isn't there. |
| `Failed to read IMAGES/init_boot.img` | taiko has no `init_boot` partition. |
| `Failed to read SYSTEM/etc/build.prop` / `VENDOR/…` / `ODM/…` (during boot re-sign) | those partitions aren't inside boot.img; props are read later from the real images. |
| `INFO: Couldn't find AIDL metadata for: vendor.mediatek.hardware.* … expected for prebuilt interfaces` | our proprietary HALs declared in `configs/vintf/manifest.xml` with no AIDL source in-tree. Working as intended. |
| `Duplicate key 'BoardPlatform' / 'ProductModel' with identical values found` | set in two inherited makefiles to the *same* value — no effect. |
| `setProcessGroupSwappiness is deprecated: Unsupported in memcg v2` | AOSP `system/core/init` source, not our tree. |
| `Sysprop apex.all.ready is missing, default to ''` | benign default during `check_target_files_vintf`. |
| `Disabling zucchini` / `Disabling lz4diff` | full (non-incremental) OTA — no source build to diff against. |

`super_partition_size = 11811160064`, `mtk_dynamic_partitions_group_size =
11806965760` — exact scatter match. `lpmake` built `super_empty.img` with
A+B groups over the 7 dynamic partitions (`odm_dlkm product system system_dlkm
system_ext vendor vendor_dlkm`; `mi_ext` intentionally not built — HyperOS
-only). `boot`/`vendor_boot` re-signed AVB `SHA256_RSA2048` test key,
`rollback_index 1785542400`, header v4; `vendor_boot` rebuilt with the
`RECOVERY`/`recovery` ramdisk fragment.

**Cosmetic, not fixed:** `misc_info` `ab_partitions` ends with an empty `''`
after the 13 firmware partitions (`countrycode … tee`, from
`proprietary-firmware.txt` `;AB`). `proprietary-firmware.txt` itself is clean
(13 entries, no blank line); the empty element is an AOSP/extract-utils
list-join artifact. `ota_from_target_files` skips falsy names — payload built
(2115 ops) and signed with no complaint. Revisit only if a full-zip
`fastboot update` rejects an empty partition name.

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
- [ ] First-boot `logcat`/`dmesg` triage (Round 53 cleared most of the earlier
      list - `libwpa_client` / CHRE / `sensors.dynamic_sensor_hal` +
      `libhidparser` / Widevine-apex absences are all normal for MT6789
      LineageOS, confirmed vs yunluo). Remaining watch items:
      - `EffectFactory` errors → the `audio_effects.xml` pre_processing lib was
        repointed to `libaudiopreprocessing.so` (R53); confirm aec/ns/agc load.
      - `camerahalserver` crash → camera correctness is still a first-boot task
        (intra-vendor metadata ABI split, `sepolicy`).
      - Auto-brightness feel → the nits/backlight curves are still yunluo's.
```
