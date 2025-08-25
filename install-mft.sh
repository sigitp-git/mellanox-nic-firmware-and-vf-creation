#!/bin/bash
# Mellanox MFT Installation Script
# This script downloads and installs the latest LTS version of Mellanox Firmware Tools
# 
# Usage: 
#   sudo ./install-mft.sh                    # Auto-detect latest version
#   sudo ./install-mft.sh --no-auto-detect  # Use fallback version
#   sudo ./install-mft.sh --version X.Y.Z-W # Use specific version
#   sudo ./install-mft.sh --help            # Show help

set -e

# Configuration
MFT_VERSION_FALLBACK="4.30.1-1210"  # Fallback version if auto-detection fails
LOG_FILE="/var/log/mft-install.log"
MFT_DOWNLOAD_PAGE="https://network.nvidia.com/products/adapter-software/firmware-tools/"
AUTO_DETECT_VERSION=true  # Default to auto-detection
SPECIFIED_VERSION=""      # User-specified version

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-auto-detect)
                AUTO_DETECT_VERSION=false
                shift
                ;;
            --version)
                SPECIFIED_VERSION="$2"
                AUTO_DETECT_VERSION=false
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log "ERROR: Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    cat << EOF
Mellanox MFT Installation Script

Usage: sudo $0 [OPTIONS]

OPTIONS:
    --no-auto-detect     Use fallback version instead of auto-detecting latest
    --version X.Y.Z-W    Install specific version (e.g., 4.30.1-1210)
    --help, -h           Show this help message

Examples:
    sudo $0                           # Auto-detect and install latest LTS version
    sudo $0 --no-auto-detect         # Install fallback version ($MFT_VERSION_FALLBACK)
    sudo $0 --version 4.29.1-1200    # Install specific version

Environment Variables:
    AUTO_DETECT_VERSION=false        # Disable auto-detection (same as --no-auto-detect)

EOF
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to detect latest MFT LTS version
detect_latest_mft_version() {
    log "Attempting to detect latest MFT LTS version..."
    
    # Install curl if not available
    if ! command -v curl >/dev/null 2>&1; then
        log "Installing curl for version detection..."
        yum install -y curl || apt-get install -y curl
    fi
    
    # Try multiple methods to detect the latest version
    local detected_version=""
    
    # Method 1: Try to parse the download page
    log "Method 1: Parsing NVIDIA download page..."
    local page_content=$(curl -s --connect-timeout 10 "$MFT_DOWNLOAD_PAGE" 2>/dev/null || echo "")
    
    if [ -n "$page_content" ]; then
        # Look for MFT version patterns in the page
        # Pattern: mft-X.Y.Z-WXYZ-x86_64-rpm.tgz
        detected_version=$(echo "$page_content" | grep -oE 'mft-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-x86_64-rpm\.tgz' | \
                          sed 's/mft-\(.*\)-x86_64-rpm\.tgz/\1/' | \
                          sort -V | tail -1)
        
        if [ -n "$detected_version" ]; then
            log "✅ Detected version from download page: $detected_version"
            echo "$detected_version"
            return 0
        fi
    fi
    
    # Method 2: Try direct URL probing for common LTS versions
    log "Method 2: Probing for common LTS versions..."
    local test_versions=(
        "4.30.1-1210"
        "4.29.1-1200" 
        "4.28.1-1190"
        "4.27.1-1180"
        "4.26.1-1170"
    )
    
    for version in "${test_versions[@]}"; do
        local test_url="https://www.mellanox.com/downloads/MFT/mft-${version}-x86_64-rpm.tgz"
        log "Testing version: $version"
        
        if curl --head --silent --fail "$test_url" >/dev/null 2>&1; then
            log "✅ Found available version: $version"
            detected_version="$version"
            break
        fi
    done
    
    if [ -n "$detected_version" ]; then
        echo "$detected_version"
        return 0
    fi
    
    # Method 3: Try GitHub releases API (if NVIDIA publishes there)
    log "Method 3: Checking alternative sources..."
    # This could be expanded to check other sources
    
    log "❌ Could not auto-detect latest MFT version"
    return 1
}

# Function to validate MFT version format
validate_mft_version() {
    local version="$1"
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
        return 0
    else
        log "WARNING: Invalid version format: $version"
        return 1
    fi
}

# Function to get MFT version (auto-detect, specified, or fallback)
get_mft_version() {
    local version=""
    
    # If user specified a version, use that
    if [ -n "$SPECIFIED_VERSION" ]; then
        if validate_mft_version "$SPECIFIED_VERSION"; then
            log "✅ Using user-specified version: $SPECIFIED_VERSION"
            echo "$SPECIFIED_VERSION"
            return 0
        else
            log "ERROR: User-specified version has invalid format: $SPECIFIED_VERSION"
            return 1
        fi
    fi
    
    # Try auto-detection if enabled
    if [ "$AUTO_DETECT_VERSION" = "true" ]; then
        log "Auto-detection enabled, attempting to find latest LTS version..."
        
        if version=$(detect_latest_mft_version); then
            if validate_mft_version "$version"; then
                log "✅ Using auto-detected version: $version"
                echo "$version"
                return 0
            else
                log "⚠️  Auto-detected version has invalid format, using fallback"
            fi
        else
            log "⚠️  Auto-detection failed, using fallback version"
        fi
    else
        log "Auto-detection disabled, using configured version"
    fi
    
    # Use fallback version
    if validate_mft_version "$MFT_VERSION_FALLBACK"; then
        log "Using fallback version: $MFT_VERSION_FALLBACK"
        echo "$MFT_VERSION_FALLBACK"
        return 0
    else
        log "ERROR: Fallback version is invalid: $MFT_VERSION_FALLBACK"
        return 1
    fi
}

