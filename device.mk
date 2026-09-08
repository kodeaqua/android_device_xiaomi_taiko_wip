#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# device.mk - Xiaomi Redmi Pad 2 (taiko)
#
# HAL strategy: BLOB-FIRST. Almost every hardware HAL (audio, bluetooth, camera,
# composer@3.x, allocator, gatekeeper.mitee, keymint@4.0.mitee, thermal, usb,
# memtrack, sensors multihal, health, lights, media c2, wifi-service-lazy,
# wpa_supplicant, hostapd, contexthub, dumpstate.xiaomi ...) ships as a
# prebuilt in vendor/ - see proprietary-files.txt. This makefile therefore only
# pulls in the handful of HALs that are NOT in the blob set plus LineageOS
# additions. Do NOT add android.hardware.*-service.mediatek source packages
# here - they collide with the blobs.

LOCAL_PATH := device/xiaomi/taiko

# -----------------------------------------------------------------------------
# Common product bases
# -----------------------------------------------------------------------------
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/userspace_reboot.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Dalvik heap - 4 GB RAM device.
# frameworks/native here is the LineageOS fork (android_frameworks_native,
# lineage-23.2); its build/*-dalvik-heap.mk are Lineage's own values, not AOSP.
# There is no tablet-*-4096 profile (Lineage tablet presets stop at 2048), and
# the "phone"/"tablet" prefix is just a filename - PRODUCT_CHARACTERISTICS is
# what selects tablet behaviour. phone-xhdpi-4096 is the Lineage 4 GB profile:
#   heapstartsize 8m / heapgrowthlimit 192m / heapsize 512m /
#   heaptargetutilization 0.6 / heapminfree 8m / heapmaxfree 16m   (all ?=)
# Intentionally tighter than the HyperOS stock tuning (growthlimit 256m,
# util 0.75) - better headroom on 4 GB. Override individual values in
# configs/props if a workload needs it.
$(call inherit-product, frameworks/native/build/phone-xhdpi-4096-dalvik-heap.mk)

# -----------------------------------------------------------------------------
# Virtual A/B (compressed) - matches stock ro.virtual_ab.*
# -----------------------------------------------------------------------------
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    vendor_boot \
    dtbo \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier \
    otapreopt_script \
    checkpoint_gc

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=$(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE) \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=$(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE) \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_USE_DYNAMIC_PARTITIONS := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

# -----------------------------------------------------------------------------
# Device characteristics
# -----------------------------------------------------------------------------
PRODUCT_CHARACTERISTICS := tablet
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_ENABLE_UFFD_GC := true

# Prebuilt boot.img + TARGET_NO_KERNEL -> no $(PRODUCT_OUT)/kernel, so check_vintf
# has nothing to match the framework compatibility matrix <kernel> requirements
# (version + CONFIG_* fragments) against. The stock GKI kernel already satisfies
# the android16-6.12 KMI; relax the OTA-time kernel-requirements assert instead
# of failing on a check with no input. prebuilt/kernel.lz4 keeps the stock Image
# for a future switch to a repacked boot.img where check_vintf can run for real.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# -----------------------------------------------------------------------------
# fastbootd (AOSP) + preloader helpers
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    fastbootd \
    create_pl_dev \
    create_pl_dev.recovery

# -----------------------------------------------------------------------------
# MediaTek common — build from source (hardware/mediatek, lineage-23.2)
#
# These module NAMES also exist as prebuilts in the stock firmware. Soong
# registers every module in the tree, so keeping both the blob and the source
# module = "multiple modules named ..." hard error. The blobs have been removed
# from proprietary-files.txt (see its header) and are rebuilt here instead.
# Everything else stays blob-first.
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    libmtkperf_client_vendor \
    libperfctl_vendor \
    libpowerhalwrap_vendor \
    libaedv \
    libladder \
    chipinfo \
    wlan_assistant \
    libwifi-hal-wrapper \
    android.hardware.wifi-service \
    vendor.mediatek.hardware.mtkpower@1.2 \
    android.hardware.memtrack-service.mediatek \
    android.hardware.thermal-service.mediatek \
    thermal_symlinks_mediatek

# MediaTek Mssi RRO overlays (wifi/framework capability flags per SoC).
# mssi.mk filters by TARGET_BOARD_PLATFORM; for mt6789 it adds only
# MssiFrameworkOverlay / MssiNetworkStackOverlay / MssiWifiOverlay.
$(call inherit-product, hardware/mediatek/overlay/mssi.mk)

# hardware/mediatek/aidl/gadget builds its own `init.mt6789.usb.rc` prebuilt_etc
# unless told the device ships one - which we do (rootdir/etc/init.mt6789.usb.rc,
# extracted from the stock vendor ramdisk). Without this the two modules collide:
#   module "init.mt6789.usb.rc" ... found in multiple namespaces
$(call soong_config_set,mediatek_gadget,use_custom_usb_gadget_rc,true)

