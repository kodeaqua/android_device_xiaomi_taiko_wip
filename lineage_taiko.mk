#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit from taiko device
$(call inherit-product, device/xiaomi/taiko/device.mk)

# Inherit some common LineageOS stuff
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

PRODUCT_NAME := lineage_taiko
PRODUCT_DEVICE := taiko
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := Redmi Pad 2

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# A16 / Soong build.prop: PRODUCT_BUILD_PROP_OVERRIDES keys must be
# gen_build_prop.py config fields (build/soong/scripts/gen_build_prop.py
# override_config), not the legacy make-var names - PRODUCT_NAME / TARGET_DEVICE
# / PRIVATE_BUILD_DESC now hard-error "isn't a valid prop override".
#   PRODUCT_NAME       -> DeviceProduct  (ro.product.<part>.name)
#   TARGET_DEVICE      -> dropped        (DeviceName is already taiko)
#   PRIVATE_BUILD_DESC -> BuildDesc      (ro.build.description)
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="taiko-user 16 BP2A.250605.031.A3 OS3.0.304.0.WOVMIXM release-keys" \
    DeviceProduct=taiko

# stock fingerprint (used for SafetyNet/Play Integrity basic + OTA metadata).
# BUILD_FINGERPRINT := is still honored (build/make/core/config.mk writes it to
# build_fingerprint-$(TARGET_PRODUCT).txt, which gen_build_prop reads).
BUILD_FINGERPRINT := Redmi/miodm_taiko/taiko:16/BP2A.250605.031.A3/OS3.0.304.0.WOVMIXM:user/release-keys
