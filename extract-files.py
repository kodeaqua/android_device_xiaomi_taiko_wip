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

namespace_imports = [
    "device/xiaomi/taiko",
    "hardware/mediatek",
    "hardware/mediatek/libmtkperf_client",
    "hardware/xiaomi",
]

lib_fixups: lib_fixups_user_type = {
    libs_clang_rt_ubsan: lib_fixup_remove_arch_suffix,
    libs_proto_3_9_1: lib_fixup_vendorcompat,
    libs_proto_21_12: lib_fixup_remove_proto_version_suffix,
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
