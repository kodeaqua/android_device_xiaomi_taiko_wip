#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# verify-build.sh - post-`brunch taiko` sanity check for the Redmi Pad 2 tree.
#
# Run from the LineageOS build root AFTER a build:
#     ./device/xiaomi/taiko/tools/verify-build.sh
#     ./device/xiaomi/taiko/tools/verify-build.sh --deep     # + per-.so dlopen scan (slow)
#     OUT=out/target/product/taiko ./device/xiaomi/taiko/tools/verify-build.sh
#
# It checks: build artifacts, that every blob dropped for a source module is
# actually provided by source, that key MTK/Xiaomi blobs survived, VINTF, kernel
# modules, fstab, AVB, partition sizes vs the scatter, and (--deep) which vendor
# .so files still have unresolved NEEDED libs (= likely first-boot dlopen fails).
# Nothing here needs root.

set -u
OUT="${OUT:-out/target/product/taiko}"
DEEP=0; [ "${1:-}" = "--deep" ] && DEEP=1

# scatter-derived partition sizes (bytes)
SUPER_MAX=11811160064          # 0x2c0000000
BOOT_MAX=67108864              # 0x4000000
VENDORBOOT_MAX=67108864
DTBO_MAX=8388608               # 0x800000

P=0; W=0; F=0
c_g=$'\e[32m'; c_y=$'\e[33m'; c_r=$'\e[31m'; c_b=$'\e[36m'; c_0=$'\e[0m'
pass(){ P=$((P+1)); printf "  ${c_g}PASS${c_0} %s\n" "$*"; }
warn(){ W=$((W+1)); printf "  ${c_y}WARN${c_0} %s\n" "$*"; }
fail(){ F=$((F+1)); printf "  ${c_r}FAIL${c_0} %s\n" "$*"; }
sec(){ printf "\n${c_b}== %s ==${c_0}\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

if [ ! -d "$OUT" ]; then
  echo "OUT dir '$OUT' not found - run from the build root, or set OUT=" >&2
  exit 2
fi
echo "OUT = $OUT"

# ---------------------------------------------------------------------------
sec "Build artifacts"
z=$(ls -1 "$OUT"/lineage-*.zip 2>/dev/null | grep -v -- '-img-' | head -1)
if [ -n "$z" ]; then
  s=$(stat -c%s "$z"); hs=$(( s / 1048576 ))
  [ "$s" -gt 700000000 ] && pass "OTA zip: $(basename "$z") (${hs} MiB)" \
                         || warn "OTA zip small: $(basename "$z") (${hs} MiB)"
else
  warn "no lineage-*.zip (mka bacon not run, or images-only build)"
fi
imgz=$(ls -1 "$OUT"/lineage-*-img-*.zip 2>/dev/null | head -1)
[ -n "$imgz" ] && pass "fastboot img zip: $(basename "$imgz")" \
               || warn "no *-img-*.zip (needed for 'fastboot update')"

for i in boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
  [ -s "$OUT/$i" ] && pass "$i ($(stat -c%s "$OUT/$i") B)" || fail "$i missing"
done
if [ -s "$OUT/super.img" ]; then
  pass "super.img ($(( $(stat -c%s "$OUT/super.img") / 1048576 )) MiB)"
elif [ -s "$OUT/super_empty.img" ]; then
  pass "super_empty.img (retrofit/fastbootd path)"
else
  warn "no super.img / super_empty.img"
fi

# ---------------------------------------------------------------------------
sec "Partition size vs scatter"
chk_sz(){ # file  max  name
  [ -s "$1" ] || { warn "$3: image absent"; return; }
  local s; s=$(stat -c%s "$1")
  if [ "$s" -le "$2" ]; then pass "$3 $s <= $2"
  else fail "$3 $s > $2  (won't flash)"; fi
}
chk_sz "$OUT/boot.img"        "$BOOT_MAX"       "boot.img"
chk_sz "$OUT/vendor_boot.img" "$VENDORBOOT_MAX" "vendor_boot.img"
chk_sz "$OUT/dtbo.img"        "$DTBO_MAX"       "dtbo.img"
if [ -s "$OUT/super.img" ]; then chk_sz "$OUT/super.img" "$SUPER_MAX" "super.img"; fi
# logical partitions must fit the group (super - 4 MiB)
tot=0
for i in system system_ext product vendor vendor_dlkm odm_dlkm system_dlkm; do
  [ -s "$OUT/$i.img" ] && tot=$(( tot + $(stat -c%s "$OUT/$i.img") ))
done
if [ "$tot" -gt 0 ]; then
  if [ "$tot" -le 11806965760 ]; then pass "sum(logical imgs) $tot <= group 11806965760"
  else fail "sum(logical imgs) $tot > group 11806965760"; fi
fi

# ---------------------------------------------------------------------------
sec "Round-48 bet: dropped blobs must be provided by source"
# these were removed from proprietary-files.txt on the assumption a source
# module installs them. If any is missing from the built vendor image, restore
# that blob line.
# lib64 miss = FAIL (restore the blob); lib (32-bit) miss = WARN only, since a
# core_64_bit_only build ships little/no 32-bit vendor.
have32=0; [ "$(find "$OUT/vendor/lib" -maxdepth 2 -name '*.so' 2>/dev/null | head -30 | wc -l)" -ge 25 ] && have32=1
chk_src(){ # path  [soft]
  if [ -e "$OUT/$1" ]; then pass "src provides $1"; return; fi
  if [ "${2:-}" = soft ]; then warn "absent (32-bit, probably fine): $1"; else fail "MISSING $1  -> restore the blob"; fi
}
for m in libaecsw libagc1sw libagc2sw libbassboostsw libbundleaidl libdownmixaidl \
         libdynamicsprocessingaidl libenvreverbsw libequalizersw libextensioneffect \
         libloudnessenhanceraidl libnssw libpreprocessingaidl libpresetreverbsw \
         libreverbaidl libvirtualizersw libvisualizeraidl libvolumesw; do
  chk_src "vendor/lib64/soundfx/$m.so"
  [ "$have32" -eq 1 ] && chk_src "vendor/lib/soundfx/$m.so" soft
done
chk_src "vendor/lib64/mediadrm/libdrmclearkeyplugin.so"
chk_src "vendor/lib64/mediacas/libclearkeycasplugin.so"
chk_src "vendor/lib64/libwpa_client.so"
chk_src "vendor/lib64/libhidparser.so"
chk_src "vendor/bin/hw/android.hardware.contexthub-service.tinysys"   # Round 46
chk_src "vendor/lib64/chre_atoms_log.so"
chk_src "vendor/lib64/hw/sensors.dynamic_sensor_hal.so"               # Round 47
chk_src "vendor/bin/hw/android.hardware.health-service.example"       # Round 21
chk_src "vendor/bin/hw/android.hardware.sensors-service.multihal"     # Round 18
chk_src "vendor/bin/hw/wpa_supplicant"; chk_src "vendor/bin/hw/hostapd"

# ---------------------------------------------------------------------------
sec "Key MTK / Xiaomi blobs still installed"
for f in \
  vendor/bin/hw/camerahalserver \
  vendor/bin/hw/android.hardware.audio.service-aidl.mediatek \
  vendor/bin/hw/android.hardware.security.keymint@4.0-service.mitee \
  vendor/bin/hw/android.hardware.gatekeeper-service.mitee \
  vendor/lib64/hw/mt6789/android.hardware.graphics.allocator-V2-mediatek.so \
  vendor/lib64/hw/hwcomposer.mtk_common.so \
  vendor/lib64/hw/mt6789/mapper.mediatek.so \
  vendor/lib64/hw/android.hardware.audio.core-impl-mediatek.so \
  vendor/lib64/android.hardware.bluetooth.audio-impl-mediatek.so \
  vendor/etc/sensors/hals.conf \
  vendor/etc/fstab.mt6789 ; do
  [ -e "$OUT/$f" ] && pass "$f" || fail "$f MISSING"
done

# ---------------------------------------------------------------------------
sec "VINTF (assembled device manifest)"
vm="$OUT/vendor/etc/vintf/manifest.xml"
if [ -s "$vm" ]; then
  pass "manifest.xml present ($(wc -l <"$vm") lines)"
  for n in android.hardware.audio.core android.hardware.audio.effect \
           android.hardware.camera.provider vendor.mediatek.hardware.mtkpower \
           android.hardware.graphics.allocator android.hardware.graphics.composer3 \
           android.hardware.security.keymint android.hardware.health; do
    grep -q "$n" "$vm" && pass "  HAL declared: $n" || warn "  HAL not in manifest: $n"
  done
  grep -q '<sepolicy>' "$vm" && grep -q '202504' "$vm" \
    && pass "  sepolicy target-version 202504" || warn "  sepolicy version tag not 202504"
else
  fail "manifest.xml missing"
fi
fcm="$OUT/vendor/etc/vintf/compatibility_matrix.device.xml"
[ -s "$fcm" ] && pass "device compat matrix present" || warn "no device compat matrix (checkvintf may still pass)"
if have checkvintf && [ -s "$vm" ]; then
  if checkvintf --check-compat "$OUT" >/tmp/_cv.log 2>&1; then pass "checkvintf --check-compat OK"
  else warn "checkvintf --check-compat complained (see /tmp/_cv.log)"; fi
fi

# ---------------------------------------------------------------------------
sec "Kernel modules"
chk_modlist(){ # dir  label
  local d="$OUT/$1" ml="$OUT/$1/modules.load"
  [ -d "$d" ] || { warn "$2: dir absent"; return; }
  local ko; ko=$(ls -1 "$d"/*.ko 2>/dev/null | wc -l)
  [ -s "$ml" ] || { fail "$2: modules.load missing (dir has $ko .ko)"; return; }
  local n bad=0
  while read -r m; do [ -z "$m" ] && continue
    [ -e "$d/$m" ] || { bad=$((bad+1)); [ "$bad" -le 3 ] && echo "      missing: $m"; }
  done < "$ml"
  n=$(grep -c . "$ml")
  [ "$bad" -eq 0 ] && pass "$2: $n in modules.load, $ko .ko, all resolve" \
                   || fail "$2: $bad modules.load entries have no .ko"
}
chk_modlist vendor_dlkm/lib/modules  "vendor_dlkm"
chk_modlist system_dlkm/lib/modules  "system_dlkm"
for d in "$OUT/vendor_ramdisk/lib/modules" "$OUT"/obj/PACKAGING/depmod_VENDOR_RAMDISK*/modules ; do
  [ -d "$d" ] && { ko=$(ls -1 "$d"/*.ko 2>/dev/null|wc -l); pass "vendor_ramdisk modules dir: $ko .ko ($d)"; break; }
done

# ---------------------------------------------------------------------------
sec "fstab"
for f in "$OUT/vendor/etc/fstab.mt6789" \
         "$OUT/vendor_ramdisk/first_stage_ramdisk/fstab.mt6789" \
         "$OUT/recovery/root/first_stage_ramdisk/fstab.mt6789"; do
  [ -s "$f" ] && pass "$(echo "$f"|sed "s#$OUT/##")" || warn "absent: $(echo "$f"|sed "s#$OUT/##")"
done
fst="$OUT/vendor/etc/fstab.mt6789"
if [ -s "$fst" ]; then
  grep -qE '^\s*system\s+/system\s+erofs' "$fst" && grep -qE '^\s*system\s+/system\s+ext4' "$fst" \
    && pass "  system: erofs+ext4 dual lines" || warn "  system dual-fs lines?"
  grep -q 'soc:odm/11230000.msdc' "$fst" && pass "  SD path fix (soc:odm/11230000.msdc)" \
    || warn "  SD uevent path not the fixed one"
  grep -q 'metadata_encryption' "$fst" && pass "  /data metadata encryption" || warn "  no metadata_encryption on /data"
  grep -qE 'mi_ext.*nofail' "$fst" && pass "  mi_ext nofail" || warn "  mi_ext line?"
fi

# ---------------------------------------------------------------------------
sec "AVB"
if have avbtool; then
  if avbtool info_image --image "$OUT/vbmeta.img" >/tmp/_avb.log 2>&1; then
    grep -q 'Flags:\s*3' /tmp/_avb.log && pass "vbmeta flags = 3 (verity+verification disabled, bring-up)" \
      || warn "vbmeta flags != 3 ($(grep -i flags /tmp/_avb.log | head -1))"
    for c in vbmeta_system vbmeta_vendor boot vendor_boot; do
      grep -q "Partition Name:\s*$c" /tmp/_avb.log && pass "  chained: $c" || warn "  no chain descriptor for $c"
    done
  else warn "avbtool info_image failed (see /tmp/_avb.log)"; fi
else
  warn "avbtool not in PATH - skipping AVB descriptor check"
fi

# ---------------------------------------------------------------------------
sec "Props"
bp="$OUT/vendor/build.prop"
if [ -s "$bp" ]; then
  grep -q '^ro.vendor.build.security_patch=2026-06-05' "$bp" && pass "vendor SPL 2026-06-05" \
    || warn "vendor SPL: $(grep ro.vendor.build.security_patch "$bp")"
  grep -q '^ro.product.vendor.name=taiko' "$bp" && pass "ro.product.vendor.name=taiko" \
    || warn "ro.product.vendor.name = $(grep '^ro.product.vendor.name=' "$bp")"
else
  fail "vendor/build.prop missing"
fi
sp="$OUT/system/build.prop"
[ -s "$sp" ] && { grep -q '^ro.build.version.sdk=36' "$sp" && pass "SDK 36" || warn "SDK: $(grep '^ro.build.version.sdk=' "$sp")"; }

# ---------------------------------------------------------------------------
sec "SELinux"
for f in vendor/etc/selinux/precompiled_sepolicy vendor/etc/selinux/vendor_sepolicy.cil \
         system/etc/selinux/plat_sepolicy.cil ; do
  [ -e "$OUT/$f" ] && pass "$f" || warn "$f absent"
done

# ---------------------------------------------------------------------------
if [ "$DEEP" -eq 1 ]; then
  sec "Deep: unresolved NEEDED in built vendor .so (first-boot dlopen risk)"
  have llvm-readelf && RE=llvm-readelf || RE=readelf
  # build a set of provided sonames from vendor + system + apex
  tmp=$(mktemp)
  { for d in "$OUT"/vendor/lib64 "$OUT"/vendor/lib64/*/ "$OUT"/vendor/lib64/hw \
             "$OUT"/system/lib64 "$OUT"/system/lib64/*/ \
             "$OUT"/vendor/lib "$OUT"/vendor/lib/*/ "$OUT"/system/lib ; do
      [ -d "$d" ] && ls -1 "$d" 2>/dev/null | grep '\.so$'
    done
    # apex-bundled libs
    find "$OUT"/vendor/apex "$OUT"/system/apex -name '*.so' 2>/dev/null | xargs -r -n1 basename
  } | sort -u > "$tmp"
  bad=0
  while IFS= read -r so; do
    b=$(basename "$so")
    while IFS= read -r nd; do
      [ -z "$nd" ] && continue
      grep -qxF "$nd" "$tmp" && continue
      case "$nd" in libc.so|libm.so|libdl.so|liblog.so|libc++.so|ld-android.so|libc++_shared.so) continue;; esac
      bad=$((bad+1)); printf "  ${c_y}dlopen?${c_0} %-42s needs %s\n" "$b" "$nd"
    done < <("$RE" -d "$so" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
  done < <(find "$OUT"/vendor/lib64 "$OUT"/vendor/lib -name '*.so' 2>/dev/null)
  rm -f "$tmp"
  [ "$bad" -eq 0 ] && pass "every vendor .so NEEDED resolves inside the image" \
                   || warn "$bad unresolved NEEDED refs (expected for check_elf=False blobs; note for first-boot logcat)"
fi

# ---------------------------------------------------------------------------
printf "\n${c_b}== Summary ==${c_0}\n"
printf "  ${c_g}%d PASS${c_0}   ${c_y}%d WARN${c_0}   ${c_r}%d FAIL${c_0}\n" "$P" "$W" "$F"
[ "$F" -eq 0 ] && echo "  build looks flashable (WARNs are first-boot / camera / cosmetic)" \
              || echo "  FAILs above must be resolved before flashing"
exit $(( F > 0 ? 1 : 0 ))
