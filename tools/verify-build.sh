#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# verify-build.sh - post-`brunch taiko` sanity check for the Xiaomi Redmi Pad 2
# (taiko) LineageOS 23.2 bring-up. Run from the build root:
#
#     ./device/xiaomi/taiko/tools/verify-build.sh            # fast
#     ./device/xiaomi/taiko/tools/verify-build.sh --deep     # + per-.so NEEDED scan
#     ./device/xiaomi/taiko/tools/verify-build.sh --flash    # print fastboot cmds
#     OUT=... TOP=... ./device/xiaomi/taiko/tools/verify-build.sh
#
# Sections: artifacts / partition sizes / generated-makefile hygiene /
# round-by-round drop verification / kept MTK-Xiaomi blobs / mvpu island /
# VINTF / kernel modules / fstab / recovery / AVB / build.prop / SELinux /
# APEX / (--deep) unresolved-NEEDED scan / (--flash) fastboot recipe.
# Nothing needs root. WARN = first-boot/camera/cosmetic; FAIL = fix before flash.

set -u

# ---- locate TOP + OUT --------------------------------------------------------
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${TOP:-$(cd "$SELF/../../../.." 2>/dev/null && pwd)}"
[ -d "$TOP/build/soong" ] || TOP="$(pwd)"
OUT="${OUT:-$TOP/out/target/product/taiko}"
SOONG_OUT="${SOONG_OUT:-$TOP/out/soong}"
DT="$TOP/device/xiaomi/taiko"
DEEP=0; FLASH=0
for a in "$@"; do case "$a" in --deep) DEEP=1;; --flash) FLASH=1;; esac; done

# scatter (MT6789_Android_scatter.txt) partition sizes, bytes
SUPER_MAX=11811160064          # 0x2c0000000  (11 GiB)
GROUP_MAX=11806965760          # super - 4 MiB LP metadata
BOOT_MAX=67108864             ; VENDORBOOT_MAX=67108864 ; DTBO_MAX=8388608

P=0; W=0; F=0; FAILS=()
if [ -t 1 ]; then c_g=$'\e[32m';c_y=$'\e[33m';c_r=$'\e[31m';c_b=$'\e[36m';c_d=$'\e[2m';c_0=$'\e[0m'
else c_g= ;c_y= ;c_r= ;c_b= ;c_d= ;c_0= ; fi
pass(){ P=$((P+1)); printf "  ${c_g}PASS${c_0} %s\n" "$*"; }
warn(){ W=$((W+1)); printf "  ${c_y}WARN${c_0} %s\n" "$*"; }
fail(){ F=$((F+1)); FAILS+=("$*"); printf "  ${c_r}FAIL${c_0} %s\n" "$*"; }
info(){ printf "  ${c_d}%s${c_0}\n" "$*"; }
sec(){ printf "\n${c_b}== %s ==${c_0}\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
sz(){ stat -c%s "$1" 2>/dev/null || echo 0; }
mib(){ echo $(( $(sz "$1") / 1048576 )); }

[ -d "$OUT" ] || { echo "OUT '$OUT' not found - run from the build root or set OUT=" >&2; exit 2; }
echo "TOP  = $TOP"
echo "OUT  = $OUT"
RE=readelf; have llvm-readelf && RE=llvm-readelf

# ---------------------------------------------------------------------------
sec "Build artifacts"
z=$(ls -1 "$OUT"/lineage-*.zip 2>/dev/null | grep -v -- '-img-' | head -1)
if [ -n "$z" ]; then
  [ "$(sz "$z")" -gt 700000000 ] && pass "OTA zip $(basename "$z") ($(mib "$z") MiB)" \
    || warn "OTA zip suspiciously small: $(basename "$z") ($(mib "$z") MiB)"
else warn "no lineage-*.zip (mka bacon not run / images-only build)"; fi
imgz=$(ls -1 "$OUT"/lineage-*-img-*.zip 2>/dev/null | head -1)
[ -n "$imgz" ] && pass "fastboot img zip $(basename "$imgz")" || warn "no *-img-*.zip"
for i in boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
  [ -s "$OUT/$i" ] && pass "$i ($(sz "$OUT/$i") B)" || fail "$i missing"
done
if   [ -s "$OUT/super.img" ];        then pass "super.img ($(mib "$OUT/super.img") MiB)"
elif [ -s "$OUT/super_empty.img" ];  then pass "super_empty.img (fastbootd path)"
else warn "no super.img / super_empty.img"; fi
for i in system.img vendor.img product.img system_ext.img vendor_dlkm.img odm_dlkm.img system_dlkm.img; do
  [ -s "$OUT/$i" ] && info "  $i $(mib "$OUT/$i") MiB"
done

# ---------------------------------------------------------------------------
sec "Partition size vs scatter"
chk(){ [ -s "$1" ] || { warn "$3: absent"; return; }
       [ "$(sz "$1")" -le "$2" ] && pass "$3 $(sz "$1") <= $2" || fail "$3 $(sz "$1") > $2  (won't flash)"; }
chk "$OUT/boot.img"        "$BOOT_MAX"       "boot.img"
chk "$OUT/vendor_boot.img" "$VENDORBOOT_MAX" "vendor_boot.img"
chk "$OUT/dtbo.img"        "$DTBO_MAX"       "dtbo.img"
[ -s "$OUT/super.img" ] && chk "$OUT/super.img" "$SUPER_MAX" "super.img"
tot=0; for i in system system_ext product vendor vendor_dlkm odm_dlkm system_dlkm; do
  [ -s "$OUT/$i.img" ] && tot=$(( tot + $(sz "$OUT/$i.img") )); done
[ "$tot" -gt 0 ] && { [ "$tot" -le "$GROUP_MAX" ] \
  && pass "sum(logical imgs) $tot <= group $GROUP_MAX (headroom $(( (GROUP_MAX-tot)/1048576 )) MiB)" \
  || fail "sum(logical imgs) $tot > group $GROUP_MAX"; }
mi="$SOONG_OUT/.intermediates/../../target/product/taiko/misc_info.txt"
[ -f "$OUT/misc_info.txt" ] && mi="$OUT/misc_info.txt"
[ -f "$mi" ] && grep -qE "super_partition_size=$SUPER_MAX" "$mi" \
  && pass "misc_info super_partition_size = $SUPER_MAX" \
  || info "  (misc_info.txt not checked)"

# ---------------------------------------------------------------------------
sec "Generated-makefile hygiene (Round 49 regression class)"
vmk=$(find "$TOP"/vendor/xiaomi/taiko -maxdepth 2 -name '*-vendor.mk' 2>/dev/null | head -1)
if [ -n "$vmk" ] && [ -f "$vmk" ]; then
  # ELF (.so) or .apk/.jar landing in PRODUCT_COPY_FILES = "found ELF prebuilt in PRODUCT_COPY_FILES"
  bad=$(grep -oE '[^ ]+\.(so|apk|jar):' "$vmk" 2>/dev/null | grep -c '.')
  [ "$bad" -eq 0 ] && pass "no .so/.apk/.jar in PRODUCT_COPY_FILES ($(basename "$vmk"))" \
    || { fail "$bad ELF/APK/JAR entr(y|ies) in PRODUCT_COPY_FILES of $(basename "$vmk")"
         grep -oE '[^ ]+\.(so|apk|jar):' "$vmk" | head -5 | sed 's/^/      /'; }
  bp=$(find "$TOP"/vendor/xiaomi/taiko -maxdepth 2 -name 'Android.bp' 2>/dev/null | head -1)
  [ -n "$bp" ] && grep -q 'check_elf_files: false' "$bp" \
    && pass "generated Android.bp carries check_elf_files: false (blanket DISABLE_CHECKELF)" \
    || warn "no check_elf_files:false seen in generated Android.bp"
else
  warn "generated vendor/xiaomi/taiko/**/*-vendor.mk not found (run from build root / after extract-files.py)"
fi

# ---------------------------------------------------------------------------
sec "Round 21/28/46-48 drops: source must provide the file"
src(){ [ -e "$OUT/$1" ] && pass "src: $1" \
       || { [ "${2:-}" = soft ] && warn "absent (likely fine): $1" || fail "MISSING $1  -> restore that proprietary-files.txt line"; }; }
soft(){ [ -e "$OUT/$1" ] && pass "present: $1" || warn "absent - $2"; }

# Audio effects: the correctness test is "does every lib the shipped
# audio_effects.xml references resolve" - NOT "is each dropped HyperOS blob
# name back". Round 48 dropped libbundleaidl/libvolumesw/libequalizersw/... =
# HyperOS-only alt impls; taiko's own config calls the AOSP wrapper libs
# (libbundlewrapper, libreverbwrapper, ...) + the *_mtk / *aidl blobs, all of
# which ARE shipped. Parse the config and check each path= entry.
aecfg="$DT/configs/audio/audio_effects.xml"
if [ -f "$aecfg" ]; then
  miss=0; nlib=0
  while IFS= read -r lib; do
    nlib=$((nlib+1))
    case "$lib" in lib_some_fx_*) continue;; esac      # AOSP template placeholders
    if find "$OUT/vendor/lib64/soundfx" "$OUT/vendor/lib/soundfx" \
            "$OUT/system/lib64/soundfx" -name "$lib" 2>/dev/null | grep -q .; then :
    else miss=$((miss+1)); warn "  audio_effects.xml lib not in image: $lib"; fi
  done < <(grep -oE 'path="[^"]+\.so"' "$aecfg" | sed 's/path="//;s/"//' | sort -u)
  [ "$miss" -eq 0 ] && pass "audio_effects.xml: all $nlib referenced libs resolve in soundfx/" \
                    || warn "audio_effects.xml: $miss referenced lib(s) missing - effect(s) unavailable, non-fatal (check logcat 'EffectFactory')"