# -----------------------------------------------------------------------------
# Power - use the STOCK MediaTek power stack (blob).
# vendor.mediatek.hardware.mtkpower-service.mediatek registers BOTH
# vendor.mediatek.hardware.mtkpower AND android.hardware.power/IPower/default
# (see the power-mediatek.xml manifest fragment). Adding
# android.hardware.power-service.pixel-libperfmgr would put a SECOND IPower in
# the manifest and a second service racing at runtime, so it is intentionally
# NOT used here. Switching to pixel-libperfmgr is a follow-up that also has to
# strip the mtkpower AIDL service + power-mediatek.xml and prove the perf blobs
# still bind - do it with on-device testing, not blind.
# configs/powerhint.json is kept in-tree for that future switch but not copied.
# libmtkperf_client_vendor / libperfctl_vendor / libpowerhalwrap_vendor are
# still built from source (23.2) - they are the client side and pair with the
# stock libpowerhal.so blob.

# -----------------------------------------------------------------------------
# LineageOS Health (charging control) - separate from the stock health blob
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    vendor.lineage.health-service.default
$(call soong_config_set,lineage_health,charging_control_charging_path,/sys/class/power_supply/battery/input_suspend)
$(call soong_config_set,lineage_health,charging_control_charging_enabled,0)
$(call soong_config_set,lineage_health,charging_control_charging_disabled,1)

# -----------------------------------------------------------------------------
# Power off alarm
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    PowerOffAlarm

# -----------------------------------------------------------------------------
# DRM - keep AOSP clearkey in addition to the stock clearkey/Widevine blobs
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# -----------------------------------------------------------------------------
# Kernel module load lists shipped into the module partitions
# (.ko files come from BOARD_*_KERNEL_MODULES in BoardConfig.mk)
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/vendor_dlkm/modules.load:$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules/modules.load \
    $(LOCAL_PATH)/prebuilt/system_dlkm/modules.load:$(TARGET_COPY_OUT_SYSTEM_DLKM)/lib/modules/modules.load

# -----------------------------------------------------------------------------
# fstab / first-stage
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    fstab.mt6789

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6789:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6789 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6789:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6789

# -----------------------------------------------------------------------------
# Init scripts (extracted from the stock vendor ramdisk / vendor/etc/init/hw)
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    init.insmod.sh \
    init.pstore_blk.sh \
    factory_init.connectivity.common.rc \
    factory_init.connectivity.rc \
    factory_init.dcxo_nvram.rc \
    factory_init.project.rc \
    factory_init.rc \
    init.aee.rc \
    init.cgroup.rc \
    init.connectivity.common.rc \
    init.connectivity.rc \
    init.mt6789.rc \
    init.mt6789.usb.rc \
    init.mtkgki.rc \
    init.project.rc \
    init.sensor_2_0.rc \
    init_connectivity.rc \
    meta_init.connectivity.common.rc \
    meta_init.connectivity.rc \
    meta_init.dcxo_nvram.rc \
    meta_init.project.rc \
    meta_init.rc \
    meta_init.vendor.rc \
    multi_init.rc

# -----------------------------------------------------------------------------
# SoC config files (MT6789-generic; refine from the dump if needed)
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/audio/,$(TARGET_COPY_OUT_VENDOR)/etc) \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/media/,$(TARGET_COPY_OUT_VENDOR)/etc) \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/seccomp/,$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy) \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/wifi/,$(TARGET_COPY_OUT_VENDOR)/etc/wifi) \
    $(LOCAL_PATH)/configs/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf \
    $(LOCAL_PATH)/configs/thermal_info_config.json:$(TARGET_COPY_OUT_VENDOR)/etc/thermal_info_config.json

# -----------------------------------------------------------------------------
# Feature permissions
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

# -----------------------------------------------------------------------------
# RRO overlays
# -----------------------------------------------------------------------------
PRODUCT_ENFORCE_RRO_TARGETS := *
PRODUCT_PACKAGES += \
    FrameworksResOverlayTaiko \
    SettingsResOverlayTaiko \
    WifiResOverlayTaiko \
    LineageSDKOverlayTaiko \
    PowerOffAlarmOverlayTaiko

# -----------------------------------------------------------------------------
# Soong namespaces
# -----------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/mediatek \
    hardware/mediatek/libmtkperf_client \
    hardware/xiaomi

# -----------------------------------------------------------------------------
# Inherit proprietary blobs (vendor/xiaomi/taiko, generated by extract-files.py)
# -----------------------------------------------------------------------------
$(call inherit-product-if-exists, vendor/xiaomi/taiko/taiko-vendor.mk)
