#!/bin/bash
# Setup script for Yocto hardened security project
# This script prepares the build environment and fetches required dependencies

set -e

echo "========================================"
echo "Yocto Hardened Security - Setup Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WORKDIR="${PWD}"
YOCTO_DIR="${WORKDIR}/yocto-build"
POKY_REPO="https://git.yoctoproject.org/git/poky"
META_OE_REPO="https://github.com/openembedded/meta-openembedded.git"

# Yocto branch (adjust as needed for your distribution)
YOCTO_BRANCH="scarthgap"

echo -e "${YELLOW}[*] Configuration${NC}"
echo "Workspace directory: ${WORKDIR}"
echo "Yocto build directory: ${YOCTO_DIR}"
echo "Yocto branch: ${YOCTO_BRANCH}"
echo ""

# Check system requirements
echo -e "${YELLOW}[*] Checking system requirements${NC}"

# Check for required tools
commands=("git" "curl" "gcc" "make" "python3")
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}[!] ERROR: $cmd is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}[✓] All required tools found${NC}"

# Check Python modules
echo -e "${YELLOW}[*] Checking Python dependencies${NC}"
python3 -c "import distutils.version" 2>/dev/null || {
    echo -e "${YELLOW}[!] Installing Python build tools${NC}"
    python3 -m pip install --user setuptools wheel --quiet
}
echo -e "${GREEN}[✓] Python dependencies ready${NC}"

# Check disk space
echo -e "${YELLOW}[*] Checking disk space${NC}"
available=$(df "${WORKDIR}" | awk 'NR==2 {print $4}')
required=$((50 * 1024 * 1024))  # 50GB in KB

if [ "$available" -lt "$required" ]; then
    echo -e "${RED}[!] WARNING: Only ${available}KB available, but ~50GB recommended${NC}"
else
    echo -e "${GREEN}[✓] Sufficient disk space available (${available}KB)${NC}"
fi
echo ""

# Create Yocto build directory
echo -e "${YELLOW}[*] Setting up Yocto directories${NC}"
mkdir -p "${YOCTO_DIR}"
cd "${YOCTO_DIR}"
echo -e "${GREEN}[✓] Created ${YOCTO_DIR}${NC}"

# Check if poky already exists
if [ -d "poky" ]; then
    echo -e "${YELLOW}[!] Poky directory already exists, skipping clone${NC}"
else
    echo -e "${YELLOW}[*] Cloning Yocto Poky repository${NC}"
    echo "    Branch: ${YOCTO_BRANCH}"
    git clone --depth 1 --branch "${YOCTO_BRANCH}" "${POKE_REPO}" poky
    echo -e "${GREEN}[✓] Poky cloned successfully${NC}"
fi

# Check if meta-openembedded exists
if [ -d "meta-openembedded" ]; then
    echo -e "${YELLOW}[!] meta-openembedded already exists, skipping clone${NC}"
else
    echo -e "${YELLOW}[*] Cloning meta-openembedded${NC}"
    git clone --depth 1 --branch "${YOCTO_BRANCH}" "${META_OE_REPO}" meta-openembedded
    echo -e "${GREEN}[✓] meta-openembedded cloned successfully${NC}"
fi
echo ""

# Setup build environment
echo -e "${YELLOW}[*] Initializing Yocto build environment${NC}"
cd "${YOCTO_DIR}/poky"
source oe-init-build-env build
echo -e "${GREEN}[✓] Yocto build environment initialized${NC}"
echo ""

# Configure bblayers.conf
echo -e "${YELLOW}[*] Configuring bblayers.conf${NC}"
BBLAYERS_CONF="${YOCTO_DIR}/poky/build/conf/bblayers.conf"

if grep -q "meta-openembedded" "${BBLAYERS_CONF}"; then
    echo -e "${YELLOW}[!] meta-openembedded already in bblayers.conf${NC}"
else
    echo "  Adding meta-openembedded/meta-oe"
    sed -i "$ s|^|${YOCTO_DIR}/meta-openembedded/meta-oe \\\\\n|" "${BBLAYERS_CONF}"
fi

if grep -q "meta-security" "${BBLAYERS_CONF}"; then
    echo -e "${YELLOW}[!] meta-security already in bblayers.conf${NC}"
else
    echo "  Adding meta-security layer"
    sed -i "$ s|^|${WORKDIR}/meta-security \\\\\n|" "${BBLAYERS_CONF}"
fi
echo -e "${GREEN}[✓] bblayers.conf configured${NC}"
echo ""

# Configure local.conf
echo -e "${YELLOW}[*] Configuring local.conf${NC}"
LOCAL_CONF="${YOCTO_DIR}/poky/build/conf/local.conf"

# Set machine to QEMU
if grep -q "^MACHINE" "${LOCAL_CONF}"; then
    sed -i 's/^MACHINE = .*/MACHINE = "qemux86-64"/' "${LOCAL_CONF}"
else
    echo 'MACHINE = "qemux86-64"' >> "${LOCAL_CONF}"
fi
echo "  Machine set to qemux86-64"

# Enable security features
if ! grep -q "DISTRO_FEATURES" "${LOCAL_CONF}"; then
    echo 'DISTRO_FEATURES:append = " security"' >> "${LOCAL_CONF}"
fi
echo "  Security features enabled"

# Optimize for reasonable build time
if ! grep -q "^BB_NUMBER_THREADS" "${LOCAL_CONF}"; then
    echo 'BB_NUMBER_THREADS = "4"' >> "${LOCAL_CONF}"
    echo 'PARALLEL_MAKE = "-j 4"' >> "${LOCAL_CONF}"
fi
echo "  Build parallelization configured"

echo -e "${GREEN}[✓] local.conf configured${NC}"
echo ""

# Verify configuration
echo -e "${YELLOW}[*] Verifying configuration${NC}"
echo "  Machine: $(grep '^MACHINE' ${LOCAL_CONF} | cut -d'=' -f2)"
echo "  Distro features: $(grep 'DISTRO_FEATURES' ${LOCAL_CONF})"
echo "  Layers configured:"
grep -E '^[^#]*meta-' "${BBLAYERS_CONF}" | sed 's/^/    /'
echo ""

echo -e "${GREEN}[✓] Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review configuration in: ${YOCTO_DIR}/poky/build/conf/"
echo "  2. Build the image: bash scripts/build-image.sh"
echo "  3. Run in QEMU: bash scripts/run-qemu.sh"
echo ""
echo "To manually enter the build environment:"
echo "  cd ${YOCTO_DIR}/poky"
echo "  source oe-init-build-env build"
echo ""