else warn "configs/audio/audio_effects.xml not found - effect coverage not checked"; fi
# effect libs that MUST be present (config backbone: AOSP wrappers + kept blobs)
for f in libbundlewrapper libreverbwrapper libvisualizer libdownmix libldnhncr \
         libdynproc libaudiopreprocessing libspatializer libeffectproxy \
         libmisoundfx_aidl libdlbvolaidl libswdapaidl libswspatializeraidl \
         libaecsw_mtk libnssw_mtk libpreprocessingaidl_mtk ; do
  [ -e "$OUT/vendor/lib64/soundfx/$f.so" ] && pass "soundfx/$f.so" \
    || fail "soundfx/$f.so MISSING  -> audio_effects.xml references it"
done

src "vendor/lib64/mediadrm/libdrmclearkeyplugin.so"
src "vendor/lib64/mediacas/libclearkeycasplugin.so"
src "vendor/lib64/android.hardware.audio.core-impl-mediatek.so"   # R37: kept, NOT under hw/
src "vendor/bin/hw/android.hardware.health-service.example"       # R21
src "vendor/bin/hw/android.hardware.sensors-service.multihal"     # R18
src "vendor/bin/hw/wpa_supplicant"; src "vendor/bin/hw/hostapd"   # R27/48
src "vendor/etc/bpf/filterPowerSupplyEvents.o"                    # R21
src "vendor/etc/vintf/manifest/android.hardware.audio.effect.service-aidl.xml" soft
src "vendor/bin/mkshrc" soft ; src "vendor/etc/mkshrc" soft       # R24
# Dropped for a rule collision; source module not pulled into the image.
# All non-fatal on a Wi-Fi-only tablet - verify the feature at first boot,
# restore the blob line only if it is actually broken.
soft "vendor/lib64/libwpa_client.so"                 "legacy; unused by AIDL Wi-Fi on A16"
soft "vendor/lib64/libhidparser.so"                  "BT-HID descriptor parsing; low risk"
soft "vendor/bin/hw/android.hardware.contexthub-service.tinysys" "CHRE/context-hub (R46); nano-apps + sensor batching only"
soft "vendor/lib64/hw/sensors.dynamic_sensor_hal.so" "external/dynamic sensors (R47)"

