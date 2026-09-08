#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/lineage_taiko.mk

# LineageOS 23.2 lunch is 3-part (<product>-<release>-<variant>); `breakfast`
# builds it as  lineage_taiko-$(aosp_target_release)-<variant>  (currently bp4a).
# So invoke as:  breakfast taiko   (NOT  breakfast lineage_taiko-userdebug).
COMMON_LUNCH_CHOICES := \
    lineage_taiko-bp4a-user \
    lineage_taiko-bp4a-userdebug \
    lineage_taiko-bp4a-eng
