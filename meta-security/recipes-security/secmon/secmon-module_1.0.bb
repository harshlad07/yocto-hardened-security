SUMMARY = "Security Monitoring Kernel Module"
DESCRIPTION = "A loadable kernel module for real-time monitoring of process activity, privilege escalation, and suspicious system calls."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6415c00fef6a83de8"

SRC_URI = "file://secmon.c \
           file://secmon.h \
           file://Kconfig \
           file://Makefile "

S = "${WORKDIR}"

# Module source files
MODULE_NAME = "secmon"
MODULE_PACKAGE = "kernel-module-${MODULE_NAME}"

# Inherit the kernel module build class
inherit module

# Build directory
B = "${WORKDIR}"

# Module installation
do_compile() {
    cd ${S}
    oe_runmake KDIR=${STAGING_KERNEL_DIR} modules
}

do_install() {
    mkdir -p ${D}/lib/modules/${KERNEL_VERSION}/extra
    cp ${S}/${MODULE_NAME}.ko ${D}/lib/modules/${KERNEL_VERSION}/extra/
}

# Package files
FILES:${PN} = "/lib/modules/${KERNEL_VERSION}/extra/${MODULE_NAME}.ko"

# Auto-load module on boot
rpc_binaries_append = "${PN}"

# Module dependencies
DEPEND = "virtual/kernel"
RDEPEND:${PN} = "kernel (${KERNEL_VERSION})"

# Kernel module feature
MODULE_TARBALL = "1"