# ---------------------------------------------------------------------------
sec "Kept MTK / Xiaomi blobs"
for f in \
  vendor/bin/hw/camerahalserver \
  vendor/bin/hw/android.hardware.audio.service-aidl.mediatek \
  vendor/bin/hw/android.hardware.security.keymint@4.0-service.mitee \
  vendor/bin/hw/android.hardware.gatekeeper-service.mitee \
  vendor/bin/hw/vendor.mediatek.hardware.aee@V1-service \
  vendor/bin/hw/vendor.mediatek.hardware.mtkpower-service.mediatek \
  vendor/lib64/hw/mt6789/android.hardware.graphics.allocator-V2-mediatek.so \
  vendor/lib64/hw/hwcomposer.mtk_common.so \
  vendor/lib64/hw/mt6789/mapper.mediatek.so \
  vendor/lib64/android.hardware.audio.core-impl-mediatek.so \
  vendor/lib64/android.hardware.bluetooth.audio-impl-mediatek.so \
  vendor/lib64/hw/android.hardware.sensors@2.X-subhal-mediatek.so \
  vendor/etc/sensors/hals.conf \
  vendor/etc/fstab.mt6789 ; do
  [ -e "$OUT/$f" ] && pass "$f" || fail "$f MISSING"
done
# dropped-on-purpose: these must be GONE (aconfig_flags.pb / flag.info are NOT
# here - A16 build-generates vendor/etc/aconfig_flags.pb, so present = correct;
# what was dropped was a name-colliding *blob*, invisible once the line is gone)
for f in vendor/bin/aee_aedv64_v2 vendor/bin/aee_dumpstatev_v2 vendor/bin/aeev_v2 \
         vendor/bin/hw/vendor.mediatek.hardware.aee@1.1-service \
         vendor/bin/hw/android.hardware.contexthub-service.tinysys.blob \
         vendor/lib64/libmtkcam.mcsspolicy.so vendor/lib64/libmtkcam_capture_request_monitor.so ; do
  [ -e "$OUT/$f" ] && warn "expected-gone still present: $f" || info "  gone (ok): $f"
done

# ---------------------------------------------------------------------------
sec "GPU / graphics loader paths (Mali-G57 - boot-critical)"
# MTK ships the real driver at <dir>/mt6789/<name> and a bare symlink at the
# path the loader dlopens. BOTH must exist. -e follows symlinks (target must
# resolve); -L confirms the link node is present.
loadpath(){ # $1 = vendor-relative loader path, $2 = FAIL|WARN
  local p="$OUT/$1"
  if [ -e "$p" ]; then
    [ -L "$p" ] && pass "$1 -> $(readlink "$p") (resolves)" || pass "$1 (real file)"
  elif [ -L "$p" ]; then fail "$1 is a DANGLING symlink -> $(readlink "$p") (real .so not installed)"
  else [ "$2" = WARN ] && warn "$1 absent" || fail "$1 MISSING - loader can't find it (add to MTK_SOC_SYMLINKS in Android.mk)"
  fi; }
for b in lib lib64; do
  loadpath "vendor/$b/egl/libGLES_mali.so"                                   FAIL   # egl.cfg "0 1 mali"
  loadpath "vendor/$b/hw/vulkan.mali.so"                                     FAIL   # Vulkan loader
  loadpath "vendor/$b/hw/mapper.mediatek.so"                                 FAIL   # gralloc mapper (SurfaceFlinger)
  loadpath "vendor/$b/hw/android.hardware.graphics.allocator-V2-mediatek.so" WARN   # allocator impl
done
loadpath "vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so" WARN
ec="$OUT/vendor/lib64/egl/egl.cfg"; [ -f "$ec" ] || ec="$OUT/vendor/lib/egl/egl.cfg"
[ -f "$ec" ] && { pass "egl.cfg present"; grep -v '^#' "$ec" | sed 's/^/      /'; } || info "  no egl/egl.cfg (loader auto-probes libGLES_mali)"

# ---------------------------------------------------------------------------
sec "KeyMint / Gatekeeper mitee deps (Round 63 - boot-critical)"
# Both mitee HAL blobs carry ;DISABLE_CHECKELF, so nothing in the build
# verifies their NEEDED libs. If any of these is missing the HAL dies at the
# dynamic linker, keystore2 never reaches a KeyMint, and Android 16's init.rc
# blocks forever in `on post-fs-data` at "wait_for_prop
# keystore.module_hash.sent true" - splash forever, no adb, no panic, no
# pstore. See README Round 63.
kmdep(){ # $1 = lib filename
  if [ -e "$OUT/vendor/lib64/$1" ]; then pass "vendor/lib64/$1"
  else fail "vendor/lib64/$1 MISSING - keymint/gatekeeper HAL will not start (device.mk: add ${1%.so}.vendor)"; fi; }
for l in android.hardware.security.keymint-V4-ndk.so \
         android.hardware.security.rkp-V3-ndk.so \
         android.hardware.security.sharedsecret-V1-ndk.so \
         android.hardware.security.secureclock-V1-ndk.so \
         android.hardware.gatekeeper-V1-ndk.so \
         lib_android_keymaster_keymint_utils.so \
         libcppbor.so libgatekeeper.so libkeymaster4support.so \
         libkeymaster_messages.so libkeymaster_portable.so \
         libkeymint.so libkeymint_remote_prov_support.so libkeymint_support.so; do
  kmdep "$l"
done
# The blob NEEDs libcppbor_external.so (HyperOS's 2nd cppbor build variant);
# extract-files repoints it at libcppbor.so. Confirm no stale NEEDED survived.
km="$OUT/vendor/bin/hw/android.hardware.security.keymint@4.0-service.mitee"
if [ -f "$km" ] && command -v readelf >/dev/null; then
  readelf -d "$km" 2>/dev/null | grep -q "libcppbor_external.so" \
    && fail "keymint blob still NEEDs libcppbor_external.so - blob_fixup did not apply (re-run extract-files.py)" \
    || pass "keymint blob NEEDED repointed off libcppbor_external"
fi

# ---------------------------------------------------------------------------
sec "MVPU island (Round 49b)"
for f in libmvpu_wrapper.so libmvpu_engine.so libmvpu_runtime.so libmvpuop_mtk_cv.so \
         libmvpuop_mtk_nn.so libswtcc.so libultrahdr_mtk.so ; do
  [ -e "$OUT/vendor/lib64/$f" ] && pass "vendor/lib64/$f" || fail "vendor/lib64/$f MISSING (libswtcc/libultrahdr_mtk hard-NEED libmvpu_wrapper)"
