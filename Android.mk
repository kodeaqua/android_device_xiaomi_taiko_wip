#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),taiko)
include $(call all-makefiles-under,$(LOCAL_PATH))

# ---------------------------------------------------------------------------
# MediaTek ships its SoC-specific vendor libs/binaries under <dir>/mt6789/
# with a bare symlink beside them (/vendor/lib64/foo.so -> mt6789/foo.so).
# proprietary-files.txt carries only the real mt6789/ files (listing the
# symlink too makes extract-utils emit a duplicate soong module); recreate
# the symlinks here, the same way the Redmi Pad 1 (yunluo) tree does.
# ---------------------------------------------------------------------------
MTK_SOC_SYMLINKS := \
    $(TARGET_OUT_VENDOR)/bin/hw/android.hardware.graphics.allocator-V2-service-mediatek.mt6789 \
    $(TARGET_OUT_VENDOR)/bin/v3avpud-64b.mt6789 \
    $(TARGET_OUT_VENDOR)/lib/arm.graphics-V5-ndk.so \
    $(TARGET_OUT_VENDOR)/lib/arm.mali.platform-V2-ndk.so \
    $(TARGET_OUT_VENDOR)/lib/egl/libGLES_mali.so \
    $(TARGET_OUT_VENDOR)/lib/gc05a2_truly_front_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib/gc05a2_truly_front_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib/gc08a8_truly_main_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib/gc08a8_truly_main_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib/hw/android.hardware.graphics.allocator-V2-mediatek.so \
    $(TARGET_OUT_VENDOR)/lib/hw/mapper.mediatek.so \
    $(TARGET_OUT_VENDOR)/lib/hw/vendor.mediatek.hardware.pq_aidl-impl.so \
    $(TARGET_OUT_VENDOR)/lib/hw/vulkan.mali.so \
    $(TARGET_OUT_VENDOR)/lib/libaal_cust_func.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_egl_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_gralloc_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_mali_config_sysprops.so \
    $(TARGET_OUT_VENDOR)/lib/libgpudataproducer.so \
    $(TARGET_OUT_VENDOR)/lib/libhdrvideo.so \
    $(TARGET_OUT_VENDOR)/lib/libmmagent.so \
    $(TARGET_OUT_VENDOR)/lib/libmml.so \
    $(TARGET_OUT_VENDOR)/lib/libmmlpqImpl.so \
    $(TARGET_OUT_VENDOR)/lib/libmnl.so \
    $(TARGET_OUT_VENDOR)/lib/libmtk_mali_user.so \
    $(TARGET_OUT_VENDOR)/lib/libneuron_adapter_mgvi.so \
    $(TARGET_OUT_VENDOR)/lib/libpq_cust_base.so \
    $(TARGET_OUT_VENDOR)/lib/libpq_sec.so \
    $(TARGET_OUT_VENDOR)/lib/libpqconfig.so \
    $(TARGET_OUT_VENDOR)/lib/libpqparamparser.so \
    $(TARGET_OUT_VENDOR)/lib/libscltm.so \
    $(TARGET_OUT_VENDOR)/lib/libvcodec_utility_v3a.so \
    $(TARGET_OUT_VENDOR)/lib/libvcodecdrv_v3a.so \
    $(TARGET_OUT_VENDOR)/lib/libvpudv3a_vcodec.so \
    $(TARGET_OUT_VENDOR)/lib64/arm.graphics-V5-ndk.so \
    $(TARGET_OUT_VENDOR)/lib64/arm.mali.platform-V2-ndk.so \
    $(TARGET_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    $(TARGET_OUT_VENDOR)/lib64/gc05a2_truly_front_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib64/gc05a2_truly_front_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/gc08a8_truly_main_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib64/gc08a8_truly_main_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/android.hardware.graphics.allocator-V2-mediatek.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/mapper.mediatek.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vendor.mediatek.hardware.pq_aidl-impl.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vulkan.mali.so \
    $(TARGET_OUT_VENDOR)/lib64/libaal_cust_func.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_egl_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_gralloc_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_mali_config_sysprops.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_isp.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_tuning_mgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_twin.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeatureiodrv_mem.so \
    $(TARGET_OUT_VENDOR)/lib64/libgpudataproducer.so \
    $(TARGET_OUT_VENDOR)/lib64/libhdrvideo.so \
    $(TARGET_OUT_VENDOR)/lib64/libmmagent.so \
    $(TARGET_OUT_VENDOR)/lib64/libmml.so \
    $(TARGET_OUT_VENDOR)/lib64/libmmlpqImpl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmnl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtk_mali_user.so \
    $(TARGET_OUT_VENDOR)/lib64/libneuron_adapter_mgvi.so \
    $(TARGET_OUT_VENDOR)/lib64/libneuron_runtime.6.so \
    $(TARGET_OUT_VENDOR)/lib64/libneuron_runtime.7.so \
    $(TARGET_OUT_VENDOR)/lib64/libneuron_runtime.8.so \
    $(TARGET_OUT_VENDOR)/lib64/libneuron_runtime.so \
    $(TARGET_OUT_VENDOR)/lib64/libpq_cust_base.so \
    $(TARGET_OUT_VENDOR)/lib64/libpq_sec.so \
    $(TARGET_OUT_VENDOR)/lib64/libpqconfig.so \
    $(TARGET_OUT_VENDOR)/lib64/libpqparamparser.so \
    $(TARGET_OUT_VENDOR)/lib64/libscltm.so \
    $(TARGET_OUT_VENDOR)/lib64/libvcodec_utility_v3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libvcodecdrv_v3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libvpudv3a_vcodec.so

$(MTK_SOC_SYMLINKS):
	@echo "Symlink: $@ -> $(TARGET_BOARD_PLATFORM)/$(notdir $@)"
	@mkdir -p $(dir $@)
	$(hide) ln -sf $(TARGET_BOARD_PLATFORM)/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(MTK_SOC_SYMLINKS)

endif
