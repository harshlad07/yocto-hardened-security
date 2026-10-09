#!/bin/bash
# Build script for Yocto hardened security distribution
# This script compiles the custom Yocto image with security hardening

set -e

echo "========================================"
echo "Yocto Hardened Security - Build Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKDIR="${PWD}"
YOCTO_DIR="${WORKDIR}/yocto-build"
BUILD_DIR="${YOCTO_DIR}/poky/build"
IMAGE_NAME="hardened-image"

echo -e "${YELLOW}[*] Configuration${NC}"
echo "Workspace: ${WORKDIR}"
echo "Build directory: ${BUILD_DIR}"
echo "Image name: ${IMAGE_NAME}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[*] Checking prerequisites${NC}"

if [ ! -d "${BUILD_DIR}" ]; then
    echo -e "${RED}[!] Build directory not found: ${BUILD_DIR}${NC}"
    echo -e "${RED}[!] Please run setup-yocto.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Build directory found${NC}"

if [ ! -d "${WORKDIR}/meta-security" ]; then
    echo -e "${RED}[!] meta-security layer not found at ${WORKDIR}/meta-security${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] meta-security layer found${NC}"
echo ""

# Enter build environment
echo -e "${YELLOW}[*] Entering Yocto build environment${NC}"
cd "${YOCTO_DIR}/poky"
source oe-init-build-env build >/dev/null 2>&1
echo -e "${GREEN}[✓] Build environment initialized${NC}"
echo ""

# Verify layers
echo -e "${YELLOW}[*] Verifying layers${NC}"
echo "Configured layers:"
bitbake-layers show-layers 2>/dev/null | grep -E '^[^ ]' | sed 's/^/  /'
echo ""

# Create hardened image recipe if it doesn't exist
echo -e "${YELLOW}[*] Checking image recipe${NC}"
IMAGE_RECIPE="${WORKDIR}/meta-security/recipes-core/images/${IMAGE_NAME}.bb"
mkdir -p "$(dirname "${IMAGE_RECIPE}")"

if [ ! -f "${IMAGE_RECIPE}" ]; then
    echo -e "${YELLOW}[!] Creating image recipe: ${IMAGE_NAME}.bb${NC}"
    cat > "${IMAGE_RECIPE}" << 'EOF'
# Hardened Embedded Linux Image
SUMMARY = "Hardened embedded Linux distribution with security monitoring"

REQUIRE_CONF = "1"

inherit core-image

# Base image packages
IMAGE_INSTALL = "\
    packagegroup-core-boot \
    packagegroup-core-full-cmdline \
    auditd \
    audit \
    rsyslog \
    util-linux \
    procps \
    openssl \
    openssh \
    openssh-client \
    openssh-server \
    openssh-keygen \
    curl \
    wget \
    git \
    vim \
    nano \
"

# Security packages
IMAGE_INSTALL += "\
    secmon-module \
"

# Optional security tools
IMAGE_INSTALL:append = " \
    e2fsprogs \
    e2fsprogs-e2fsck \
    kernel-modules \
"

# Image features
IMAGE_FEATURES = "\
    ssh-server-dropbear \
    tools-debug \
    tools-profile \
"

# Kernel modules to include
IMAGE_INSTALL += "kernel-modules"

# Set root password (change for production!)
ROOT_HOME = "/root"
IMAGE_PREPROCESS_COMMAND = "sed -i 's/^root:[^:]*/root:*/' ${IMAGE_ROOTFS}/etc/shadow || true"

# Security hardening configurations
SYSCONF_INSTALL_DIR = "/etc"

# Reduce image size
IMAGE_ROOTFS_SIZE = "262144"

# Security: disable unnecessary services
SYSTEMD_AUTO_ENABLE:pn-systemd-network = "disable"
SYSTEMD_AUTO_ENABLE:pn-avahi-daemon = "disable"

# Enable auditd on boot
SYSTEMD_AUTO_ENABLE:pn-auditd = "enable"

# Read-only filesystem support (optional)
# IMAGE_FEATURES += "read-only-rootfs"
EOF
    echo -e "${GREEN}[✓] Image recipe created${NC}"
else
    echo -e "${GREEN}[✓] Image recipe already exists${NC}"
fi
echo ""

# Start the build
echo -e "${YELLOW}[*] Starting Yocto image build${NC}"
echo -e "${BLUE}This may take 30-60 minutes depending on your system...${NC}"
echo ""

start_time=$(date +%s)

# Run bitbake with progress output
if bitbake "${IMAGE_NAME}"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    echo ""
    echo -e "${GREEN}[✓] Build completed successfully in ${minutes}m ${seconds}s${NC}"
    echo ""
    
    # Display build artifacts
    echo -e "${YELLOW}[*] Build artifacts:${NC}"
    DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images/qemux86-64"
    if [ -d "${DEPLOY_DIR}" ]; then
        echo "  Image files:"
        ls -lh "${DEPLOY_DIR}"/${IMAGE_NAME}* 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}' || true
        echo ""
        echo "  Kernel files:"
        ls -lh "${DEPLOY_DIR}"/bzImage* 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}' || true
        echo ""
        echo "  Root filesystem:"
        ls -lh "${DEPLOY_DIR}"/core-image* 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}' || true
    fi
    echo ""
    echo -e "${YELLOW}[*] Next steps:${NC}"
    echo "  1. Run the image in QEMU: bash scripts/run-qemu.sh"
    echo "  2. Boot and test security features"
    echo "  3. Load and test the secmon kernel module"
    echo ""
else
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    echo ""
    echo -e "${RED}[!] Build failed after ${minutes}m ${seconds}s${NC}"
    echo -e "${RED}[!] Check build logs in: ${BUILD_DIR}/tmp/log/${NC}"
    echo ""
    exit 1
fi
