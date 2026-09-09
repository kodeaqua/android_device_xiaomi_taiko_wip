#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# BoardConfig.mk - Xiaomi Redmi Pad 2 (taiko)
#
# SoC     : MediaTek MT6789 (marketed "Helio G100" on this SKU)
# Kernel  : GKI, android16-6.12 (stock: 6.12.30-android16-5), NO public source
# Ships   : Android 16 (BP2A.250605.031.A3 / OS3.0.304.0.WOVMIXM)
# Layout  : Virtual A/B (compressed), dynamic partitions, no dedicated recovery
#           partition (recovery lives in the vendor_boot recovery ramdisk).
#
# Boot-image handling (see source.android.com/docs/core/architecture/partitions):
#  * boot.img  - stock GKI, kernel only (header v4, ramdisk_size = 0). Consumed
#                AS-IS via TARGET_NO_KERNEL + BOARD_PREBUILT_BOOTIMAGE; the build
#                only rewrites its AVB footer with the (test) keys.
#  * NO init_boot partition on this device (confirmed against the OTA payload
#    partition list) - the generic ramdisk is assembled into vendor_boot.
#  * vendor_boot.img - REBUILT. Stock is header v4 with TWO ramdisk fragments:
#        [0] type PLATFORM (default)   -> normal vendor ramdisk + kernel modules
#        [1] type RECOVERY  ("recovery") -> recovery resources
#    i.e. this is a standard BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT setup,
#    NOT a separate "dlkm" ramdisk fragment.
#  * The PLATFORM (0x1) fragment is NOT the one this build generates from
#    TARGET_COPY_OUT_VENDOR_RAMDISK - it's the real stock fragment, byte-for-
#    byte, via build/tasks/vendor_boot.mk repointing INTERNAL_VENDOR_RAMDISK_
#    TARGET at prebuilt/vendor_ramdisk.cpio.lz4. This device's bootloader/LK
#    loads the PLATFORM fragment ALONE for a normal boot (no concatenation
#    with RECOVERY), so it must be a complete standalone first-stage rootfs -
#    confirmed on the sibling TWRP tree (same device) that this build's own
#    generated PLATFORM fragment panics early ("Unable to mount root fs on
#    /dev/ram") because it lacks stock's real init/linkerconfig/sepolicy/
#    prop.default/res content, even with the same real kernel modules bundled
#    in. See build/tasks/vendor_boot.mk for the full writeup. The RECOVERY
#    (0x2) fragment is untouched - still built from this tree's own LineageOS
#    recovery sources on every compile.
#
# Corrections vs. taiko_referensi_BoardConfig.mk (claude-web draft):
#   - device IS Virtual A/B (ro.virtual_ab.enabled=true) -> AB_OTA_UPDATER := true
#   - there is NO init_boot partition (draft was right to omit it, kept here)
#   - the 2nd vendor_boot ramdisk is RECOVERY, not "dlkm"
#   - keystore backend is Microtrust "mitee", not beanpod
#
# Values still marked TODO must be filled from the real fastboot/GPT dump before
# a flashable build is cut.

DEVICE_PATH := device/xiaomi/taiko
PREBUILT_PATH := $(DEVICE_PATH)/prebuilt
CONFIGS_PATH := $(DEVICE_PATH)/configs

# -----------------------------------------------------------------------------
# Architecture - MT6789: 2x Cortex-A76 + 6x Cortex-A55
# -----------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a76
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a55
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# Keep everything 64-bit (core_64_bit_only product base)
ZYGOTE_FORCE_64 := true
IGNORE_PREFER32_ON_DEVICE := true

# -----------------------------------------------------------------------------
# Bootloader / platform
# -----------------------------------------------------------------------------
TARGET_BOOTLOADER_BOARD_NAME := taiko
TARGET_NO_BOOTLOADER := true
TARGET_OTA_ASSERT_DEVICE := taiko

BOARD_VENDOR := xiaomi
BOARD_HAS_MTK_HARDWARE := true
TARGET_BOARD_PLATFORM := mt6789
TARGET_BOARD_PLATFORM_GPU := mali-g57

