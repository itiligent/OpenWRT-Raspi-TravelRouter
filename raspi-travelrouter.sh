#!/bin/bash
#######################################################################################################################
# Build an Openwrt Travelrouter on Raspberry Pi
# David Harrop
# February 2024
#######################################################################################################################
# ADD YOUR CUSTOM PACKAGE RECIPE BELOW
#######################################################################################################################

    CUSTOM_PACKAGES="-wpad-basic-mbedtls wpad-mbedtls -dnsmasq dnsmasq-full \
    curl luci luci-app-mwan3 luci-app-sqm luci-app-travelmate mwan3 nano qrencode sqm-scripts tcpdump travelmate \
    kmod-usb2 kmod-usb3 kmod-usb-core usbutils kmod-gpio-button-hotplug \
    usbmuxd libimobiledevice kmod-usb-net kmod-usb-net-rndis kmod-usb-net-ipheth \
    kmod-rt2800-lib kmod-rt2800-usb kmod-rt2x00-lib kmod-rt2x00-usb" 

    # 1st line above contains necessary substituted dns & wifi crypto base packages (don't change)
    # 2nd line above contains required system packages (don't change)
    # 3rd line above contains required usb support packages (don't change)
    # 4th line above contains iPhone & Android tether packages (don't change)
    # 5th line above contains example usb device packages for the common RTL8812 chipset.  (Optionally remove this & add your specific usb wifi chipset packages here)

clear

# Prepare text output colours
CYAN='\033[0;36m'
LRED='\033[0;91m'
LYELLOW='\033[0;93m'
NC='\033[0m' # No Colour

# Make sure the user is NOT running this script as root
if [[ $EUID -eq 0 ]]; then
    echo
    echo -e "${LRED}This script must NOT be run as root, it will prompt for sudo when needed." 1>&2
    echo -e ${NC}
    exit 1
fi

# Check if sudo is installed. (Debian does not always include sudo by default.)
if ! command -v sudo &> /dev/null; then
    echo "${LRED}Sudo is not installed. Please install sudo."
    echo -e ${NC}
    exit 1
fi

# Make sure the user running setup is a member of the sudo group
if ! id -nG "$USER" | grep -qw "sudo"; then
    echo
    echo -e "${LRED}The current user (${USER}) must be a member of the 'sudo' group. Run: sudo usermod -aG sudo ${USER}${NC}" 1>&2
    exit 1
fi

# Trigger a prompt for sudo for admin privileges as needed
echo
echo -e "${CYAN}Script requires sudo privileges for some actions${NC}"
echo
sudo sudo -v
echo
echo -e "${CYAN}Checking for curl...${NC}"
sudo apt-get update -qq && sudo apt-get install curl -qq -y
clear

#######################################################################################################################
# User input variables
#######################################################################################################################

# Mandatory static user input to determine versions
    VERSION=""               # Blank "" triggers user prompt for a specifc OWRT version or snapshot.
    TARGET="bcm27xx"         # Set the CPU build target, bcm27xx is the value for Raspi 3 & 4
    ARCH="bcm2711"           # Set to ARCH=bcm2710 for Raspi3 or ARCH=bcm2711 for Rapi4 
    IMAGE_PROFILE="rpi-4"    # Set to rpi-3 or rpi-4 | For available profiles run $SOURCE_DIR/make info
    RELEASE_URL="https://downloads.openwrt.org/releases/" # Where to obtain latest stable version number
    BUILD_LOG="$(pwd)/build.log"
    IMAGE_TAG=""             # ID tag is added to the completed image filename to uniquely identify the built image(s)
  
#######################################################################################################################
# Script prompt variables - do not edit unless expert
#######################################################################################################################

# Prompt for the desired OWRT version
if [[ -z ${VERSION} ]]; then
    LATEST_RELEASE=$(curl -s "$RELEASE_URL" | grep -oP "([0-9]+\.[0-9]+\.[0-9]+)" | sort -V | tail -n1)
    echo
    echo -e "${CYAN}Enter OpenWRT version to build:${NC}"
    while true; do
        read -p "    Enter a release version number (latest stable release = $LATEST_RELEASE), or hit enter for latest snapshot: " VERSION
        [[ "${VERSION}" = "" ]] || [[ "${VERSION}" != "" ]] && break
    done
    echo
fi

# Create a custom image name tag
if [[ -z ${IMAGE_TAG} ]]; then
    echo
    echo -e "${CYAN}Custom image filename identifier:${NC}"
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

# Dynamically create the OpenWRT download link whilst also supporting legacy version imagebuilder download compression formats
if [[ -n ${VERSION} ]]; then
    BASE_URL="https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/${ARCH}"
    BUILDER_PREFIX="openwrt-imagebuilder-${VERSION}-${TARGET}-${ARCH}.Linux-x86_64.tar"
