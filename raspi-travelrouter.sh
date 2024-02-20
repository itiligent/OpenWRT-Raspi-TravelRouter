#!/bin/bash
#######################################################################################################################
# Build an Openwrt Travelrouter on Raspberry Pi
# David Harrop
# February 2024
#######################################################################################################################

clear

# Prepare text output colours
LYELLOW='\033[0;93m'
LRED='\033[0;91m'
NC='\033[0m' #No Colour

if ! [[ $(id -u) = 0 ]]; then
    echo
    echo -e "${LRED}Please run this script as sudo.${NC}" 1>&2
    echo
    exit 1
fi

echo -e "${LYELLOW}Checking for curl...${NC}"
apt-get update -qq
apt-get install curl -qq -y

clear

#######################################################################################################################
# User input variables
#######################################################################################################################

# Mandatory static user input to determine versions
    VERSION=""               # "" = snapshot or enter specifc version
    TARGET="bcm27xx"         # Set the CPU build target, bcm27xx is the value for Raspi 3 & 4
    ARCH="bcm2711"           # Set to ARCH=bcm2710 for Raspi3 or ARCH=bcm2711 for Rapi4 
    IMAGE_PROFILE="rpi-4"    # Set to rpi-3 or rpi-4 | For available profiles run $SOURCE_DIR/make info
    RELEASE_URL="https://downloads.openwrt.org/releases/" # Where to obtain latest stable version number
    BUILD_LOG="$(pwd)/build.log"
    
# Package Selections. Provide your specific recipe of custom OWRT packages for the custom build here.
    CUSTOM_PACKAGES="-wpad-basic-mbedtls wpad-mbedtls -dnsmasq dnsmasq-full \
    auc curl luci luci-app-attendedsysupgrade luci-app-mwan3 luci-app-sqm luci-app-travelmate mwan3 nano qrencode sqm-scripts sqm-scripts-extra tcpdump travelmate \
    kmod-usb2 kmod-usb3 kmod-usb-core usbutils kmod-gpio-button-hotplug \
    usbmuxd libimobiledevice kmod-usb-net kmod-usb-net-rndis kmod-usb-net-ipheth \
    kmod-rt2800-lib kmod-rt2800-usb kmod-rt2x00-lib kmod-rt2x00-usb" 

    # 1st line above contains necessary substituted dns & wifi crypto base packages
    # 2nd line above contains required system packages 
    # 3rd line above contains required usb support packages
    # 4th line above contains iPhone & Android tether packages. Add any extra usb ethernet adapter chipset packages here 
    # 5th line above contains RTL8812 usb driver test packages. Remove & add your specific usb wifi chipset packages here

#######################################################################################################################
# Script user prompts
#######################################################################################################################

echo -e ${LYELLOW}
echo "Image Builder activity will be logged to ${BUILD_LOG}"
echo

# Prompt for the desired OWRT version
if [[ -z ${VERSION} ]]; then
LATEST_RELEASE=$(curl -s "$RELEASE_URL" | grep -oP "([0-9]+\.[0-9]+\.[0-9]+)" | sort -V | tail -n1)
echo
    echo -e "${LYELLOW}Enter OpenWRT version to build:${NC}"
    while true; do
        read -p "    Enter a version number (latest stable release is $LATEST_RELEASE), or leave blank for latest snapshot: " VERSION
        [[ "${VERSION}" = "" ]] || [[ "${VERSION}" != "" ]] && break
    done
    echo
fi

# Create a custom image name tag
IMAGE_TAG=""
if [[ -z ${IMAGE_TAG} ]]; then
echo
    echo -e "${LYELLOW}Custom image filename identifier:${NC}"
    while true; do
        read -p "    Enter text to include in the image filename [Enter for \"custom\"]: " IMAGE_TAG
        [[ "${IMAGE_TAG}" = "" ]] || [[ "${IMAGE_TAG}" != "" ]] && break
    done
fi
# If no image name tag is given, create a default value
if [[ -z ${IMAGE_TAG} ]]; then
    IMAGE_TAG="custom"
fi

#######################################################################################################################
# Setup the image builder working environment
#######################################################################################################################

# Select the OWRT version to build.
if [[ ${VERSION} != "" ]]; then
    BUILDER="https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/${ARCH}/openwrt-imagebuilder-${VERSION}-${TARGET}-${ARCH}.Linux-x86_64.tar.xz"
else
    BUILDER="https://downloads.openwrt.org/snapshots/targets/${TARGET}/${ARCH}/openwrt-imagebuilder-${TARGET}-${ARCH}.Linux-x86_64.tar.xz" # Current snapshot
fi

# Configure the build paths
    SOURCE_FILE="${BUILDER##*/}" # Separate the tar.xz file name from the source download link
    SOURCE_DIR="${SOURCE_FILE%%.tar.xz}" # Get the uncompressed tar.xz directory name and set as the source dir
    BUILD_ROOT="$(pwd)/openwrt_build_output"
    OUTPUT="${BUILD_ROOT}/firmware_images"
    INJECT_FILES="$(pwd)/openwrt_inject_files"

#######################################################################################################################
# Begin script build actions
#######################################################################################################################
# Clear out any previous builds
    rm -rf "${BUILD_ROOT}"
    rm -rf "${SOURCE_DIR}"

# Create the destination directories
    mkdir -p "${BUILD_ROOT}"
    mkdir -p "${OUTPUT}"
    mkdir -p "${INJECT_FILES}"
    chown -R $SUDO_USER $INJECT_FILES
    chown -R $SUDO_USER $BUILD_ROOT

# Option to pre-configure images with injected config files
    echo -e ${LYELLOW}
    read -p $"Copy optional config files to ${INJECT_FILES} now for inclusion into the new image. Enter to begin build..."
    echo -e ${NC}

# Install OWRT build system dependencies for recent Ubuntu/Debian.
# See here for other distro dependencies: https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem
    sudo apt-get update  2>&1 | tee -a ${BUILD_LOG}
    sudo apt-get install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git libncurses-dev libssl-dev python3-distutils rsync unzip zlib1g-dev file wget qemu-utils 2>&1 | tee -a ${BUILD_LOG}

# Download the image builder source if we haven't already
if [ ! -f "${BUILDER##*/}" ]; then
    wget -q --show-progress "$BUILDER"
    tar xJvf "${BUILDER##*/}" --checkpoint=.100 2>&1 | tee -a ${BUILD_LOG}
fi

# Uncompress if the source tar.xz exists but there is no uncompressed source directory (was cleared for a fresh build).
if [ -n "${SOURCE_DIR}" ]; then
    tar xJvf "${BUILDER##*/}" --checkpoint=.100 2>&1 | tee -a ${BUILD_LOG}
fi

# Remove sudo access limits on source download
    chown -R $SUDO_USER:root $SOURCE_FILE
    chown -R $SUDO_USER:root $SOURCE_DIR
    
# Start a clean image build with the selected packages
    cd $(pwd)/"${SOURCE_DIR}"/
    make clean 2>&1 | tee -a ${BUILD_LOG}
    make image PROFILE="${IMAGE_PROFILE}" PACKAGES="${CUSTOM_PACKAGES}" EXTRA_IMAGE_NAME="${IMAGE_TAG}" FILES="${INJECT_FILES}" BIN_DIR="${OUTPUT}" 2>&1 | tee -a ${BUILD_LOG}