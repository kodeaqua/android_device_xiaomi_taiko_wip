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
    # graphics.common AIDL skew: the MTK gralloc / mapper / allocator / HWC /
    # GPU / codec2 blobs were built against android.hardware.graphics.common-V6
    # (HyperOS Android 16), but LineageOS 23.2 trunk froze V7. libgralloctypes /
    # libui / graphics.allocator-V2-ndk (source) pull V7 -> "depends on multiple
    # versions of the same aidl_interface". graphics.common is a types-only
    # package and V7 is a backward-compatible superset, so bump the NEEDED to V7
    # on every consumer blob (same rationale as libmt_mitee keymint V3->V4).
    (
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
    ): blob_fixup()
    .patchelf_version(patchelf_version)
    .replace_needed(
        "android.hardware.graphics.common-V6-ndk.so",
        "android.hardware.graphics.common-V7-ndk.so",
    ),
}  # fmt: skip

module = ExtractUtilsModule(
    "taiko",
    "xiaomi",
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    check_elf=True,
    add_firmware_proprietary_file=True,
)

if __name__ == "__main__":
    utils = ExtractUtils.device(module)
    utils.run()