# -----------------------------------------------------------------------------
# boot.img - stock GKI, used AS-IS (no kernel source, nothing to gain by
# repacking). This is the source.android.com "prebuilt boot image" path:
#   TARGET_NO_KERNEL + BOARD_PREBUILT_BOOTIMAGE  ->  the build takes boot.img
#   verbatim, only (re)writing its AVB footer with the (test) release keys so
#   it verifies against the rebuilt vbmeta.
# The stock boot.img is header v4, kernel-only (ramdisk_size = 0); the generic
# ramdisk is assembled into vendor_boot (below), there is NO init_boot.
# -----------------------------------------------------------------------------
BOARD_BOOT_HEADER_VERSION := 4
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true
BOARD_KERNEL_PAGESIZE := 4096

TARGET_NO_KERNEL := true
BOARD_PREBUILT_BOOTIMAGE := $(PREBUILT_PATH)/boot.img
# (PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false is set in device.mk -
#  no $(PRODUCT_OUT)/kernel for check_vintf to match the FCM <kernel> section.)

# dtbo is its own physical partition, supplied as a stock prebuilt (no source
# to regenerate the overlays). BOARD_KERNEL_SEPARATED_DTBO is intentionally NOT
# set - that flag is for the build-dtbo-from-source path.

# -----------------------------------------------------------------------------
# vendor_boot.img - REBUILT from parts so LineageOS recovery + our fstab land
# in it. Stock vendor_boot is header v4 with two ramdisk fragments:
#   [0] PLATFORM (default) -> generic + vendor ramdisk + first-stage modules
#   [1] RECOVERY ("recovery") -> recovery resources
# With BOARD_USES_GENERIC_KERNEL_IMAGE the generic ramdisk is concatenated into
# vendor_boot (boot.img stays kernel-only), and
# BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT emits the separate "recovery"
# fragment (ramdisk_type = RECOVERY) - matching the stock table exactly.
#
# BOARD_INCLUDE_DTB_IN_BOOTIMG must be true: board_config.mk hard-errors on
# "BOARD_PREBUILT_DTBIMAGE_DIR with BOARD_INCLUDE_DTB_IN_BOOTIMG != true". The
# flag name says "BOOTIMG" but with TARGET_NO_KERNEL + prebuilt boot.img the DTB
# is packed into the rebuilt vendor_boot, not boot.img (same as yunluo).
# -----------------------------------------------------------------------------
BOARD_VENDOR_BOOT_HEADER_VERSION := 4
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true

BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2

# TEMPORARY DIAGNOSTIC (Round 56, first-boot bring-up) - DO NOT SHIP.
# System boot hangs at the bootloader splash indefinitely (no bootanimation,
# no adb, and no pstore panic/pmsg capture at all - so the hang is silent,
# not a crash). sepolicy/vendor/ is still the yunluo starting point, never
# verified against a first boot (see CLAUDE.md). Forcing permissive here
# isolates whether a missing sepolicy allow rule on a required service
# (vold/servicemanager/surfaceflinger/...) is what's blocking boot, since an
# enforcing denial on a critical service gives exactly this symptom - no
# log, because the process just gets killed/blocked, not panicked.
# Revert this line the moment the real cause is found; permissive must never
# ship.
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

# Stock vendor_boot bootconfig payload (verbatim from the dumped vendor_boot.img)
BOARD_BOOTCONFIG += kernel.rcu_nocbs=all
BOARD_BOOTCONFIG += kernel.rcutree.enable_rcu_lazy=1
BOARD_BOOTCONFIG += kernel.rcupdate.rcu_cpu_stall_cputime=1

BOARD_KERNEL_BASE := 0x3fff8000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_KERNEL_TAGS_OFFSET := 0x07c88000
BOARD_DTB_OFFSET := 0x07c88000

BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# DTB embedded into vendor_boot (extracted from the stock vendor_boot.img)
BOARD_PREBUILT_DTBIMAGE_DIR := $(PREBUILT_PATH)/dtb

# dtbo - stock image reused as-is (no source to regenerate the overlays from)
BOARD_PREBUILT_DTBOIMAGE := $(PREBUILT_PATH)/dtbo.img

# -----------------------------------------------------------------------------
# Kernel source - there is none (stock GKI prebuilt, TARGET_NO_KERNEL). But
# LineageOS' `generated_kernel_includes` Soong genrule (pulled in by any module
# using the `generated_kernel_headers` header_lib - libjni_poweroffalarm from
# hardware/mediatek/packages/PowerOffAlarm) runs `make -C $(TARGET_KERNEL_SOURCE)
# headers_install`, and TARGET_KERNEL_SOURCE defaults to kernel/$(TARGET_DEVICE_DIR)
# = kernel/xiaomi/taiko (nonexistent -> "No such file or directory. Stop."). Point
# it at an in-tree stub Makefile whose headers_install just makes an empty
# usr/include; the sole consumer only needs bionic-sysroot UAPI headers.
TARGET_KERNEL_SOURCE := $(DEVICE_PATH)/kernel-headers