else
    BASE_URL="https://downloads.openwrt.org/snapshots/targets/${TARGET}/${ARCH}"
    BUILDER_PREFIX="openwrt-imagebuilder-${TARGET}-${ARCH}.Linux-x86_64.tar"
fi

BUILDER_XZ="${BASE_URL}/${BUILDER_PREFIX}.xz"
BUILDER_ZST="${BASE_URL}/${BUILDER_PREFIX}.zst"

# Try downloading .zst first, fallback to .xz if .zst is unavailable
if curl --head --silent --fail "${BUILDER_ZST}" >/dev/null; then
    BUILDER="${BUILDER_ZST}"
elif curl --head --silent --fail "${BUILDER_XZ}" >/dev/null; then
    BUILDER="${BUILDER_XZ}"
else
    echo
    echo "    Error: Could not find a valid image builder file for OpenWRT version ${VERSION:-snapshot}."
    echo
    exit 1
fi

echo
echo "    Using image builder: ${BUILDER}"

# Configure the build paths
SOURCE_FILE="${BUILDER##*/}" # Separate the tar.xz file name from the source download link
BUILD_ROOT="$(pwd)/openwrt_build_output"
OUTPUT="${BUILD_ROOT}/firmware_images"
VMDIR="${BUILD_ROOT}/vm"
INJECT_FILES="$(pwd)/openwrt_inject_files"
BUILD_LOG="${BUILD_ROOT}/owrt-build.log" # Creates a build log in the local working directory

# Set SOURCE_DIR based on download file extension (annoyingly snapshots changed to tar.zst. vs releases are tar.xz)
SOURCE_EXT="${SOURCE_FILE##*.}"
if [[ "${SOURCE_EXT}" == "xz" ]]; then
    SOURCE_DIR="${SOURCE_FILE%.tar.xz}"
	EXTRACT="tar -xJvf"
elif [[ "${SOURCE_EXT}" == "zst" ]]; then
    SOURCE_DIR="${SOURCE_FILE%.tar.zst}"
	EXTRACT="tar -I zstd -xf"
else
    echo "Unsupported file extension: ${SOURCE_EXT}"
fi

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
if [[ ${CREATE_VM} = true ]] && [[ ${IMAGE_PROFILE} = "generic" ]]; then mkdir -p "${VMDIR}" ; fi

# Option to pre-configure images with injected config files
echo -e "${LYELLOW}"
echo -e "    [Optional] TO BAKE A CUSTOM CONFIG INTO YOUR OWRT IMAGE"
echo -e "    copy your OWRT backup config files to ${CYAN}${INJECT_FILES}${LYELLOW} before hitting enter..."
echo
read -p "    Press ENTER to begin the OWRT build..."
echo -e "${NC}"

# Install OWRT build system dependencies for recent Ubuntu/Debian.
# See here for other distro dependencies: https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem

# Get the Python 3 version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')

# Split the Python3 version into major, minor, and patch components
IFS='.' read -r -a VERSION_PARTS <<< "$PYTHON_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}

# Compare the distro Python3 version and install the correct build dependencies
if (( MAJOR < 3 )) || (( MAJOR == 3 && MINOR <= 11 )); then
    echo "Python version is less than or equal to 3.11"
    sudo apt-get install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git libncurses5-dev libssl-dev python3-distutils python3-setuptools rsync unzip zlib1g-dev file wget qemu-utils zstd  2>&1 | tee -a ${BUILD_LOG}
else
    echo "Python version is 3.12 or above"
	sudo apt-get install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
    python3-setuptools rsync swig unzip zlib1g-dev file wget 2>&1 | tee -a ${BUILD_LOG}
fi

# Download the image builder source if we haven't already
if [ ! -f "${SOURCE_FILE}" ]; then
    wget -q --show-progress "$BUILDER"
    ${EXTRACT} "${SOURCE_FILE}" | tee -a ${BUILD_LOG}
fi

# Uncompress if the source tarball exists but there is no uncompressed source directory (saves re-download when build directories are cleared for a fresh build).
if [ -f "${SOURCE_FILE}" ]; then
     ${EXTRACT} "${SOURCE_FILE}" | tee -a ${BUILD_LOG}
fi
    
# Start a clean image build with the selected packages
    cd $(pwd)/"${SOURCE_DIR}"/
    make clean 2>&1 | tee -a ${BUILD_LOG}
    make image PROFILE="${IMAGE_PROFILE}" PACKAGES="${CUSTOM_PACKAGES}" EXTRA_IMAGE_NAME="${IMAGE_TAG}" FILES="${INJECT_FILES}" BIN_DIR="${OUTPUT}" 2>&1 | tee -a ${BUILD_LOG}