# Parse command line arguments first
parse_arguments "$@"

log "Starting Mellanox MFT installation"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

# Get MFT version (auto-detect or fallback)
if ! MFT_VERSION=$(get_mft_version); then
    log "ERROR: Could not determine MFT version to install"
    exit 1
fi

MFT_PACKAGE="mft-${MFT_VERSION}-x86_64-rpm.tgz"
MFT_URL="https://www.mellanox.com/downloads/MFT/${MFT_PACKAGE}"

log "Selected MFT version: $MFT_VERSION"
log "Package: $MFT_PACKAGE"
log "Download URL: $MFT_URL"

# Show version selection summary
echo ""
echo "=== MFT Installation Summary ==="
echo "Version: $MFT_VERSION"
echo "Package: $MFT_PACKAGE"
if [ -n "$SPECIFIED_VERSION" ]; then
    echo "Source: User-specified version"
elif [ "$AUTO_DETECT_VERSION" = "true" ]; then
    echo "Source: Auto-detected (latest available)"
else
    echo "Source: Fallback version"
fi
echo "================================="
echo ""

# Install dependencies
log "Installing dependencies..."
yum install -y gcc rpm-build make elfutils-libelf-devel perl lshw jq wget

# Get kernel version for kernel-devel
KERNEL_VERSION=$(uname -r)
log "Current kernel version: $KERNEL_VERSION"

# Install kernel-devel for current kernel
log "Installing kernel-devel for current kernel..."
yum install -y "kernel-devel-${KERNEL_VERSION}" || {
    log "WARNING: Exact kernel-devel match not found, installing latest available"
    yum install -y kernel-devel
}

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
log "Working in temporary directory: $TEMP_DIR"

# Download MFT package
log "Downloading MFT package from: $MFT_URL"
if wget "$MFT_URL"; then
    log "Download completed successfully"
else
    log "ERROR: Failed to download MFT package"
    log "URL: $MFT_URL"
    log "Version: $MFT_VERSION"
    
    if [ "$AUTO_DETECT_VERSION" = "true" ] && [ -z "$SPECIFIED_VERSION" ]; then
        log ""
        log "Auto-detection may have failed. You can try:"
        log "1. Run with --no-auto-detect to use fallback version"
        log "2. Check available versions at: $MFT_DOWNLOAD_PAGE"
        log "3. Specify a version manually: --version X.Y.Z-W"
    else
        log "Please check if the version $MFT_VERSION is available at:"
        log "$MFT_DOWNLOAD_PAGE"
    fi
    exit 1
fi

# Extract package
log "Extracting MFT package..."
tar xvf "$MFT_PACKAGE"

# Navigate to extracted directory
MFT_DIR="mft-${MFT_VERSION}-x86_64-rpm"
cd "$MFT_DIR"

# Check if install script exists
if [ ! -f "install.sh" ]; then
    log "ERROR: install.sh not found in extracted package"
    exit 1
fi

# Run installation
log "Running MFT installation..."
if ./install.sh; then
    log "MFT installation completed successfully"
else
    log "ERROR: MFT installation failed"
    exit 1
fi

# Start MST service
log "Starting MST service..."
if mst start; then
    log "MST service started successfully"
else
    log "WARNING: Failed to start MST service"
fi

# Verify installation
log "Verifying installation..."
if command -v mlxconfig >/dev/null 2>&1; then
    log "✅ mlxconfig command available"
else
    log "❌ mlxconfig command not found"
fi

if command -v mlxlink >/dev/null 2>&1; then
    log "✅ mlxlink command available"
else
    log "❌ mlxlink command not found"
fi

if command -v flint >/dev/null 2>&1; then
    log "✅ flint command available"
else
    log "❌ flint command not found"
fi

# Check MST status
log "MST Status:"
mst status | tee -a "$LOG_FILE"

# Cleanup
cd /
rm -rf "$TEMP_DIR"
log "Temporary files cleaned up"

# Check for ConnectX-7 devices
log "Checking for ConnectX-7 devices..."
DEVICES=$(lspci | grep -i "MT2910\|ConnectX-7" | wc -l)
if [ "$DEVICES" -gt 0 ]; then
    log "✅ Found $DEVICES ConnectX-7 device(s)"
    lspci | grep -i "MT2910\|ConnectX-7" | tee -a "$LOG_FILE"
else
    log "⚠️  No ConnectX-7 devices detected"
fi

log "MFT installation script completed"
log "Next steps:"
log "1. Run health check: sudo ./mlx-nic-health-check.sh"
log "2. Configure VFs if needed: sudo ./create-virtual-function.sh"
log "3. Check firmware versions and update if necessary"

echo ""
echo "Installation completed! Check $LOG_FILE for detailed logs."