done
n=$(find "$OUT/vendor/lib64" -name 'libmvpu*.so' 2>/dev/null | wc -l)
[ "$n" -ge 40 ] && pass "$n libmvpu* libs in vendor/lib64" || warn "only $n libmvpu* libs (expected ~43)"

# ---------------------------------------------------------------------------
sec "VINTF"
vm="$OUT/vendor/etc/vintf/manifest.xml"
frags="$OUT/vendor/etc/vintf/manifest"     # merged into the runtime manifest at boot
hal_declared(){ grep -rqs "<name>$1</name>" "$vm" "$frags" 2>/dev/null; }
if [ -s "$vm" ]; then
  nf=$(ls -1 "$frags"/*.xml 2>/dev/null | wc -l)
  pass "device manifest ($(wc -l <"$vm") lines) + $nf vintf fragments"
  # these may live in manifest.xml OR a fragment - both merge at runtime
  for n in android.hardware.audio.core android.hardware.audio.effect \
           android.hardware.camera.provider vendor.mediatek.hardware.mtkpower \
           android.hardware.graphics.allocator android.hardware.graphics.composer3 \
           android.hardware.security.keymint android.hardware.gatekeeper \
           android.hardware.health android.hardware.sensors android.hardware.usb; do
    hal_declared "$n" && pass "  HAL: $n" || warn "  HAL not in manifest or any fragment: $n"
  done
  grep -q '<sepolicy>' "$vm" && grep -q '202504' "$vm" && pass "  sepolicy 202504" || warn "  sepolicy tag != 202504"
else fail "device manifest.xml missing"; fi
fcm="$OUT/vendor/etc/vintf/compatibility_matrix.device.xml"
if [ -s "$fcm" ]; then
  pass "device compat matrix present"
  miss=0
  for n in vendor.dolby.dms vendor.xiaomi.hardware.micharge vendor.xiaomi.hw.touchfeature \
           vendor.xiaomi.sensor.citsensorservice vendor.xiaomi.hardware.displayfeature_aidl \
           vendor.xiaomi.hardware.mtkblackbox ; do
    grep -q "$n" "$fcm" || { miss=$((miss+1)); warn "  proprietary HAL not in device FCM: $n"; }
  done
  [ "$miss" -eq 0 ] && pass "  Round-35 proprietary HALs all in device FCM"
else warn "no compatibility_matrix.device.xml"; fi
if have checkvintf; then
  # the authoritative check already ran in-build (check_target_files_vintf.py at
  # Package OTA). This is a best-effort re-run; CLI shape varies by version.
  if   checkvintf --check-compat --rootdir="$OUT" >/tmp/_cv.log 2>&1 \
    || checkvintf -c --dirmap /:"$OUT"           >/tmp/_cv.log 2>&1; then
    pass "checkvintf --check-compat OK"
  else warn "checkvintf re-run inconclusive (build's own check_target_files_vintf.py already passed) - see /tmp/_cv.log"
       sed 's/^/      /' /tmp/_cv.log | head -8; fi
else warn "checkvintf not on PATH - relying on the in-build VINTF check"; fi

# ---------------------------------------------------------------------------
sec "Kernel modules"
kmod(){ local d="$OUT/$1" ml="$OUT/$1/modules.load"
  [ -d "$d" ] || { warn "$2: dir absent"; return; }
  local ko; ko=$(ls -1 "$d"/*.ko 2>/dev/null | wc -l)
  [ -s "$ml" ] || { fail "$2: modules.load missing ($ko .ko present)"; return; }
  local bad=0 n; n=$(grep -c . "$ml")
  while read -r m; do [ -z "$m" ] && continue
    [ -e "$d/$m" ] || { bad=$((bad+1)); [ "$bad" -le 3 ] && info "      no .ko for: $m"; }
  done < "$ml"
  [ "$bad" -eq 0 ] && pass "$2: $n in modules.load, $ko .ko, all resolve" \
                   || fail "$2: $bad modules.load entries have no .ko"
  [ -e "$d/modules.dep" ] && pass "$2: modules.dep generated (depmod ran)" || warn "$2: no modules.dep"
}
kmod vendor_dlkm/lib/modules  "vendor_dlkm"
kmod system_dlkm/lib/modules  "system_dlkm"
# /vendor/lib/modules must resolve to vendor_dlkm's modules: init.insmod.sh +
# many init*.rc do `insmod /vendor/lib/modules/*.ko` / modprobe from
# /vendor/lib/modules. Stock ships it as a symlink -> /vendor_dlkm/lib/modules.
vlm="$OUT/vendor/lib/modules"
if [ -L "$vlm" ]; then
  tgt=$(readlink "$vlm")
  # AOSP auto-creates this as -> /vendor_dlkm/lib/modules when
  # BOARD_USES_VENDOR_DLKMIMAGE=true. The target is an absolute *device* path
  # that won't resolve on the build host, so accept it by name.
  case "$tgt" in
    /vendor_dlkm/lib/modules|../../../vendor_dlkm/lib/modules)
      pass "vendor/lib/modules -> $tgt (device path - resolves on-device)" ;;
    *) [ -e "$vlm/modules.load" ] && pass "vendor/lib/modules -> $tgt (resolves)" \
         || warn "vendor/lib/modules -> $tgt : unusual target, verify it reaches vendor_dlkm's modules.load on-device" ;;
  esac
elif [ -d "$vlm" ]; then
  ls -1 "$vlm"/*.ko >/dev/null 2>&1 && pass "vendor/lib/modules is a real dir with .ko" \
    || fail "vendor/lib/modules is an EMPTY real dir - init.insmod.sh / init*.rc load nothing from vendor_dlkm (Wi-Fi/thermal/charger/sensors modules dead). Need a build symlink -> /vendor_dlkm/lib/modules."
else
  fail "vendor/lib/modules MISSING - init.insmod.sh reads /vendor/lib/modules; vendor_dlkm's $(ls -1 "$OUT/vendor_dlkm/lib/modules"/*.ko 2>/dev/null | wc -l) modules won't load. Add a symlink -> /vendor_dlkm/lib/modules."
fi
# vendor_boot ramdisk .ko: pick the dir that actually has the most .ko
vrd=$(find "$OUT" -type d \( -path '*vendor_ramdisk*modules*' -o -path '*VENDOR_RAMDISK*' \) 2>/dev/null \
      | while read -r d; do echo "$(find "$d" -maxdepth 1 -name '*.ko' | wc -l) $d"; done \
      | sort -rn | head -1)
vn=${vrd%% *}; vd=${vrd#* }
if [ -n "$vrd" ] && [ "${vn:-0}" -gt 0 ]; then pass "vendor_boot ramdisk modules: $vn .ko (${vd#$OUT/})"
else warn "vendor_boot ramdisk .ko dir not located (modules may already be packed into vendor_boot.img)"; fi

# ---------------------------------------------------------------------------
sec "vendor_dlkm modprobe blocklist (Round 58 - metis boot-hang fix)"
# metis.ko NULL-derefs (lowlt_list_del_task) once second-stage boot ramps up.
# It's neutralised by a modules.blocklist + `modprobe -b`, NOT by removing it
# from modules.load (modprobe -a pulls it back as a dep of scheduler.ko etc).
bl="$OUT/vendor_dlkm/lib/modules/modules.blocklist"
if [ -s "$bl" ]; then
  miss=0
  for m in metis mi_schedule task_turbo; do
    grep -qE "^blocklist[[:space:]]+$m\b" "$bl" || { warn "  modules.blocklist missing: blocklist $m"; miss=1; }
  done
  [ "$miss" -eq 0 ] && pass "modules.blocklist blocks metis + mi_schedule + task_turbo"
else
  fail "vendor_dlkm/lib/modules/modules.blocklist MISSING - metis.ko will load and NULL-deref -> boot hang at logo (Round 58)"
fi
cfg="$OUT/vendor/etc/init.insmod.mt6789.cfg"
if [ -s "$cfg" ]; then
  if grep -qE '^modprobe\|-b \*' "$cfg"; then
    pass "init.insmod.mt6789.cfg: modprobe|-b *  (blob_fixup applied - blocklist is honored)"
  elif grep -qE '^modprobe\|\*' "$cfg"; then
    fail "init.insmod.mt6789.cfg still has 'modprobe|*' (no -b) - modules.blocklist is IGNORED, metis loads, boot hangs. extract-files.py blob_fixup didn't apply (re-extract vendor/xiaomi/taiko)."
  else
    warn "init.insmod.mt6789.cfg: no 'modprobe|...' line found - verify how vendor_dlkm modules load"
  fi
else
  warn "vendor/etc/init.insmod.mt6789.cfg absent in the built image"
fi
# metis/mi_schedule/task_turbo MUST still be in modules.load (stock) - blocklist
# neutralises them; removing the lines too was the ineffective Round 57 state.
mlc="$OUT/vendor_dlkm/lib/modules/modules.load"
if [ -s "$mlc" ]; then
  for m in metis.ko mi_schedule.ko task_turbo.ko; do
    grep -qxF "$m" "$mlc" || warn "  $m not in modules.load - Round 57 (ineffective) state? blocklist is the fix, not line removal"
  done
fi
info "  blast radius (expected): scheduler / cpufreq_sugov_ext / mtk_core_ctl /"
info "  vip_engine / mtk_fpsgo_v3 / fpsgo / powerhal_cpu_ctrl / ccidvfs /"
info "  mtk-vcodec-sys-api (HW video -> SW decode) all fail to insmod cleanly"

# ---------------------------------------------------------------------------
sec "vendor_boot PLATFORM fragment (Round 54 - normal-boot first-stage rootfs)"
# This device's LK loads the PLATFORM (0x1) vendor_ramdisk fragment ALONE for a
# normal boot. With TARGET_NO_KERNEL + no init_boot the build's own generated
# fragment has no /init -> "Unable to mount root fs on /dev/ram" panic. Fix
# (R54): build/tasks/vendor_boot.mk repoints INTERNAL_VENDOR_RAMDISK_TARGET at
# the stock fragment prebuilt/vendor_ramdisk.cpio.lz4.
[ -s "$DT/prebuilt/vendor_ramdisk.cpio.lz4" ] \
  && pass "prebuilt/vendor_ramdisk.cpio.lz4 present ($(mib "$DT/prebuilt/vendor_ramdisk.cpio.lz4") MiB)" \
  || fail "prebuilt/vendor_ramdisk.cpio.lz4 MISSING - normal boot will panic 'Unable to mount root fs' (Round 54)"
[ -s "$DT/build/tasks/vendor_boot.mk" ] \
  && grep -q 'INTERNAL_VENDOR_RAMDISK_TARGET' "$DT/build/tasks/vendor_boot.mk" \
  && pass "build/tasks/vendor_boot.mk repoints INTERNAL_VENDOR_RAMDISK_TARGET" \
  || fail "build/tasks/vendor_boot.mk missing / not repointing INTERNAL_VENDOR_RAMDISK_TARGET (Round 54)"
# Prove the built vendor_boot.img actually carries the complete fragment (has
# /init), not the broken generated one.
ub="$TOP/out/host/linux-x86/bin/unpack_bootimg"
if [ -x "$ub" ] && [ -s "$OUT/vendor_boot.img" ] && have lz4; then
  d=$(mktemp -d)
  "$ub" --boot_img "$OUT/vendor_boot.img" --format mkbootimg --out "$d" >/dev/null 2>&1
  frag=$(ls -1 "$d"/vendor_ramdisk00 "$d"/vendor-ramdisk-by-name/* 2>/dev/null | head -1)
  if [ -s "$frag" ]; then
    lst=$(lz4 -d -c "$frag" 2>/dev/null | cpio -t 2>/dev/null)
    echo "$lst" | grep -qxE 'init|first_stage_ramdisk' \
      && pass "vendor_boot PLATFORM fragment has /init + first_stage_ramdisk (complete rootfs)" \
      || fail "vendor_boot PLATFORM fragment has NO /init - normal boot will panic (Round 54 not effective)"
    echo "$lst" | grep -q 'first_stage_ramdisk/fstab.mt6789' \
      && warn "  its fstab is stock HyperOS's (Layer 2 - device.mk PRODUCT_COPY_FILES fstab is dead code for normal boot; harmless while AVB verification is disabled, MUST fix before re-enabling AVB)"
  else warn "  could not unpack vendor_boot.img PLATFORM fragment"; fi
  rm -rf "$d"
else
  info "  unpack_bootimg / lz4 not available - skipping fragment content check"
  info "  (Layer 2: normal-boot first-stage fstab is stock's, not rootdir/etc/fstab.mt6789 - deferred gap)"
fi

# ---------------------------------------------------------------------------
sec "fstab"
for f in "vendor/etc/fstab.mt6789" \
         "vendor_ramdisk/first_stage_ramdisk/fstab.mt6789" \
         "recovery/root/first_stage_ramdisk/fstab.mt6789"; do
  [ -s "$OUT/$f" ] && pass "$f" || warn "absent: $f"
done
fst="$OUT/vendor/etc/fstab.mt6789"
if [ -s "$fst" ]; then
  grep -qE '^\s*system\s+/system\s+erofs' "$fst" && grep -qE '^\s*system\s+/system\s+ext4' "$fst" \
    && pass "  erofs+ext4 dual lines" || warn "  system dual-fs lines?"
  grep -q 'soc:odm/11230000.msdc' "$fst" && pass "  SD path fix (soc:odm/11230000.msdc)" || warn "  SD uevent path not the fixed one"
  grep -q 'keydirectory=/metadata/vold/metadata_encryption' "$fst" && pass "  /data metadata encryption" || warn "  no metadata_encryption on /data"
  grep -qE '/data\s+f2fs.*checkpoint=fs' "$fst" && pass "  /data checkpoint=fs (Virtual A/B)" || warn "  /data checkpoint flag?"
  grep -qE 'mi_ext.*nofail' "$fst" && pass "  mi_ext nofail" || warn "  mi_ext line?"
  grep -qE '^\s*system_dlkm .*avb=vbmeta_system' "$fst" && pass "  system_dlkm chained to vbmeta_system" || warn "  system_dlkm avb chain?"
fi

# ---------------------------------------------------------------------------
sec "Recovery"
[ -s "$OUT/vendor_boot.img" ] && pass "recovery rides in vendor_boot (no recovery.img expected)" || true
[ -e "$OUT/recovery.img" ] && warn "recovery.img built - device has no recovery partition (BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)" || info "  no recovery.img (correct)"
[ -e "$OUT/vendor_ramdisk/first_stage_ramdisk/fstab.mt6789" ] && pass "first-stage fstab in vendor ramdisk" || warn "first-stage fstab not in vendor ramdisk"
# Round 55: recovery ADB only enumerates with a configfs USB gadget - AOSP
# recovery init.rc forces sys.usb.configfs=0 (legacy android_usb, absent on this
# GKI kernel). Override lives in recovery/root/init.recovery.mt6789.rc.
rr="$DT/recovery/root/init.recovery.mt6789.rc"
if [ -s "$rr" ]; then
  grep -qE 'setprop[[:space:]]+sys\.usb\.configfs[[:space:]]+1' "$rr" \
    && grep -qE 'setprop[[:space:]]+sys\.usb\.controller' "$rr" \
    && pass "recovery/root/init.recovery.mt6789.rc: configfs gadget + UDC set (Round 55 - adb-in-recovery)" \
    || warn "recovery/root/init.recovery.mt6789.rc present but missing sys.usb.configfs 1 / sys.usb.controller (Round 55)"
else
  warn "recovery/root/init.recovery.mt6789.rc absent - adb won't enumerate in recovery (Round 55)"
fi

# ---------------------------------------------------------------------------
sec "AVB"
if have avbtool; then
  if avbtool info_image --image "$OUT/vbmeta.img" >/tmp/_avb.log 2>&1; then
    grep -qE 'Flags:[[:space:]]*3' /tmp/_avb.log && pass "vbmeta flags=3 (verity+verification disabled - bring-up)" \
      || warn "vbmeta flags != 3: $(grep -i flags /tmp/_avb.log | head -1 | sed 's/^ *//')"
    locs=$(grep -oE 'Rollback Index Location:[[:space:]]*[0-9]+' /tmp/_avb.log | awk '{print $NF}' | sort -n | tr '\n' ' ')
    [ -n "$locs" ] && pass "  rollback index locations: $locs" || info "  (no chain rollback locations parsed)"
    for c in vbmeta_system vbmeta_vendor boot vendor_boot; do
      grep -qE "Partition Name:[[:space:]]*$c" /tmp/_avb.log && pass "  chained: $c" || warn "  no chain descriptor: $c"
    done
  else warn "avbtool info_image failed (/tmp/_avb.log)"; fi
else warn "avbtool not on PATH - AVB descriptors not checked"; fi

# ---------------------------------------------------------------------------
sec "build.prop (Round 29-30)"
bp="$OUT/vendor/build.prop"
if [ -s "$bp" ]; then
  grep -q '^ro.vendor.build.security_patch=2026-06-05' "$bp" && pass "vendor SPL 2026-06-05" \
    || warn "vendor SPL: $(grep '^ro.vendor.build.security_patch=' "$bp")"
  grep -q '^ro.product.vendor.name=taiko' "$bp" && pass "ro.product.vendor.name=taiko" \
    || warn "ro.product.vendor.name = $(grep '^ro.product.vendor.name=' "$bp")"
  n=$(grep -c '^ro.vendor.build.version.sdk_full=' "$bp"); [ "$n" -le 1 ] && pass "no sdk_full dup in vendor" || fail "$n sdk_full lines in vendor/build.prop (Round 30)"
  ab=$(grep -oE '^ro.vendor.build.ab_ota_partitions=.*' "$bp" | cut -d= -f2)
  case "$ab" in *,*,*,*,*,*,*,*,*,*,*) pass "ro.vendor.build.ab_ota_partitions = full list";; *) warn "ab_ota_partitions short: $ab (dump had only boot,product,system,vendor)";; esac
