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

**State (2026-09-11):** pushed to `kodeaqua/android_device_xiaomi_taiko_wip`
`lineage-23.2`. `brunch taiko` completes cleanly (since Round 51) — all work
since is **real-hardware flash debugging** (Rounds 52-66, full detail in
`README.md`). Recovery boots (Round 54/55, `adb` reachable); **normal system
boot has never yet succeeded** — silent hang at the splash, no crash/pstore
trace even with a forced `hung_task_panic`/`softlockup_panic` diagnostic
(Round 60). **Round 63 found the root cause** (static audit, validated
Round 64-66 against a real completed `brunch taiko` output — full `NEEDED`
transitive closure resolved from all three mitee-related binaries, `tools/
verify-build.sh --deep` now: 135 PASS / 13 WARN / 5 FAIL, all five confirmed
non-boot-critical camera-AI/VoLTE gaps unrelated to this fix): the two mitee
KeyMint/Gatekeeper HAL blobs carry `DISABLE_CHECKELF`, so soong never saw
their AOSP support-lib dependencies and installed **none** of them into
`/vendor/lib64` — the HALs die at the dynamic linker, keystore2 never
reaches a KeyMint, and Android 16's `init.rc` blocks forever in
`on post-fs-data` at `wait_for_prop keystore.module_hash.sent true` (no
timeout → no adb, no panic, no pstore, recovery unaffected). Fixed by
installing 14 vendor variants explicitly in `device.mk` + a
`libcppbor_external`→`libcppbor` `replace_needed`; `verify-build.sh` now has
a standing sweep (Round 65/66) that resolves every `;DISABLE_CHECKELF`
blob's `NEEDED` against the real built image and FAILs on anything
unresolved — this exact bug class (a blob whose deps nothing installs)
cannot silently recur. **Round 61's `PLATFORM_SECURITY_PATCH := 2026-08-01`
pin didn't build** (`version_util.mk` hard-errors — that var has been
release-flag-locked, not device-tree-settable, since AOSP's Trunk Stable
migration) **and was unnecessary anyway** — this device's own `bp4a` release
token already carries `2026-08-01` via `vendor/lineage`'s own
`RELEASE_PLATFORM_SECURITY_PATCH`, confirmed against a real build's
`system/build.prop`; Round 64 deleted the dead assignment. **Not yet
confirmed on real hardware** — one thing flagged worth watching once it is:
`on post-fs-data` runs ART's `odsign` (keystore2/KeyMint-dependent) right
after the line this fix unblocks, never yet reached to confirm it doesn't
hit its own separate issue. Camera is **enabled** (though its own AI-algo
libs are missing `libc++_shared.so` — Round 66, deferred, not boot-related).
`configs/audio|media|wifi` are taiko's own now. `BOARD_SUPER_PARTITION_SIZE`
is real (11 GiB from the scatter).

**Rule learned the hard way (Round 63):** dropping a blob because it collides
with an AOSP source module is only *half* a fix. `vendor_available: true`
makes a lib **buildable** for vendor; soong installs the vendor variant only
when an **installed vendor module depends on it**. A prebuilt HAL with
`;DISABLE_CHECKELF` declares no dependencies at all — so its libs silently
never ship. Whenever you drop a blob lib "because source provides it", add
the corresponding `<module>.vendor` to `device.mk` **in the same change**,
and prefer fixing `check_elf` over disabling it.