# -----------------------------------------------------------------------------
# Kernel modules (all prebuilt .ko, KMI-matched to the stock GKI build)
# -----------------------------------------------------------------------------
# vendor_boot (first-stage) ramdisk modules
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(PREBUILT_PATH)/modules.load.vendor_ramdisk))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(addprefix $(PREBUILT_PATH)/modules/,$(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD))

# recovery ramdisk modules (same KMI set on this device)
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(PREBUILT_PATH)/modules.load.recovery))
RECOVERY_KERNEL_MODULES := $(addprefix $(PREBUILT_PATH)/modules/,$(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD))

# de-dupe so the two lists do not create duplicate build rules
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(sort $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES) $(RECOVERY_KERNEL_MODULES))

# vendor_dlkm - SoC/vendor modules
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(PREBUILT_PATH)/vendor_dlkm/modules.load))
BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(PREBUILT_PATH)/vendor_dlkm/*.ko)
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(wildcard $(PREBUILT_PATH)/vendor_dlkm/modules.blocklist)

# system_dlkm - GKI modules (shipped by Google alongside the GKI kernel)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(PREBUILT_PATH)/system_dlkm/modules.load))
BOARD_SYSTEM_KERNEL_MODULES := $(wildcard $(PREBUILT_PATH)/system_dlkm/*.ko)

# -----------------------------------------------------------------------------
# Partitions
# -----------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 262144 # BOARD_KERNEL_PAGESIZE * 64

BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# TODO: confirm against the real GPT / super_map.pb from a fastboot dump.
# From the taiko MT6789_Android_scatter.txt: super partition_size = 0x2c0000000
# = 11811160064 (exactly 11 GiB). Virtual A/B -> one copy of the logical set
# lives in super, so the group gets ~all of it (super - 4 MiB LP metadata),
# never super/2.
BOARD_SUPER_PARTITION_SIZE := 11811160064
BOARD_SUPER_PARTITION_GROUPS := mtk_dynamic_partitions
BOARD_MTK_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm
BOARD_MTK_DYNAMIC_PARTITIONS_SIZE := 11806965760

BOARD_USES_METADATA_PARTITION := true
BOARD_SUPER_PARTITION_METADATA_DEVICE := super

# odm is NOT a separate partition on taiko - stock folds it into /vendor/odm
# (the dump has vendor/odm/{bin,etc}; the payload has odm_dlkm.img but no
# odm.img). 19 blobs and odm.prop target odm/ -> redirect the whole odm
# install tree into vendor. odm_dlkm stays its own logical partition.
TARGET_COPY_OUT_ODM := vendor/odm

# Filesystem types.
# A from-source LineageOS build is generated fresh, so these do not have to match
# the stock erofs images - ext4 for the writ-once system-side partitions and
# erofs (better density) for the mostly-static vendor side, matching yunluo.
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_EROFS_COMPRESSOR := lz4hc,9
BOARD_EROFS_PCLUSTER_SIZE := 262144

BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_USES_ODM_DLKMIMAGE := true
BOARD_USES_SYSTEM_DLKMIMAGE := true

TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

-include vendor/lineage/config/BoardConfigReservedSize.mk

# -----------------------------------------------------------------------------
# Recovery - no dedicated partition, recovery ramdisk rides in vendor_boot
# -----------------------------------------------------------------------------
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6789
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888

# -----------------------------------------------------------------------------
# Display
# -----------------------------------------------------------------------------
TARGET_SCREEN_DENSITY := 360
TARGET_USES_VULKAN := true
PRODUCT_FS_COMPRESSION := 1

# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
TARGET_SYSTEM_PROP += $(CONFIGS_PATH)/props/system.prop
TARGET_SYSTEM_EXT_PROP += $(CONFIGS_PATH)/props/system_ext.prop
TARGET_PRODUCT_PROP += $(CONFIGS_PATH)/props/product.prop
TARGET_VENDOR_PROP += $(CONFIGS_PATH)/props/vendor.prop
TARGET_ODM_PROP += $(CONFIGS_PATH)/props/odm.prop

# -----------------------------------------------------------------------------
# Android Verified Boot
# Built with AOSP test keys; every partition is re-signed from source, so the
# stock rollback indexes/algorithms are irrelevant. Re-sign with real keys only
# once the device is unlocked-and-booting and you move to a signed release.
# -----------------------------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS := --flags 3
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)

BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_VBMETA_VENDOR := vendor vendor_dlkm odm_dlkm
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 2

BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA2048
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 3

BOARD_AVB_VENDOR_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VENDOR_BOOT_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 4

# No BOARD_AVB_RECOVERY_* - there is no recovery partition (recovery is a
# vendor_boot ramdisk fragment, covered by vendor_boot's AVB descriptor).

# -----------------------------------------------------------------------------
# Security patch level (vendor image) - from stock vendor/build.prop
# -----------------------------------------------------------------------------
VENDOR_SECURITY_PATCH := 2026-06-05
BOOT_SECURITY_PATCH := 2026-08-01

# -----------------------------------------------------------------------------
# VINTF
# -----------------------------------------------------------------------------
# manifest.xml = verbatim stock. manifest_audio_aidl.xml carries the
# android.hardware.audio.core AIDL HALs that the stock ships in a separate
# fragment (android.hardware.audio.service-aidl.xml) - that filename collides
# with hardware/interfaces/audio/aidl/default's prebuilt_etc, and the build
# forbids VINTF xml in PRODUCT_COPY_FILES, so merge it in as a second
# DEVICE_MANIFEST_FILE input instead.
DEVICE_MANIFEST_FILE := \
    $(CONFIGS_PATH)/vintf/manifest.xml \
    $(CONFIGS_PATH)/vintf/manifest_audio_aidl.xml
# No DEVICE_MATRIX_FILE: the stock device compatibility_matrix.xml requires the
# MediaTek framework extensions (vendor.mediatek.framework.mtksf_ext,
# vendor.mediatek.hardware.mbrainj) that only exist when the mediatek-common
# framework jar is built - we do not build it. LineageOS' default device
# compatibility matrix is used instead (OTA-time check only).
# Append only our device-specific matrices. vendor/lineage/config/common.mk adds
# its own vendor/lineage/config/device_framework_matrix.xml itself - do NOT
# re-list it here ('does not exist' at soong bootstrap if the path ever moves,
# and ':=' would clobber the Lineage + AOSP defaults).
# configs/vintf/device_framework_matrix.xml covers the proprietary Xiaomi/Dolby
# vendor-extension HALs (and mtkpower/IMtkPowerService @3) that the stock
# manifest + blob vintf fragments advertise but no shared framework matrix
# lists - without it checkvintf --check-compat fails at OTA packaging time.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    $(CONFIGS_PATH)/vintf/device_framework_matrix.xml \
    hardware/mediatek/vintf/mediatek_framework_compatibility_matrix.xml

# -----------------------------------------------------------------------------
# SELinux
# -----------------------------------------------------------------------------
include device/mediatek/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# -----------------------------------------------------------------------------
# Wi-Fi (MediaTek connac / wmt) - Wi-Fi-only SKU
#
# lineage-23.2 note: hardware/mediatek dropped wpa_supplicant_8_lib, so the
# `lib_driver_cmd_mt66xx` private driver_cmd lib no longer exists - we do NOT
# set BOARD_WPA_SUPPLICANT_PRIVATE_LIB. wpa_supplicant / hostapd are built from
# external/wpa_supplicant_8 against the plain nl80211 driver (device.mk adds
# them to PRODUCT_PACKAGES). BOARD_HOSTAPD_DRIVER is what makes the `hostapd`
# soong module exist at all - without it PRODUCT_PACKAGES fails with
# "non-existent modules ... hostapd".
#
# BOARD_WLAN_DEVICE is intentionally NOT set: LineageOS' frameworks wifi HAL
# maps BOARD_WLAN_DEVICE := MediaTek onto a `libwifi-hal-mediatek` module that
# does not exist on 23.2 (hardware/mediatek/wlan provides `libwifi-hal-wrapper`
# instead). Leaving it unset uses the wrapper path, matching the yunluo tree.
# -----------------------------------------------------------------------------
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
WIFI_DRIVER_FW_PATH_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_FW_PATH_STA := "STA"
WIFI_DRIVER_FW_PATH_AP := "AP"
WIFI_DRIVER_FW_PATH_P2P := "P2P"
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_STATE_ON := "1"
WIFI_DRIVER_STATE_OFF := "0"
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true

# -----------------------------------------------------------------------------
# Inherit proprietary board config
# -----------------------------------------------------------------------------
-include vendor/xiaomi/taiko/BoardConfigVendor.mk