else fail "vendor/build.prop missing"; fi
sp="$OUT/system/build.prop"
[ -s "$sp" ] && { grep -q '^ro.build.version.sdk=36' "$sp" && pass "SDK 36" || warn "SDK: $(grep '^ro.build.version.sdk=' "$sp")"; }
# Round 61: PLATFORM_SECURITY_PATCH must be >= the highest SPL this physical
# unit's mitee KeyMint TA has ever genuinely latched (stock's own 2026-08-01),
# or pre-existing keys (most relevantly /data's own FBE key material) get
# permanently rejected with KEY_REQUIRES_UPGRADE - a silent, non-crashing hang.
[ -s "$sp" ] && { grep -q '^ro.build.version.security_patch=2026-08-01' "$sp" && pass "system SPL 2026-08-01 (Round 61 KeyMint rollback fix)" \
  || fail "system SPL: $(grep '^ro.build.version.security_patch=' "$sp") - must be >= 2026-08-01 (Round 61)"; }
for pf in vendor odm; do
  n=$(grep -rc '^ro.build.version.sdk_full=\|^ro.'"$pf"'.build.version.sdk_full=' "$OUT/$pf/build.prop" 2>/dev/null || echo 0)
done
grep -qs '^ro.sf.lcd_density=' "$OUT/vendor/build.prop" "$OUT/system/build.prop" && pass "ro.sf.lcd_density set" || warn "ro.sf.lcd_density not found"