**Rule learned the hard way (Round 64):** `PLATFORM_SECURITY_PATCH` (and its
siblings like `TARGET_PLATFORM_VERSION`) cannot be set in a device tree at
all anymore — `build/make/core/version_util.mk` hard-errors on direct
assignment. The real override point for a release-flag-locked var is
`vendor/lineage/release/flag_values/<release-token>/RELEASE_<NAME>.
textproto` (LineageOS's own repo, not this device tree) — check what it
*already* says before assuming a value needs pinning; it frequently already
has the right one. Verify a static-audit fix like this against a real build
before trusting it (`out/target/product/<device>/` if one already exists,
`soong_ui.bash --dumpvars-mode --vars="X"` for a single var, or just
`brunch`) — a "no device access" round's reasoning can be right about the
problem and still wrong about the fix.

## File responsibilities

| File | Owns |
|---|---|
| `BoardConfig.mk` | partitions, filesystem types, AVB, boot/vendor_boot layout, kernel-module wiring, SELinux/Wi-Fi board flags |
| `device.mk` | `PRODUCT_PACKAGES` / `PRODUCT_COPY_FILES` — **blob-first**, only non-blob HALs + Lineage extras. Does **not** own `PLATFORM_SECURITY_PATCH` (Round 61 tried, Round 64 found it's release-flag-locked and unnecessary — see `vendor/lineage`'s `bp4a` release config) |
| `lineage_taiko.mk` | product identity, `inherit-product` chain (`core_64_bit_only` + `full_base` + `common_full_tablet_wifionly`) |
| `AndroidProducts.mk` | lunch combos |
| `extract-files.py` / `setup-makefiles.py` | blob extractor; `blob_fixups` map is tuned against `check_elf` output |
| `proprietary-files.txt` | ~2.2k blobs (aospdtgen, this exact build, pruned ~1400 lines across 25 rounds) |
| `proprietary-firmware.txt` | non-super firmware partitions (`dpm`, `gz`, `lk`, `md1img`, `tee`, …) |
| `configs/props/*.prop` | per-partition props, wired via `TARGET_*_PROP` in `BoardConfig.mk` |
| `configs/vintf/manifest.xml` | device VINTF manifest — **verbatim stock** (`<sepolicy><version>202504</version>` + HAL `<version>`s), verified = dump. Plus `manifest_audio_aidl.xml` (2nd `DEVICE_MANIFEST_FILE`, the `audio.core` AIDL HALs). No `DEVICE_MATRIX_FILE` — stock's needs the unbuilt `mediatek-common` jar. `device_framework_matrix.xml` (`DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE`, alongside the MTK one) marks the proprietary Xiaomi/Dolby vendor HALs + `mtkpower@3` optional so OTA-time `checkvintf` passes — see README Round 35. |
| `configs/audio\|media\|wifi/` | **taiko's own, from `dump-ota/vendor/etc/`** (replaced the yunluo copies). `seccomp/` still MT6789-generic. |
| `rootdir/etc/fstab.mt6789` | first-stage **and** recovery fstab (erofs+ext4 fallback lines) |
| `rootdir/etc/*.rc`, `rootdir/bin/*.sh` | MTK init scripts from the stock vendor ramdisk; each has a `prebuilt_etc`/`sh_binary` in `rootdir/Android.bp` **and** a line in `device.mk` `PRODUCT_PACKAGES` — keep both in sync |
| `sepolicy/vendor/` | **yunluo starting point** — regenerate from first-boot `avc: denied` |
| `recovery/root/` | auto-merged into the recovery ramdisk root by `build/make/core/Makefile` (`$(TARGET_DEVICE_DIR)/recovery/root`, no `BoardConfig.mk`/`device.mk` wiring needed). Currently just `init.recovery.mt6789.rc` — forces recovery's USB gadget onto configfs (AOSP recovery's stock `init.rc` defaults to the legacy `android_usb` sysfs path, which this kernel doesn't implement) — see README Round 55. |
| `overlay/`, `overlay-lineage/` | RRO packages (in `PRODUCT_PACKAGES`, **not** `DEVICE_PACKAGE_OVERLAYS`). `power_profile.xml` battery = 9000, `config_defaultPeakRefreshRate` = 90 (right); auto-brightness curves still yunluo's |
| `prebuilt/` | `boot.img`/`dtbo.img` (used as-is), `vendor_boot.img` (reference), `dtb/mt6789.dtb`, `modules/`, `vendor_dlkm/`, `system_dlkm/`, `vendor_ramdisk.cpio.lz4` (stock PLATFORM vendor_boot fragment, byte-for-byte — see Round 54). `vendor_dlkm/modules.blocklist` blocks `metis`/`mi_schedule` (crash NULL-derefs on real boot — Round 58); needs `vendor/etc/init.insmod.mt6789.cfg`'s `blob_fixup` (`modprobe|-b *`) to actually take effect, since plain `modprobe -a` ignores it. **`metis`/`mi_schedule` also ship as a *second*, independent copy baked directly into `vendor_ramdisk.cpio.lz4` itself** (`lib/modules/metis.ko` + `modules.load.recovery`, read only when RECOVERY is concatenated onto PLATFORM — i.e. entering recovery) — the vendor_dlkm blocklist above can't reach it (`/vendor` isn't mounted yet). Blocked via a `lib/modules/modules.blocklist` entry **spliced directly into the cpio byte stream** (new cpio entry inserted before `TRAILER!!!`, nothing else re-serialized) — see Round 59. **Never extract+repack this file wholesale as a non-root user** — every entry's stored `root:root` ownership silently collapses to the extracting user's uid/gid, which the on-device unpacker needs correct; always splice new entries in instead, or repack under `fakeroot`. |
| `kernel-headers/Makefile` | stub `TARGET_KERNEL_SOURCE` (wired in `BoardConfig.mk`). No kernel source, but LineageOS' `generated_kernel_includes` genrule (pulled by `generated_kernel_headers` consumers, e.g. `PowerOffAlarm`) still runs `make -C $(TARGET_KERNEL_SOURCE) headers_install` — stub makes an empty `usr/include`. See README Round 31. |

## Boot / kernel model (do not "fix" this into a normal kernel build)

- `boot.img`: stock GKI, **kernel-only** (`ramdisk_size = 0`), consumed via
  `TARGET_NO_KERNEL := true` + `BOARD_PREBUILT_BOOTIMAGE`. Build only rewrites
  its AVB footer.
- No `init_boot` partition — do **not** add `BOARD_PREBUILT_INIT_BOOT_IMAGE` /
  `BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE`. With `BOARD_USES_GENERIC_KERNEL_IMAGE`
  the build concatenates the generic ramdisk into **vendor_boot** — that is the
  documented AOSP path, no extra flag needed.
- `vendor_boot.img`: **rebuilt** from `prebuilt/dtb/` + `prebuilt/modules/` +
  generic ramdisk + Lineage recovery. Header v4. Recovery is a **separate**
  fragment (`ramdisk_type` RECOVERY, name `recovery`) — needs BOTH
  `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true` **and**
  `BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true`. The "2 ramdisks" =
  PLATFORM + RECOVERY, nothing else (no "dlkm" fragment).
- **The PLATFORM (0x1) fragment is the real stock one, not this build's own.**
  taiko's bootloader/LK loads PLATFORM **alone** for a normal boot (no
  concatenation with RECOVERY — that only happens entering recovery), and
  since there's no `init_boot` it has to be a complete standalone first-stage
  rootfs (generic AOSP init tree **and** vendor bits). This build's own
  generated PLATFORM fragment is real but not equivalent — confirmed on the
  sibling `kodeaqua/android_device_xiaomi_taiko-twrp` tree (same device) that
  it panics early (`Unable to mount root fs on /dev/ram`, before the fb
  console is up — looks like "boot logo then power off", no visible error).
  Fixed via `build/tasks/vendor_boot.mk` repointing
  `INTERNAL_VENDOR_RAMDISK_TARGET` at `prebuilt/vendor_ramdisk.cpio.lz4`
  (stock's PLATFORM fragment, extracted byte-for-byte from
  `prebuilt/vendor_boot.img`). Do **not** "clean this up" back to the
  generated fragment — see README Round 54 and the comment in that file for
  the full mechanism + evidence. RECOVERY stays built from source, untouched.
  Being stock-verbatim, this fragment carries its **own** embedded
  `lib/modules/*.ko` + `modules.load`/`modules.load.recovery`, entirely
  separate from `prebuilt/vendor_dlkm/` — see the `prebuilt/` row above
  (Round 59) before assuming a vendor_dlkm-side kernel-module fix reaches
  recovery too.
- `dtbo.img`: stock, `BOARD_PREBUILT_DTBOIMAGE`. `BOARD_KERNEL_SEPARATED_DTBO`
  is deliberately unset (build-from-source flag only).
- `odm` is folded into `/vendor/odm` (`TARGET_COPY_OUT_ODM := vendor/odm`) — no
  `odm` partition. `odm_dlkm` IS its own logical partition.
- Virtual A/B (not legacy): super carries ONE copy of the logical set →
  `BOARD_<group>_SIZE ≈ BOARD_SUPER_PARTITION_SIZE`, never `/2`.
- All `.ko` are prebuilt and KMI-locked to stock GKI `6.12.30-android16-5`. If
  you swap the kernel/GKI build, re-extract every module set.
- `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` (device.mk) — mandatory
  with `TARGET_NO_KERNEL`: no `$(PRODUCT_OUT)/kernel` ⇒ `check_vintf` (strict at
  API 36) has nothing to match the FCM `<kernel>` section against. Do NOT drop
  this unless you switch to a repacked boot.img that ships `:kernel`.
- DTO: stock `dtbo.img` + stock vendor_boot `dtb/` reused as prebuilts (base and
  overlays guaranteed to match). No `BOARD_DTBO_CFG` / `BOARD_KERNEL_SEPARATED_DTBO`.

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

`device.mk` adds source modules ONLY where there is no usable blob, the blob
name collides with a source module, or HyperOS shipped a verbatim-AOSP blob.
Current source list: `vendor.lineage.health-service.default`,
`android.hardware.health-service.example`, `android.hardware.sensors-service.multihal`,
`wpa_supplicant`, `hostapd`, `PowerOffAlarm`, `create_pl_dev`,
`drm-service.clearkey`, `fastbootd`, `libmtkperf_client_vendor`,
`libperfctl_vendor`, `libpowerhalwrap_vendor`, `libaedv`, `libladder`,
`chipinfo`, `wlan_assistant`, `libwifi-hal-wrapper`,
`vendor.mediatek.hardware.mtkpower@1.2`,
`android.hardware.memtrack-service.mediatek`,
`android.hardware.thermal-service.mediatek`, `thermal_symlinks_mediatek`,
RRO overlays, init scripts, feature permission XMLs.

**Never** add a `hardware/mediatek` source HAL that a blob already covers with a
DIFFERENT name (bluetooth, boot, audio, usb, vibrator) — you'd run two.

**Power**: kept the stock MediaTek blob stack
(`vendor.mediatek.hardware.mtkpower-service.mediatek` + `power-mediatek.xml`) for
`android.hardware.power/IPower/default`. The pixel-libperfmgr switch was tried
and **reverted** (its `libpowerhal`/`libaimemc` need `libpower_timer` /
`mtkpower-V1-ndk` from the source stack). Do not re-add
`android.hardware.power-service.pixel-libperfmgr`. `configs/powerhint.json` is
parked, uncopied.

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

Rounds 18-25 hit **three more variants of the same idea** — a blob and a
non-blob both produce the same thing:

1. **Module-name clash with `hardware/interfaces` / `hardware/libhardware` /
   `frameworks` / `external`**, not just `hardware/mediatek`. HyperOS ships AOSP
   reference impls verbatim (`android.hardware.health-service.example`,
   `sensors-service.multihal`, `test-nusensors`, `*.default.so` passthrough
   HALs, `libbluetooth_audio_session*`, legacy HIDL impls). → delete the blob;
   `PRODUCT_PACKAGES += <the source module>` if it isn't pulled by a base config.
2. **Install-path clash** (`error: overriding commands for target '<out path>'`).
   Same file, two producers — a blob `prebuilt_etc` and either an AOSP
   `prebuilt_etc`/`vintf_fragment` (`bluetooth_audio.xml`, LE-audio/HFP configs,
   `mkshrc`, boringssl `.rc`) **or** a build generator (`aconfig/*`,
   `aconfig_flags.pb`, `build_flags.json`, `linker.config.pb`, per-partition
   `modules.load` from `BOARD_*_KERNEL_MODULES_LOAD`, the device `fstab` we
   already ship from `rootdir/`). → delete the blob line (and any redundant
   `PRODUCT_COPY_FILES`).
3. **VINTF xml can't go through `PRODUCT_COPY_FILES`** — the build scans copies
   for VINTF content and rejects them. Merge as a second `DEVICE_MANIFEST_FILE`.

Scan against the local `android_hardware_interfaces/` (repo root, `lineage-23.2`)
for `prebuilt_etc`/`vintf_fragment` `name:`/`src:`/`filename:` + `sub_dir:` and
compare install paths to the blob list. `frameworks/`, `system/`, `packages/`,
`external/` are NOT on this machine — those collisions can only be caught from
the actual kati error.

## Build (on the other machine)

```
breakfast taiko && brunch taiko          # from ~/android/lineage
# re-extract only when extract-files.py changed or a blob was added:
rm -rf vendor/xiaomi/taiko && ./device/xiaomi/taiko/extract-files.py <ota.zip>
```

## When editing

- Values come from `../../../dump-ota/`, not from the yunluo tree.
- Keep SPDX headers: `SPDX-FileCopyrightText: 2026 The LineageOS Project`.
- Adding/removing an init `.rc`: update `rootdir/Android.bp` **and** `device.mk`.
- Adding a blob: `proprietary-files.txt` + (if ELF-broken) a `blob_fixups` entry.
- Don't silently replace a `TODO`/placeholder with a guess — see `README.md`.
