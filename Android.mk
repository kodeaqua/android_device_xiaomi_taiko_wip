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
    $(TARGET_OUT_VENDOR)/bin/hw/camerahalserver \
    $(TARGET_OUT_VENDOR)/bin/v3avpud-64b.mt6789 \
    $(TARGET_OUT_VENDOR)/lib/arm.graphics-V5-ndk.so \
    $(TARGET_OUT_VENDOR)/lib/arm.mali.platform-V2-ndk.so \
    $(TARGET_OUT_VENDOR)/lib/gc05a2_truly_front_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib/gc05a2_truly_front_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib/gc08a8_truly_main_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib/gc08a8_truly_main_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib/lib3a.ae.core.so \
    $(TARGET_OUT_VENDOR)/lib/lib3a.ae.so \
    $(TARGET_OUT_VENDOR)/lib/lib3a.aishutter.models.so \
    $(TARGET_OUT_VENDOR)/lib/lib3a.awb.core.so \
    $(TARGET_OUT_VENDOR)/lib/lib3a.log.so \
    $(TARGET_OUT_VENDOR)/lib/libDR.so \
    $(TARGET_OUT_VENDOR)/lib/libaal_cust_func.so \
    $(TARGET_OUT_VENDOR)/lib/libaiselector.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_egl_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_gralloc_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib/libarm_mali_config_sysprops.so \
    $(TARGET_OUT_VENDOR)/lib/libcam.hal3a.log.so \
    $(TARGET_OUT_VENDOR)/lib/libcamalgo.platform2.so \
    $(TARGET_OUT_VENDOR)/lib/libcameracustom.lens.so \
    $(TARGET_OUT_VENDOR)/lib/libcameracustom.so \
    $(TARGET_OUT_VENDOR)/lib/libdpframework.so \
    $(TARGET_OUT_VENDOR)/lib/libgpudataproducer.so \
    $(TARGET_OUT_VENDOR)/lib/libhdrvideo.so \
    $(TARGET_OUT_VENDOR)/lib/libmmagent.so \
    $(TARGET_OUT_VENDOR)/lib/libmml.so \
    $(TARGET_OUT_VENDOR)/lib/libmmlpqImpl.so \
    $(TARGET_OUT_VENDOR)/lib/libmnl.so \
    $(TARGET_OUT_VENDOR)/lib/libmtk_drvb.so \
    $(TARGET_OUT_VENDOR)/lib/libmtk_mali_user.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam.atmseventmgr.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_debugutils.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_metadata.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_modulehelper.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_stdutils.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_sysutils.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_tuning_utils.so \
    $(TARGET_OUT_VENDOR)/lib/libmtkcam_ulog.so \
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
    $(TARGET_OUT_VENDOR)/lib64/gc05a2_truly_front_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib64/gc05a2_truly_front_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/gc08a8_truly_main_mipi_raw_IdxMgr.so \
    $(TARGET_OUT_VENDOR)/lib64/gc08a8_truly_main_mipi_raw_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.ae.core.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.ae.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.ae.stat.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.af.assist.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.af.assist.utils.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.af.core.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.af.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.aishutter.models.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.alsflicker.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.awb.core.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.ccudrv.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.ccuif.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.custom.ae.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.dce.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.flash.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.flicker.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.gma.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.lce.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.log.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.n3d3a.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.sensors.color.so \
    $(TARGET_OUT_VENDOR)/lib64/lib3a.sensors.flicker.so \
    $(TARGET_OUT_VENDOR)/lib64/libDR.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX230PdafLibrary.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX230PdafLibraryWrapper.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX338PdafLibrary.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX338PdafLibraryWrapper.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX386PdafLibrary.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX386PdafLibraryWrapper.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX519PdafLibrary.so \
    $(TARGET_OUT_VENDOR)/lib64/libSonyIMX519PdafLibraryWrapper.so \
    $(TARGET_OUT_VENDOR)/lib64/libaaa_ltm.so \
    $(TARGET_OUT_VENDOR)/lib64/libaaa_ltmx.so \
    $(TARGET_OUT_VENDOR)/lib64/libaal_cust_func.so \
    $(TARGET_OUT_VENDOR)/lib64/libacdk.so \
    $(TARGET_OUT_VENDOR)/lib64/libaiawb_moon.so \
    $(TARGET_OUT_VENDOR)/lib64/libaiawb_p1ggm.so \
    $(TARGET_OUT_VENDOR)/lib64/libaiawb_sun.so \
    $(TARGET_OUT_VENDOR)/lib64/libaibc_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/libaibc_tuning_p2.so \
    $(TARGET_OUT_VENDOR)/lib64/libaibc_tuning_p3.so \
    $(TARGET_OUT_VENDOR)/lib64/libaibc_tuning_p4.so \
    $(TARGET_OUT_VENDOR)/lib64/libaidepth_tuning.so \
    $(TARGET_OUT_VENDOR)/lib64/libaiselector.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_egl_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_gralloc_properties_sysprop.so \
    $(TARGET_OUT_VENDOR)/lib64/libarm_mali_config_sysprops.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.afhal.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.chdr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.feature_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.cctsvr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.log.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.ae.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.ai3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.awb.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.dng.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.fsmgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.lscMgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.lsctbl.50.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.nvram.50.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.platform.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.resultpool.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.hal3a.v3.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.halisp.buf.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.halisp.common.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.halisp.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.halsensor.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.iopipe.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.isptuning.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.pdtblgen.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.tuning.cache.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.utils.sensorprovider.so \
    $(TARGET_OUT_VENDOR)/lib64/libcam.vhdr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.eis.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.fdft.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.fsc.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.gyro.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.ispfeature.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.lmv.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.lsc.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.n3d.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.platform2.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.rotate.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamalgo.vsf.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_isp.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_tuning_mgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamdrv_twin.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamera.custom.pd_buf_mgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamera.customae.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamera.customaf.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamera.customawb.so \
    $(TARGET_OUT_VENDOR)/lib64/libcamera.customflk.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.camera.3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.camera.isp.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.camera.sensors.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.camera_exif.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.eis.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.flashlight.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.lens.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.plugin.so \
    $(TARGET_OUT_VENDOR)/lib64/libcameracustom.so \
    $(TARGET_OUT_VENDOR)/lib64/libdip_drv.so \
    $(TARGET_OUT_VENDOR)/lib64/libdip_postproc.so \
    $(TARGET_OUT_VENDOR)/lib64/libdpframework.so \
    $(TARGET_OUT_VENDOR)/lib64/libeffecthal.base.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature.face.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature.stereo.provider.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature.vsdof.hal.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature_3dnr.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature_eis.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature_fsc.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature_lmv.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeature_rss.so \
    $(TARGET_OUT_VENDOR)/lib64/libfeatureiodrv_mem.so \
    $(TARGET_OUT_VENDOR)/lib64/libgpudataproducer.so \
    $(TARGET_OUT_VENDOR)/lib64/libhdrvideo.so \
    $(TARGET_OUT_VENDOR)/lib64/libimageio.so \
    $(TARGET_OUT_VENDOR)/lib64/libimageio_plat_drv.so \
    $(TARGET_OUT_VENDOR)/lib64/libimageio_plat_pipe.so \
    $(TARGET_OUT_VENDOR)/lib64/liblpcnr.so \
    $(TARGET_OUT_VENDOR)/lib64/libmmagent.so \
    $(TARGET_OUT_VENDOR)/lib64/libmml.so \
    $(TARGET_OUT_VENDOR)/lib64/libmmlpqImpl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmnl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmsnr.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtk_drvb.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtk_mali_user.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.atmseventmgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.debugwrapper.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.eventcallback.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.featurepipe.capture.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.featurepipe.depthmap.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.featurepipe.streaming.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.featurepipe.vsdof_util.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam.logicalmodule.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_3rdparty.core.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_3rdparty.customer.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_3rdparty.mtk.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_3rdparty.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_calibration_convertor.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_calibration_provider.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_debugutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_device3_app.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_device3_hal.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_device3_hidl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_device3_hidlutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_device3_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_devicesessionpolicy.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_diputils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_exif.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_fdvt.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_featurepolicy.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_featureutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_fwkutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_grallocutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hal_aidl_common.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hal_aidl_device.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hal_aidl_provider.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hal_aidl_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hwnode.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_hwutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_imem.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_imgbuf.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_mapping_mgr.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_metadata.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_metastore.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_mfb.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_modulefactory_aaa.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_modulefactory_custom.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_modulefactory_drv.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_modulefactory_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_modulehelper.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_owe.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipeline.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipeline_fbm.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_adapter.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_capture.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_isp.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_session.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinemodel_zsl.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinepolicy-security.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinepolicy-smvr.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinepolicy.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_pipelinepolicy_factory.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_prerelease.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_rsc.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_scenariorecorder.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_stdutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_streamutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_synchelper.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_sysutils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_tuning_utils.so \
    $(TARGET_OUT_VENDOR)/lib64/libmtkcam_ulog.so \
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
    $(TARGET_OUT_VENDOR)/lib64/libstereoinfoaccessor_vsdof.so \
    $(TARGET_OUT_VENDOR)/lib64/libvcodec_utility_v3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libvcodecdrv_v3a.so \
    $(TARGET_OUT_VENDOR)/lib64/libvpudv3a_vcodec.so \
    $(TARGET_OUT_VENDOR)/lib/egl/libGLES_mali.so \
    $(TARGET_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    $(TARGET_OUT_VENDOR)/lib/hw/vulkan.mali.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vulkan.mali.so \
    $(TARGET_OUT_VENDOR)/lib/hw/mapper.mediatek.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/mapper.mediatek.so \
    $(TARGET_OUT_VENDOR)/lib/hw/android.hardware.graphics.allocator-V2-mediatek.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/android.hardware.graphics.allocator-V2-mediatek.so \
    $(TARGET_OUT_VENDOR)/lib/hw/vendor.mediatek.hardware.pq_aidl-impl.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vendor.mediatek.hardware.pq_aidl-impl.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vendor.mediatek.hardware.camera.ccap@1.0-impl.so \
    $(TARGET_OUT_VENDOR)/lib64/hw/vendor.mediatek.hardware.camera.isphal_aidl@1.0-impl.so \
    $(TARGET_OUT_VENDOR)/lib64/mtkcam/libmtkcam_streaminfo_plugin-p1stt.so

# The subdir SoC symlinks above (egl/, hw/, mtkcam/) point one level down into
# <dir>/mt6789/<name> - the generic rule's $(TARGET_BOARD_PLATFORM)/$(notdir $@)
# already resolves to exactly that. egl/libGLES_mali.so + hw/vulkan.mali.so are
# what the EGL/Vulkan loaders actually dlopen (egl.cfg says "0 1 mali"); without
# them the Mali-G57 has no userspace driver. hw/mapper.mediatek.so +
# hw/android.hardware.graphics.allocator-V2-mediatek.so are the gralloc mapper/
# allocator impls SurfaceFlinger needs. These 19 stock symlinks were missing
# from the first list (it only picked up the flat vendor/lib{,64}/*.so links);
# the audio.primary/r_submix legacy-HIDL links are deliberately NOT added -
# taiko is AIDL audio, those blobs aren't shipped.
#
# lib64/hw/sensors.mt6789.so is also deliberately skipped, but note the reason
# stated here originally was wrong: its target (lib64/hw/sensors.mediatek.
# V2.0.so) IS shipped. The real reason it is unnecessary is that nothing loads
# it - sensors.<platform>.so is the legacy libhardware hw_get_module("sensors")
# name, and this tree runs the AOSP AIDL multi-HAL, which loads only what
# configs/.../hals.conf lists (android.hardware.sensors@2.X-subhal-mediatek.so
# + sensors.camera.light.so). Add it only if a sensors HAL ever logs a lookup
# for sensors.mt6789.so.

$(MTK_SOC_SYMLINKS):
	@echo "Symlink: $@ -> $(TARGET_BOARD_PLATFORM)/$(notdir $@)"
	@mkdir -p $(dir $@)
	$(hide) ln -sf $(TARGET_BOARD_PLATFORM)/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(MTK_SOC_SYMLINKS)

# ---------------------------------------------------------------------------
# Round 68: two stock symlinks the generic rule above CANNOT express. Their
# target keeps the .mt6789 suffix while the link name - the path init actually
# execs - does not, so $(TARGET_BOARD_PLATFORM)/$(notdir $@) would emit a
# DANGLING link. Stock ships two aliases for each of these binaries:
#     bin/hw/<name>          -> bin/hw/mt6789/<name>.mt6789   <- init execs this
#     bin/hw/<name>.mt6789   -> bin/hw/mt6789/<name>.mt6789
# Only the second form fits the generic rule, and only the second form was
# listed - so the path init actually uses did not exist in the image at all.
#
# Both are service binaries started by rc files this tree ships:
#   vendor/etc/init/android.hardware.graphics.allocator-V2-service-mediatek.rc
#       service vendor.gralloc-v2 /vendor/bin/hw/android.hardware.graphics.allocator-V2-service-mediatek
#   vendor/etc/init/v3avpud-64b.rc
#       service v3avpud-64b /vendor/bin/v3avpud-64b -f
#
# The allocator one is the serious half: it is the AIDL gralloc IAllocator
# that every graphics buffer allocation goes through (SurfaceFlinger, camera,
# codecs). It is declared in the device VINTF manifest, so clients wait for a
# service that can never register because its binary is not at the path init
# tries to exec. v3avpud-64b is the camera 3A VPU daemon - camera-only.
MTK_SOC_SYMLINKS_SUFFIXED := \
    $(TARGET_OUT_VENDOR)/bin/hw/android.hardware.graphics.allocator-V2-service-mediatek \
    $(TARGET_OUT_VENDOR)/bin/v3avpud-64b

$(MTK_SOC_SYMLINKS_SUFFIXED):
	@echo "Symlink: $@ -> $(TARGET_BOARD_PLATFORM)/$(notdir $@).mt6789"
	@mkdir -p $(dir $@)
	$(hide) ln -sf $(TARGET_BOARD_PLATFORM)/$(notdir $@).mt6789 $@

ALL_DEFAULT_INSTALLED_MODULES += $(MTK_SOC_SYMLINKS_SUFFIXED)

endif