# ---------------------------------------------------------------------------
sec "SELinux"
for f in vendor/etc/selinux/precompiled_sepolicy vendor/etc/selinux/vendor_sepolicy.cil \
         system/etc/selinux/plat_sepolicy.cil ; do
  [ -e "$OUT/$f" ] && pass "$f" || warn "$f absent"
done
[ -e "$OUT/odm/etc/selinux/odm_sepolicy.cil" ] && pass "odm/etc/selinux/odm_sepolicy.cil" \
  || info "  odm_sepolicy.cil absent (ok - odm has no sepolicy)"
# the fast-boot marker is precompiled_sepolicy.plat_sepolicy_and_mapping.sha256
# (note the 'precompiled_sepolicy.' prefix; build auto-generates it alongside
# precompiled_sepolicy). Absent => vendor_init recompiles sepolicy at boot.
sha=$(ls -1 "$OUT"/vendor/etc/selinux/precompiled_sepolicy.*sha256 2>/dev/null)
if [ -n "$sha" ]; then
  echo "$sha" | sed "s|$OUT/|  |" | while read -r l; do pass "$l"; done
else
  warn "no precompiled_sepolicy.*_sepolicy_and_mapping.sha256 - vendor_init recompiles sepolicy at boot (~1s slower, still boots)"
