#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import blob_fixups_user_type, blob_fixup
from extract_utils.fixups_lib import (
    lib_fixup_remove_arch_suffix,
    lib_fixup_remove_proto_version_suffix,
    lib_fixup_vendorcompat,
    lib_fixups_user_type,
    libs_clang_rt_ubsan,
    libs_proto_3_9_1,
    libs_proto_21_12,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

# LineageOS 23.2: proprietary-files.txt has already been pruned of every blob
# whose module name collides with a hardware/mediatek source module (see its
# header). Do NOT re-add libmtkperf_client_vendor / libperfctl_vendor /
# libpowerhalwrap_vendor / libaedv / libladder / chipinfo / wlan_assistant /
# vendor.mediatek.hardware.mtkpower@1.x / memtrack-service.mediatek /
# thermal-service.mediatek here or in the pinned list.
namespace_imports = [
    "device/xiaomi/taiko",
    "hardware/mediatek",
    "hardware/mediatek/libmtkperf_client",
    "hardware/xiaomi",
]
# NB: hardware/lineage/compat is NOT a soong namespace on lineage-23.2 (its
# Android.bp has no `soong_namespace {}` - the shim libs live in the default
# namespace). Importing it here fails soong bootstrap with
# "namespace hardware/lineage/compat does not exist". The *_shim libs are still
# usable directly by name in blob_fixups (.add_needed("libbase_shim.so") etc.).

def lib_fixup_libcxx_shared(lib: str, partition: str, *args) -> str:
    # NDK STL -> platform libc++ (ABI-compatible). Xiaomi MiAlgo camera libs
    # record libc++_shared as a NEEDED, which is not a soong module.
    return "libc++"


lib_fixups: lib_fixups_user_type = {
    libs_clang_rt_ubsan: lib_fixup_remove_arch_suffix,
    libs_proto_3_9_1: lib_fixup_vendorcompat,
    libs_proto_21_12: lib_fixup_remove_proto_version_suffix,
    ("libc++_shared",): lib_fixup_libcxx_shared,
}

patchelf_version = "0_17_2"

# NOTE: taiko ships on Android 16 base, so most blobs already link against the
# current -ndk / -V<n> interface libraries and need no ELF surgery. Keep this
# map minimal and let `check_elf=True` on the first extract run tell you exactly
# which NEEDED entries are missing; add targeted .add_needed()/.replace_needed()
# fixups here as they surface. The keystore backend is Microtrust "mitee"
# (android.hardware.security.keymint@4.0-service.mitee /
# android.hardware.gatekeeper-service.mitee) - NOT beanpod.
blob_fixups: blob_fixups_user_type = {
    "vendor/etc/init/android.hardware.media.c2-mediatek.rc": blob_fixup().regex_replace(
        "-mediatek", "-mediatek-64b"
    ),
    "vendor/etc/init/android.hardware.neuralnetworks-shim-service-mtk.rc": blob_fixup().regex_replace(
        "start ", "enable "
    ),
    # A16 host_init_verifier is strict: a service with no `user` line is an
    # error ("No user specified for service ... so it would have been root").
    # The stock touchfeature rc leaves touch-kmsg-init-sh implicit-root while
    # its sibling panel-info-sh (same file, same seclabel) sets `user root`.
    # Make it explicit.
    "vendor/etc/init/vendor.xiaomi.hw.touchfeature-service.rc": blob_fixup().regex_replace(
        "    class main\n    group root system\n    oneshot\n    seclabel u:r:vendor_touch_init_shell:s0",
        "    class main\n    user root\n    group root system\n    oneshot\n    seclabel u:r:vendor_touch_init_shell:s0",
    ),
    # Round 58: pass -b (blocklist-aware) to the modprobe -a vendor_dlkm
    # load. metis.ko crashes (NULL deref, lowlt_list_del_task) once real
    # boot ramps up scheduling activity; prebuilt/vendor_dlkm/
    # modules.blocklist blocks it (+mi_schedule), but that only takes
    # effect if modprobe is actually invoked with -b - plain `modprobe -a`
    # (the stock line) ignores modules.blocklist entirely. rootdir/bin/
    # init.insmod.sh already parses a "-b *" cfg arg into "modprobe -a -b
    # ...". See README Round 58 / modules.blocklist for the full writeup.
    "vendor/etc/init.insmod.mt6789.cfg": blob_fixup().regex_replace(
        r"modprobe\|\*", "modprobe|-b *"
    ),
    # Microtrust mitee: libmt_mitee links keymint-V3-ndk (blob era), but the
    # source keymint utils on lineage-23.2 are V4 -> "multiple versions of the
    # same aidl_interface". keymint V4 is a superset, and libmt_mitee is a
    # client, so bump the NEEDED to V4.
    "vendor/lib64/libmt_mitee.so": blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.security.keymint-V3-ndk.so",
        "android.hardware.security.keymint-V4-ndk.so",
    ),
    # Round 63: the mitee KeyMint service NEEDs libcppbor_external.so, which is
    # HyperOS's own second build variant of external/libcppbor (stock ships
    # both libcppbor.so and libcppbor_external.so in /vendor/lib64 - different
    # files, different SONAMEs, same upstream cppbor:: ABI). lineage-23.2's
    # AOSP keymint service links plain "libcppbor" only, so that is the module
    # this tree can actually install (device.mk, libcppbor.vendor); repoint the
    # NEEDED at it instead of trying to build a module that may not exist here.
    "vendor/bin/hw/android.hardware.security.keymint@4.0-service.mitee": blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed("libcppbor_external.so", "libcppbor.so"),
    # graphics.common AIDL skew: the MTK gralloc / mapper / allocator / HWC /
    # GPU / codec2 blobs were built against android.hardware.graphics.common-V6
    # (HyperOS Android 16), but LineageOS 23.2 trunk froze V7. libgralloctypes /
    # libui / graphics.allocator-V2-ndk (source) pull V7 -> "depends on multiple
    # versions of the same aidl_interface". graphics.common is a types-only
    # package and V7 is a backward-compatible superset, so bump the NEEDED to V7
    # on every consumer blob (same rationale as libmt_mitee keymint V3->V4).
    (
        "vendor/bin/hw/mt6789/android.hardware.graphics.allocator-V2-service-mediatek.mt6789",
        "vendor/lib/hw/mt6789/android.hardware.graphics.allocator-V2-mediatek.so",
        "vendor/lib64/hw/mt6789/android.hardware.graphics.allocator-V2-mediatek.so",
        "vendor/lib/hw/mt6789/mapper.mediatek.so",
        "vendor/lib64/hw/mt6789/mapper.mediatek.so",
        "vendor/lib64/hw/hwcomposer.mtk_common.so",
        "vendor/lib/libgpud.so",
        "vendor/lib64/libgpud.so",
        "vendor/lib/libcodec2_fsr.so",
        "vendor/lib64/libcodec2_fsr.so",
        "vendor/lib64/libaimemc.so",
        "vendor/lib64/libcodec2_vpp_AIMEMC_plugin.so",
        "vendor/lib64/libcodec2_vpp_AISR_plugin.so",
        "vendor/lib/vendor.mediatek.hardware.pq_aidl-V3-ndk.so",
        "vendor/lib64/vendor.mediatek.hardware.pq_aidl-V3-ndk.so",
        "vendor/lib/vendor.mediatek.hardware.pq_aidl-V7-ndk.so",
        "vendor/lib64/vendor.mediatek.hardware.pq_aidl-V7-ndk.so",
        # MTK camera ISP HAL interface lib (re-enabled camera stack)
        "vendor/lib64/vendor.mediatek.hardware.camera.isphal-V1-ndk.so",
    ): blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.graphics.common-V6-ndk.so",
        "android.hardware.graphics.common-V7-ndk.so",
    ),
    # graphics.common V5 (older still): the MTK camera gralloc util lib was
    # built two letters back. Same types-only superset argument -> bump to V7.
    "vendor/lib64/mt6789/libmtkcam_grallocutils.so": blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.graphics.common-V5-ndk.so",
        "android.hardware.graphics.common-V7-ndk.so",
    ),
    # camera.common AIDL skew - the ONLY real blocker for the MTK camera stack:
    # libmtkcam_hal_aidl_common links camera.common-V2 (HyperOS Android 16), but
    # lineage-23.2's hardware/interfaces has camera.common frozen at V1 only (no
    # V2 module is generated). camera.device-V3 imports camera.common-V1, so the
    # lib ends up wanting both -> "multiple versions". The lib has 0 undefined
    # camera::common symbols (readelf), i.e. the V2 NEEDED is a stale link-time
    # artifact, so down-patch it to V1.
    "vendor/lib64/mt6789/libmtkcam_hal_aidl_common.so": blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.camera.common-V2-ndk.so",
        "android.hardware.camera.common-V1-ndk.so",
    ),
    # sensors AIDL skew: the MTK PQ HAL impl links sensors-V2 (HyperOS A16),
    # but the source android.frameworks.sensorservice-V1-ndk on lineage-23.2
    # pulls sensors-V3. Frozen AIDL versions are add-only, so V3 is a superset;
    # bump the NEEDED to V3.
    (
        "vendor/lib/hw/mt6789/vendor.mediatek.hardware.pq_aidl-impl.so",
        "vendor/lib64/hw/mt6789/vendor.mediatek.hardware.pq_aidl-impl.so",
        # MTK camera sensor-provider lib links sensors-V2 + frameworks
        # .sensorservice-V1-ndk (-> sensors-V3); bump the direct NEEDED to V3.
        "vendor/lib64/mt6789/libcam.utils.sensorprovider.so",
    ): blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.sensors-V2-ndk.so",
        "android.hardware.sensors-V3-ndk.so",
    ),
}  # fmt: skip

module = ExtractUtilsModule(
    "taiko",
    "xiaomi",
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    # check_elf stays True at the MODULE level (check_elf=False demotes
    # inter-dependent .so clusters - mvpu, etc. - into PRODUCT_COPY_FILES, which
    # then trips 'found ELF prebuilt in PRODUCT_COPY_FILES', Round 49). Every
    # ELF line in proprietary-files.txt instead carries ;DISABLE_CHECKELF (see
    # its header) - that sets check_elf_files:false on the generated module
    # without demoting it. blob_fixups (AIDL version-skew replace_needed) run at
    # extract time regardless.
    check_elf=True,
    add_firmware_proprietary_file=True,
)

if __name__ == "__main__":
    utils = ExtractUtils.device(module)
    utils.run()
