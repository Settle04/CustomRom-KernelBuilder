#!/bin/bash
# Fix compilation issues for crdroidandroid/android_kernel_xiaomi_sm7250 (13.0)
# Target: Redmi K30 5G (picasso) - SM7250/SD765G

set -e

echo "=== Applying SM7250 picasso fixes ==="

# 1. Fix KernelSU symlink
if [ -L "drivers/kernelsu" ]; then
    rm -f drivers/kernelsu
    mkdir -p drivers/kernelsu
    echo "# KernelSU" > drivers/kernelsu/Kconfig
    echo "obj-" > drivers/kernelsu/Makefile
    echo "[1/10] Fixed KernelSU symlink"
else
    echo "[1/10] KernelSU OK"
fi

# 2. Create missing netfilter UAPI headers
mkdir -p include/uapi/linux/netfilter

cat > include/uapi/linux/netfilter/xt_mark.h << 'HEADER'
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_MARK_H
#define _XT_MARK_H
#include <linux/types.h>
struct xt_mark_mtinfo1 { __u32 mark, mask; __u8 invert; };
struct xt_mark_tginfo2 { __u32 mark, mask; };
#endif
HEADER

cat > include/uapi/linux/netfilter/xt_connmark.h << 'HEADER'
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_CONNMARK_H
#define _XT_CONNMARK_H
#include <linux/types.h>
enum { XT_CONNMARK_SET=0, XT_CONNMARK_SAVE=1, XT_CONNMARK_RESTORE=2 };
enum { D_SHIFT_LEFT=0, D_SHIFT_RIGHT=1 };
struct xt_connmark_tginfo1 { __u32 ctmark,ctmask,nfmask; __u8 mode; };
struct xt_connmark_tginfo2 { __u32 ctmark,ctmask,nfmask; __u8 shift_dir,shift_bits,mode; };
struct xt_connmark_mtinfo1 { __u32 mark,mask; __u8 invert; };
#endif
HEADER

cat > include/uapi/linux/netfilter/xt_dscp.h << 'HEADER'
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_DSCP_H
#define _XT_DSCP_H
#include <linux/types.h>
#define XT_DSCP_MASK 0xfc
#define XT_DSCP_SHIFT 2
#define XT_DSCP_MAX 0x3f
struct xt_dscp_info { __u8 dscp; __u8 invert; };
#endif
HEADER
echo "[2/10] Created missing netfilter headers"

# 3. Remove missing netfilter source files from Makefile
sed -i '/xt_dscp/d; /xt_hl/d; /xt_rateest/d; /xt_tcpmss/d' net/netfilter/Makefile
echo "[3/10] Removed missing netfilter modules"

# 4. Fix PLL trace include path
if [ -f "techpack/display/pll/pll_trace.h" ]; then
    sed -i 's|#define TRACE_INCLUDE_PATH .|#define TRACE_INCLUDE_PATH ../../../techpack/display/pll|' techpack/display/pll/pll_trace.h
    mkdir -p include/trace
    cp techpack/display/pll/pll_trace.h include/trace/pll_trace.h
    echo "[4/10] Fixed PLL trace include path"
else
    echo "[4/10] PLL trace OK"
fi

# 5. Fix clk-qcom trace include path
if [ -f "drivers/clk/qcom/trace.h" ]; then
    sed -i 's|#define TRACE_INCLUDE_PATH .|#define TRACE_INCLUDE_PATH ../../../drivers/clk/qcom|' drivers/clk/qcom/trace.h
    cp drivers/clk/qcom/trace.h include/trace/clk_qcom_trace.h
    echo "[5/10] Fixed clk-qcom trace include path"
else
    echo "[5/10] clk-qcom trace OK"
fi

# 6. Fix IPA driver copy_from_user
if [ -f "drivers/platform/msm/ipa/ipa_v3/ipa_hw_stats.c" ]; then
    sed -i 's/missing = copy_from_user(dbg_buff, ubuf, count);/missing = copy_from_user(dbg_buff, ubuf, min(count, sizeof(dbg_buff) - 1));/' drivers/platform/msm/ipa/ipa_v3/ipa_hw_stats.c
    echo "[6/10] Fixed IPA driver"
else
    echo "[6/10] IPA driver OK"
fi

# 7. Fix SELinux .bss.rtic relocation
if [ -f "arch/arm64/kernel/vmlinux.lds.S" ]; then
    sed -i 's/KEEP(*(.bss.rtic))/\/\* .bss.rtic merged into .bss \*\//' arch/arm64/kernel/vmlinux.lds.S
    echo "[7/10] Fixed SELinux .bss.rtic"
else
    echo "[7/10] vmlinux.lds.S OK"
fi

# 8. Fix cam_cci include path
CCI_MAKEFILE="techpack/camera/drivers/cam_sensor_module/cam_cci/Makefile"
if [ -f "$CCI_MAKEFILE" ]; then
    if ! grep -q "cam_sensor_module/cam_cci" "$CCI_MAKEFILE"; then
        sed -i '1a ccflags-y += -I$(srctree)/techpack/camera/drivers/cam_sensor_module/cam_cci' "$CCI_MAKEFILE"
    fi
    echo "[8/10] Fixed cam_cci include path"
else
    echo "[8/10] cam_cci OK"
fi

# 9. Create dummy touchscreen pramboot
PRAMBOOT="drivers/input/touchscreen/focaltech_touch/include/pramboot/FT8719_Pramboot_V0.5_20171221.i"
mkdir -p "$(dirname "$PRAMBOOT")"
touch "$PRAMBOOT"
echo "[9/10] Created dummy pramboot"

# 10. Add STUNE_ASSIST and DYNAMIC_STUNE_BOOST to defconfig
DEFCONFIG="arch/arm64/configs/vendor/lito-perf_defconfig"
if [ -f "$DEFCONFIG" ]; then
    if ! grep -q "CONFIG_STUNE_ASSIST" "$DEFCONFIG"; then
        echo "CONFIG_STUNE_ASSIST=y" >> "$DEFCONFIG"
    fi
    if ! grep -q "CONFIG_DYNAMIC_STUNE_BOOST" "$DEFCONFIG"; then
        echo "CONFIG_DYNAMIC_STUNE_BOOST=y" >> "$DEFCONFIG"
    fi
    echo "[10/10] Added STUNE_ASSIST and DYNAMIC_STUNE_BOOST"
else
    echo "[10/10] defconfig not found, skipping"
fi

echo "=== All SM7250 picasso fixes applied ==="