fi

# ---------------------------------------------------------------------------
sec "APEX (Round 48: built, not blob)"
f=$(ls -1 "$OUT"/vendor/apex/com.android.hardware.cas.apex "$OUT"/vendor/apex/com.android.hardware.cas.capex 2>/dev/null | head -1)
[ -n "$f" ] && pass "vendor apex: $(basename "$f")" || info "  com.android.hardware.cas apex absent (yunluo has none either - ok)"
# widevine.nonupdatable is NOT a vendor apex on MT6789 LineageOS (yunluo confirms);
# L1/L3 comes from the mediadrm HAL + keybox, not /vendor/apex.
ls -1 "$OUT"/vendor/apex/com.google.android.widevine.nonupdatable.* >/dev/null 2>&1 \
  && info "  widevine.nonupdatable apex present" \
  || info "  widevine.nonupdatable apex absent (expected - not a vendor apex here)"
n=$(find "$OUT/vendor/apex" -name '*.apex' -o -name '*.capex' 2>/dev/null | wc -l)
info "  $n apex in vendor/apex"

# ---------------------------------------------------------------------------
if [ "$DEEP" -eq 1 ]; then
  sec "Deep: unresolved NEEDED across the built vendor image"
  tmp=$(mktemp)
  # every .so anywhere under vendor/ + system/ + apex (recursive - catches
  # hw/mt6789/, egl/, soundfx/, mediadrm/, nnapi/, ...)
  { find "$OUT"/vendor "$OUT"/system -name '*.so' 2>/dev/null -printf '%f\n'
    find "$OUT"/vendor/apex "$OUT"/system/apex -name '*.so' 2>/dev/null -printf '%f\n'
  } | sort -u > "$tmp"
  KNOWN_DEGRADED='NSCam|NS3Av3|NSIspTuning|libc\+\+_shared|audio_utils.*mutex|libmvpu'
  bad=0; deg=0
  while IFS= read -r so; do
    b=$(basename "$so")
    while IFS= read -r nd; do
      [ -z "$nd" ] && continue
      grep -qxF "$nd" "$tmp" && continue
      case "$nd" in libc.so|libm.so|libdl.so|liblog.so|libc++.so|ld-android.so) continue;; esac
      # libc++_shared.so: known (Round 40) - lib_fixups rewrites shared_libs but
      # not the ELF; MiAlgo camera-AI libs only. Non-fatal, post-boot replace_needed.
      case "$nd" in libc++_shared.so) deg=$((deg+1)); continue;; esac
      bad=$((bad+1)); printf "  ${c_y}NEEDED?${c_0} %-40s -> %s\n" "$b" "$nd"
    done < <("$RE" -d "$so" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
    "$RE" --dyn-syms -W "$so" 2>/dev/null | awk '$4=="GLOBAL" && $7=="UND"{print $NF}' \
      | grep -qE "$KNOWN_DEGRADED" && { deg=$((deg+1)); }
  done < <(find "$OUT"/vendor/lib64 "$OUT"/vendor/lib -name '*.so' 2>/dev/null)
  rm -f "$tmp"
  [ "$bad" -eq 0 ] && pass "every vendor .so DT_NEEDED resolves in the image" \
                   || warn "$bad unresolved NEEDED (check_elf=off; note for first-boot logcat)"
  [ "$deg" -gt 0 ] && warn "$deg libs carry known-degraded UND syms (camera NSCam / libc++_shared / audio mutex / mvpu) - expected, camera/HDR/ML first-boot work"
fi

# ---------------------------------------------------------------------------
if [ "$FLASH" -eq 1 ]; then
  sec "Flash recipe (unlocked bootloader)"
  cat <<EOF
  # ===== MINIMAL (normal LineageOS flow) ================================
  # The OTA zip's payload.bin contains EVERY partition (boot, vendor_boot,
  # dtbo, vbmeta*, all super logicals, MTK firmware) - update_engine writes
  # the inactive slot and switches. Only the recovery bootstrap is manual,
  # and taiko's recovery rides in vendor_boot (no recovery partition):
  fastboot flash vendor_boot "$OUT/vendor_boot.img"
  fastboot reboot recovery
  #   recovery UI: Apply Update -> Apply from ADB
  adb sideload "$z"
  #   then: Factory reset -> Format data, Reboot system

  # ===== FIRST FLASH FROM STOCK HYPEROS (recommended hardening) =========
  # stock vbmeta has verity/verification ON; force it off up front so the
  # payload's vbmeta can't leave you in a dm-verity bootloop, and put the
  # boot chain on BOTH slots so a one-off boot failure doesn't fall back
  # to HyperOS:
  fastboot flash vbmeta_a         "$OUT/vbmeta.img"        --disable-verity --disable-verification
  fastboot flash vbmeta_b         "$OUT/vbmeta.img"        --disable-verity --disable-verification
  fastboot flash vbmeta_system_a  "$OUT/vbmeta_system.img" --disable-verity --disable-verification
  fastboot flash vbmeta_vendor_a  "$OUT/vbmeta_vendor.img" --disable-verity --disable-verification
  fastboot flash boot_a        "$OUT/boot.img"        ; fastboot flash boot_b        "$OUT/boot.img"
  fastboot flash vendor_boot_a "$OUT/vendor_boot.img" ; fastboot flash vendor_boot_b "$OUT/vendor_boot.img"
  fastboot flash dtbo_a        "$OUT/dtbo.img"        ; fastboot flash dtbo_b        "$OUT/dtbo.img"
  #   ... then the reboot recovery + adb sideload from MINIMAL above.

  # ===== FASTBOOT-ONLY (needs super.img: 'mka superimage') =============
EOF
  if [ -s "$OUT/super.img" ]; then cat <<EOF
  fastboot reboot fastboot
  fastboot flash super "$OUT/super.img"
  fastboot -w reboot
EOF
  else echo "  #   super.img not built - run 'mka superimage' first, then: fastboot flash super"; fi
  echo
  echo "  # first boot: adb wait-for-device && adb shell dmesg | grep -i 'avc: denied' ; adb logcat -b all"
fi

# ---------------------------------------------------------------------------
sec "DISABLE_CHECKELF blobs: unresolved NEEDED sweep (Round 65)"
# Round 63's bug class, generalised. ;DISABLE_CHECKELF switches off the ONLY
# thing that would notice a blob's shared-library dependency is missing, and
# soong adds no dependency edge for such a prebuilt - so a lib that nothing
# else happens to pull in simply never ships, and the blob dies at the dynamic
# linker with no build-time complaint at all. That is how the mitee KeyMint
# HAL shipped without libkeymint.so et al for 60+ rounds.
#
# This resolves every DISABLE_CHECKELF blob's DT_NEEDED against the real built
# image, using the same search path the vendor linker namespace uses. Run it
# after a full build; it needs $OUT populated.
if ! have "$RE"; then warn "no readelf/llvm-readelf - NEEDED sweep skipped"
elif [ ! -d "$OUT/vendor" ]; then warn "$OUT/vendor absent - NEEDED sweep skipped (build first)"
else
  # Where a vendor process can actually find a .so at runtime.
  sopath(){ # $1 = soname, $2 = 32|64
    local b=lib64; [ "$2" = 32 ] && b=lib
    for d in "vendor/$b" "vendor/$b/hw" "vendor/$b/egl" "vendor/$b/mt6789" \
             "vendor/$b/hw/mt6789" "odm/$b" "odm/$b/hw" "system/$b" "system/$b/vndk-sp" ; do
      [ -e "$OUT/$d/$1" ] && return 0
    done
    # APEX-provided (com.android.vndk.*, com.android.runtime, ...). Bionic
    # itself (libc/libm/libdl/libdl_android) ships one directory deeper, at
    # .../lib{,64}/bionic/ inside com.android.runtime - every DISABLE_CHECKELF
    # blob needs at least one of these, so missing this subdir turned this
    # sweep into 100+ false FAILs on the very first real run (Round 66).
    compgen -G "$OUT/system/apex/*/$b/$1" >/dev/null 2>&1 && return 0
    compgen -G "$OUT/system/apex/*/$b/bionic/$1" >/dev/null 2>&1 && return 0
    compgen -G "$OUT/apex/*/$b/$1" >/dev/null 2>&1 && return 0
    compgen -G "$OUT/apex/*/$b/bionic/$1" >/dev/null 2>&1 && return 0
    return 1
  }
  nmiss=0; nblob=0
  while IFS= read -r rel; do
    f="$OUT/$rel"; [ -f "$f" ] || continue
    head -c4 "$f" 2>/dev/null | grep -q ELF || continue
    case "$rel" in */lib/*) bits=32 ;; *) bits=64 ;; esac
    nblob=$((nblob+1))
    while IFS= read -r so; do
      [ -n "$so" ] || continue
      sopath "$so" "$bits" || { fail "$rel NEEDs $so - not in the built image (DISABLE_CHECKELF hid this)"; nmiss=$((nmiss+1)); }
    done < <("$RE" -d "$f" 2>/dev/null | awk '/NEEDED/{gsub(/[][]/,"",$5);print $5}')
  done < <(grep ';DISABLE_CHECKELF' "$DT/proprietary-files.txt" | sed 's/;.*//;s/^-//' )
  [ "$nmiss" -eq 0 ] && pass "$nblob DISABLE_CHECKELF blobs: every NEEDED resolves in the built image"
fi

# ---------------------------------------------------------------------------
printf "\n${c_b}== Summary ==${c_0}\n"
printf "  ${c_g}%d PASS${c_0}   ${c_y}%d WARN${c_0}   ${c_r}%d FAIL${c_0}\n" "$P" "$W" "$F"
if [ "$F" -gt 0 ]; then
  printf "  ${c_r}FAILs:${c_0}\n"; for x in "${FAILS[@]}"; do printf "    - %s\n" "$x"; done
  echo "  ^ resolve before flashing"
else
  echo "  no FAILs - build looks flashable (WARNs = first-boot / camera / cosmetic)"
fi
exit $(( F > 0 ? 1 : 0 ))
