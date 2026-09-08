# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Stub "kernel source" for the taiko prebuilt-kernel build.
#
# taiko ships a stock GKI boot.img with no kernel source (TARGET_NO_KERNEL).
# LineageOS' vendor/lineage/build/soong `generated_kernel_includes` genrule is
# still dragged into the Soong graph by any module that lists the
# `generated_kernel_headers` header_lib - here libjni_poweroffalarm, from
# hardware/mediatek/packages/PowerOffAlarm (added in device.mk). That genrule
# unconditionally runs
#     make -C $(TARGET_KERNEL_SOURCE) O=<genDir> ARCH=arm64 headers_install
# and TARGET_KERNEL_SOURCE defaults to kernel/$(TARGET_DEVICE_DIR) =
# kernel/xiaomi/taiko, which does not exist:
#     make: *** kernel/xiaomi/taiko: No such file or directory.  Stop.
#
# BoardConfig.mk points TARGET_KERNEL_SOURCE at this directory instead. The one
# consumer (libjni_poweroffalarm) includes only <linux/ioctl.h> / <linux/rtc.h>
# / <sys/timerfd.h>, all of which resolve from the bionic sysroot, so an empty
# usr/include is enough to satisfy the genrule. clean_headers.sh's follow-up
# asm/signal.h scrub only warns (non-fatal) on a bare tree.
#
# VERSION/PATCHLEVEL are read by vendor/lineage/config/BoardConfigKernel.mk
# (grep "^VERSION = " $(TARGET_KERNEL_SOURCE)/Makefile) to derive
# TARGET_KERNEL_VERSION; matching the stock GKI (6.12) keeps TARGET_KERNEL_NO_GCC
# auto-true so no GCC-prebuilt toolchain paths are wired up for a build that
# never compiles a kernel.

VERSION = 6
PATCHLEVEL = 12

.PHONY: headers_install
headers_install:
	mkdir -p "$(O)/usr/include"
