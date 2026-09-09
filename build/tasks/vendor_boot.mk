# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Use the device's real, factory PLATFORM vendor ramdisk fragment
# (vendor_boot ramdisk_type 0x1) instead of the one this build generates.
#
# Root cause (verified against the sibling TWRP tree,
# kodeaqua/android_device_xiaomi_taiko-twrp, which hit and solved the exact
# same bug on real taiko hardware - see its README "vendor_boot.img: normal
# boot + TWRP splash-hang, both resolved"):
#
# taiko's bootloader/LK, for a NORMAL boot, loads vendor_boot's ramdisk_type
# 0x1 (PLATFORM) fragment BY ITSELF - it does not concatenate it with the
# 0x2 (RECOVERY) fragment (that concatenation only happens when booting into
# recovery). Because this device has no init_boot partition and boot.img
# ships kernel-only (ramdisk_size = 0, see BoardConfig.mk), the PLATFORM
# fragment has to carry a COMPLETE first-stage rootfs on its own - not just
# vendor-specific fstab/ueventd/modules, but the generic AOSP init tree too
# (init, linkerconfig, sepolicy, prop.default, res/, the *_contexts files,
# ...). The stock fragment is ~27.6MB compressed / ~67MB raw and carries 215
# real kernel modules, including the UFS storage driver itself
# (ufs-mediatek-mod.ko, phy-mtk-ufs.ko) - needed before vendor_dlkm can even
# be mounted.
#
# This build's own generated PLATFORM fragment (from TARGET_COPY_OUT_VENDOR_
# RAMDISK + BOARD_VENDOR_RAMDISK_KERNEL_MODULES) is real, valid content on
# its own, but is not equivalent to stock's - confirmed on the TWRP tree
# (same device, same class of AOSP-generated ramdisk, even with the same
# real kernel modules correctly bundled) that booting it as the sole normal-
# boot fragment produces an early kernel panic:
#
#   RAMDISK: lz4 image found at block 0
#   F2FS-fs (ram0): Magic Mismatch...  (ext2/3/4/vfat/exfat/erofs all fail too)
#   Kernel panic - not syncing: VFS: Unable to mount root fs on "/dev/ram" ...
#
# This happens before the kernel framebuffer console is up, so nothing shows
# on screen past the bootloader's own splash - matches a "boot logo, then
# device powers off" first-boot symptom exactly.
#
# How this is wired in: build/make/core/Makefile always generates the
# PLATFORM ramdisk itself (INTERNAL_VENDOR_RAMDISK_TARGET, mkbootfs over
# TARGET_VENDOR_RAMDISK_OUT) and passes it to mkbootimg as --vendor_ramdisk;
# the official BOARD_VENDOR_RAMDISK_FRAGMENT.*.PREBUILT mechanism only
# covers EXTRA fragments, so it can't supply this one. What it can do is
# reassign the variable: this file is pulled in by
# `-include $(sort $(wildcard device/*/*/build/tasks/*.mk))` at the very end
# of core/Makefile, after every image rule is defined, and make expands
# recipe bodies at execution time - so the reassignment here is what the
# mkbootimg command line actually uses. The generated ramdisk is still built
# (it stays a prerequisite, recorded earlier with the old value) but goes
# unused - harmless, not worth suppressing.
#
# The RECOVERY (0x2) fragment is untouched - still built from this tree's
# own LineageOS recovery sources + BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_
# MODULES_LOAD on every compile, unmodified. Recovery mode concatenates both
# fragments, so nothing here changes how recovery boots.
#
# prebuilt/vendor_ramdisk.cpio.lz4 is the stock ramdisk_type 0x1 fragment,
# extracted byte-for-byte from prebuilt/vendor_boot.img (this device's own
# retail image) via:
#   unpack_bootimg.py --boot_img prebuilt/vendor_boot.img --format mkbootimg --out <dir>
#   -> <dir>/vendor_ramdisk00 (type 0x1, 27646885 bytes)
# committed as a prebuilt because no build config in this tree can
# regenerate stock's proprietary bootstrap content.

ifeq ($(TARGET_DEVICE),taiko)

TAIKO_PREBUILT_VENDOR_RAMDISK := device/xiaomi/taiko/prebuilt/vendor_ramdisk.cpio.lz4

# Rebuild vendor_boot.img if the prebuilt changes (the recipe references it,
# but the recorded prerequisite still points at the generated ramdisk).
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(TAIKO_PREBUILT_VENDOR_RAMDISK)

INTERNAL_VENDOR_RAMDISK_TARGET := $(TAIKO_PREBUILT_VENDOR_RAMDISK)

endif
