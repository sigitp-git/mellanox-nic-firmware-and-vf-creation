#!/bin/bash
# ConnectX-7 Firmware Download and Installation Script
# Automatically detects PSID and downloads/installs appropriate firmware
#
# Usage:
#   sudo ./install-cx7-firmware.sh                    # Auto-detect latest firmware
#   sudo ./install-cx7-firmware.sh --no-auto-detect  # Use static firmware mappings
#   sudo ./install-cx7-firmware.sh --help            # Show help

set -e

# Configuration
FIRMWARE_BASE_URL="https://www.mellanox.com/downloads/firmware"
FIRMWARE_PAGE_URL="https://network.nvidia.com/support/firmware/connectx7/"
LOG_FILE="/var/log/cx7-firmware-install.log"
AUTO_DETECT_FIRMWARE=${AUTO_DETECT_FIRMWARE:-true}  # Set to false to use static mappings

# Fallback PSID to firmware mappings for ConnectX-7 (used when auto-detection fails)
declare -A FIRMWARE_MAP_FALLBACK=(
    ["MT_0000000834"]="fw-ConnectX7-rel-28_43_3608-MCX755106AS-HEA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin.zip"
    ["MT_0000000833"]="fw-ConnectX7-rel-28_43_3608-MCX755106AS-HEA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin.zip"
    # Add more PSID mappings as needed
)

# Dynamic firmware mappings (populated by auto-detection)
declare -A FIRMWARE_MAP

# Parse command line arguments
FORCE_FIRMWARE=false

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-auto-detect)
                AUTO_DETECT_FIRMWARE=false
                shift
                ;;
            --force)
                FORCE_FIRMWARE=true
                shift
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
ConnectX-7 Firmware Installation Script

Usage: sudo $0 [OPTIONS]

OPTIONS:
    --no-auto-detect     Use static firmware mappings instead of auto-detecting latest
    --force              Force firmware installation, bypass compatibility checks (use with caution)
    --help, -h           Show this help message

Examples:
    sudo $0                    # Auto-detect and install latest LTS firmware
    sudo $0 --no-auto-detect  # Use static firmware mappings
    sudo $0 --force           # Force firmware installation (allows downgrades)

Environment Variables:
    AUTO_DETECT_FIRMWARE=false # Disable auto-detection (same as --no-auto-detect)

⚠️  WARNING: This is a personal reference project. Test thoroughly in lab environment!

EOF
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&2
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to detect latest ConnectX-7 firmware versions
detect_latest_firmware_versions() {
    log "Attempting to detect latest ConnectX-7 firmware versions..."
    
    # Install curl if not available
    if ! command -v curl >/dev/null 2>&1; then
        log "Installing curl for firmware version detection..."
        yum install -y curl || apt-get install -y curl
    fi
    
    # Clear existing firmware map
    unset FIRMWARE_MAP
    declare -g -A FIRMWARE_MAP
    
    local detected_count=0
    
    # Method 1: Parse the ConnectX-7 firmware page for latest LTS version
    log "Method 1: Parsing NVIDIA ConnectX-7 firmware page for latest LTS version..."
    local page_content=$(curl -s --connect-timeout 15 "$FIRMWARE_PAGE_URL" 2>/dev/null || echo "")
    
    if [ -n "$page_content" ]; then
        # Step 1: Find the topmost version with -LTS indication
        log "Looking for latest LTS version..."
        local lts_versions=($(echo "$page_content" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*-LTS' | sort -V -r))
        
        if [ ${#lts_versions[@]} -gt 0 ]; then
            local latest_lts="${lts_versions[0]}"
            log "Found latest LTS version: $latest_lts"
            
            # Step 2: Look for OPN: MCX755106AS-HEA with PSID: MT_0000000834
            # Parse the page structure to find firmware downloads for this specific combination
            
            # Look for firmware download patterns that match our requirements
            # Pattern: fw-ConnectX7-rel-VERSION-MCX755106AS-HEA_Ax-UEFI-X.Y.Z-FlexBoot-A.B.C.signed.bin.zip
            local firmware_pattern="fw-ConnectX7-rel-[0-9_]+-MCX755106AS-HEA_Ax-UEFI-[0-9]+\.[0-9]+\.[0-9]+-FlexBoot-[0-9]+\.[0-9]+\.[0-9]+\.signed\.bin\.zip"
            local firmware_files=($(echo "$page_content" | grep -oE "$firmware_pattern" | sort -V -r))
            
            if [ ${#firmware_files[@]} -gt 0 ]; then
                # Use the first (latest) firmware file found
                local latest_firmware="${firmware_files[0]}"
                log "✅ Found latest LTS firmware for MCX755106AS-HEA: $latest_firmware"
                
                # Map to PSIDs
                FIRMWARE_MAP["MT_0000000834"]="$latest_firmware"
                FIRMWARE_MAP["MT_0000000833"]="$latest_firmware"
                ((detected_count++))
            else
                log "⚠️  No firmware found for MCX755106AS-HEA_Ax pattern"
            fi
        else
            log "⚠️  No LTS versions found on firmware page"
        fi
        
        # Fallback: Look for any ConnectX-7 firmware files if LTS detection failed
        if [ $detected_count -eq 0 ]; then
            log "Fallback: Looking for any ConnectX-7 firmware files..."
            local firmware_files=($(echo "$page_content" | grep -oE 'fw-ConnectX7-rel-[^"]*MCX755106AS-HEA_Ax[^"]*\.signed\.bin\.zip' | sort -V -r))
            
            if [ ${#firmware_files[@]} -gt 0 ]; then
                local latest_firmware="${firmware_files[0]}"
                log "✅ Found firmware (fallback): $latest_firmware"
                FIRMWARE_MAP["MT_0000000834"]="$latest_firmware"
                FIRMWARE_MAP["MT_0000000833"]="$latest_firmware"
                ((detected_count++))
            fi
        fi
    fi
    
    # Method 2: Intelligent probing for latest firmware versions
    if [ $detected_count -eq 0 ]; then
        log "Method 2: Intelligent probing for latest firmware versions..."
        
        # Define version-specific UEFI/FlexBoot mappings
        declare -A version_uefi_map=(
            ["28_43_3608"]="14.37.50"
            ["28_42_1000"]="14.35.20"
            ["28_41_1000"]="14.33.17"
            ["28_40_1000"]="14.32.17"
            ["28_39_3560"]="14.32.17"
        )
        
        declare -A version_flexboot_map=(
            ["28_43_3608"]="3.7.500"
            ["28_42_1000"]="3.7.400"
            ["28_41_1000"]="3.7.300"
            ["28_40_1000"]="3.7.300"
            ["28_39_3560"]="3.7.300"
        )
        
        # Test versions in order of preference (newest first)
        local test_versions=(
            "28_43_3608"
            "28_42_1000"
            "28_41_1000"
            "28_40_1000" 
            "28_39_3560"
        )
        
        local test_models=(
            "MCX755106AS-HEA_Ax"
            "MCX755105AS-HEA_Ax"
        )
        
        for version in "${test_versions[@]}"; do
            for model in "${test_models[@]}"; do
                # Get version-specific UEFI/FlexBoot versions
                local uefi_version="${version_uefi_map[$version]:-14.32.17}"
                local flexboot_version="${version_flexboot_map[$version]:-3.7.300}"
                
                local test_firmware="fw-ConnectX7-rel-${version}-${model}-UEFI-${uefi_version}-FlexBoot-${flexboot_version}.signed.bin.zip"
                local test_url="${FIRMWARE_BASE_URL}/${test_firmware}"
                
                log "Testing: $test_firmware"
                if curl --head --silent --fail "$test_url" >/dev/null 2>&1; then
                    log "✅ Found available firmware: $test_firmware"
                    
                    # Map to PSIDs based on model
                    case "$model" in
                        "MCX755106AS-HEA_Ax")
                            FIRMWARE_MAP["MT_0000000834"]="$test_firmware"
                            FIRMWARE_MAP["MT_0000000833"]="$test_firmware"
                            ;;
                        "MCX755105AS-HEA_Ax")
                            FIRMWARE_MAP["MT_0000000835"]="$test_firmware"
                            ;;
                    esac
                    ((detected_count++))
                    break 2  # Found the latest available version, stop searching
                fi
            done
        done
    fi
    
    log "Auto-detection completed: $detected_count firmware mappings found"
    return $detected_count
}

# Function to load firmware mappings (auto-detect or fallback)
load_firmware_mappings() {
    local mappings_loaded=false
    
    if [ "$AUTO_DETECT_FIRMWARE" = "true" ]; then
        log "Auto-detection enabled, attempting to find latest firmware versions..."
        
        if detect_latest_firmware_versions && [ ${#FIRMWARE_MAP[@]} -gt 0 ]; then
            log "✅ Using auto-detected firmware mappings"
            mappings_loaded=true
            
            # Show detected mappings
            log "Detected firmware mappings:"
            for psid in "${!FIRMWARE_MAP[@]}"; do
                log "  PSID $psid -> ${FIRMWARE_MAP[$psid]}"
            done
        else
            log "⚠️  Auto-detection failed, falling back to static mappings"
        fi
    else
        log "Auto-detection disabled, using static mappings"
    fi
    
    # Use fallback mappings if auto-detection failed or was disabled
    if [ "$mappings_loaded" = "false" ]; then
        log "Loading fallback firmware mappings..."
        for psid in "${!FIRMWARE_MAP_FALLBACK[@]}"; do
            FIRMWARE_MAP["$psid"]="${FIRMWARE_MAP_FALLBACK[$psid]}"
        done
        
        log "Fallback firmware mappings:"
        for psid in "${!FIRMWARE_MAP[@]}"; do
            log "  PSID $psid -> ${FIRMWARE_MAP[$psid]}"
        done
    fi
    
    if [ ${#FIRMWARE_MAP[@]} -eq 0 ]; then
        error_exit "No firmware mappings available"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Check if MFT tools are installed
check_mft_tools() {
    log "Checking MFT tools installation..."
    
    if ! command -v flint >/dev/null 2>&1; then
        error_exit "flint command not found. Please install MFT tools first using install-mft.sh"
    fi
    
    if ! command -v mst >/dev/null 2>&1; then
        error_exit "mst command not found. Please install MFT tools first using install-mft.sh"
    fi
    
    log "✅ MFT tools are installed"
}

# Start MST service if not running
start_mst_service() {
    log "Starting MST service..."
    mst start || log "WARNING: MST service may already be running"
}

# Detect ConnectX-7 devices and their PSIDs
detect_devices_and_psids() {
    log "Detecting ConnectX-7 devices and PSIDs..."
    
    # Get all ConnectX-7 PCI devices
    DEVICES=($(lspci | grep -i "MT2910\|ConnectX-7" | awk '{print $1}'))
    
    if [ ${#DEVICES[@]} -eq 0 ]; then
        error_exit "No ConnectX-7 devices found"
    fi
    
    log "Found ${#DEVICES[@]} ConnectX-7 device(s): ${DEVICES[*]}"
    
    # Get MST devices and PSIDs
    declare -g -A DEVICE_PSIDS
    declare -g -A DEVICE_MST_PATHS
    
    for device in "${DEVICES[@]}"; do
        # Get MST device path
        MST_DEVICE=$(mst status -v | grep "$device" | awk '{print $2}' | head -1)
        
        if [ -z "$MST_DEVICE" ]; then
            log "WARNING: Could not find MST device for PCI device $device"
            continue
        fi
        
        DEVICE_MST_PATHS["$device"]="$MST_DEVICE"
        
        # Get PSID using flint
        PSID=$(flint -d "$device" query 2>/dev/null | grep "PSID:" | awk '{print $2}' | tr -d ' ')
        
        if [ -z "$PSID" ]; then
            log "WARNING: Could not detect PSID for device $device"
            continue
        fi
        
        DEVICE_PSIDS["$device"]="$PSID"
        log "Device $device: MST=$MST_DEVICE, PSID=$PSID"
    done
    
    if [ ${#DEVICE_PSIDS[@]} -eq 0 ]; then
        error_exit "Could not detect PSID for any devices"
    fi
}

# Download firmware for detected PSID
download_firmware() {
    local psid="$1"
    
    if [ -z "${FIRMWARE_MAP[$psid]}" ]; then
        log "ERROR: No firmware mapping found for PSID: $psid"
        log "Available PSIDs in current mappings:"
        for available_psid in "${!FIRMWARE_MAP[@]}"; do
            log "  - $available_psid"
        done
        
        if [ "$AUTO_DETECT_FIRMWARE" = "true" ]; then
            log ""
            log "Auto-detection may have failed for this PSID. You can try:"
            log "1. Run with --no-auto-detect to use fallback mappings"
            log "2. Check available firmware at: $FIRMWARE_PAGE_URL"
            log "3. Update the FIRMWARE_MAP_FALLBACK in this script"
        else
            log "Please update the FIRMWARE_MAP_FALLBACK in this script for PSID: $psid"
        fi
        
        error_exit "No firmware available for PSID: $psid"
    fi
    
    local firmware_file="${FIRMWARE_MAP[$psid]}"
    local firmware_url="${FIRMWARE_BASE_URL}/${firmware_file}"
    
    log "Downloading firmware for PSID $psid..."
    log "URL: $firmware_url"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download firmware
    if wget "$firmware_url"; then
        log "✅ Firmware download completed"
    else
        error_exit "Failed to download firmware from $firmware_url"
    fi
    
    # Extract firmware
    log "Extracting firmware..."
    if unzip "$firmware_file" >/dev/null; then
        log "✅ Firmware extracted successfully"
    else
        error_exit "Failed to extract firmware file"
    fi
    
    # Find the .bin file
    BIN_FILE=$(find . -name "*.bin" -type f | head -1)
    if [ -z "$BIN_FILE" ]; then
        error_exit "Could not find .bin file in extracted firmware"
    fi
    
    log "Found firmware binary: $BIN_FILE"
    
    # Create a symlink with shorter name to avoid "File name too long" error
    local short_name="cx7_fw_${psid}.bin"
    ln -sf "$BIN_FILE" "$short_name"
    
    # Use absolute path of the short symlink (don't resolve the target)
    local abs_bin_file="$TEMP_DIR/$short_name"
    log "Created short symlink: $abs_bin_file"
    echo "$abs_bin_file"
}

# Verify firmware compatibility
verify_firmware_compatibility() {
    local device="$1"
    local firmware_file="$2"
    
    log "Verifying firmware compatibility for device $device..."
    log "Using firmware file: $firmware_file"
    
    # Check if file exists and is readable
    if [ ! -f "$firmware_file" ]; then
        log "❌ Firmware file does not exist: $firmware_file"
        return 1
    fi
    
    # Use flint to verify without burning
    local verify_cmd="flint -d \"$device\" -i \"$firmware_file\" verify"
    if [ "$FORCE_FIRMWARE" = "true" ]; then
        verify_cmd="$verify_cmd --allow_psid_change --allow_rom_change"
        log "⚠️  Force mode enabled - bypassing some compatibility checks"
    fi
    
    if eval $verify_cmd 2>&1; then
        log "✅ Firmware compatibility verified for device $device"
        return 0
    else
        if [ "$FORCE_FIRMWARE" = "true" ]; then
            log "⚠️  Compatibility check failed but force mode enabled - proceeding anyway"
            return 0
        else
            log "❌ Firmware compatibility check failed for device $device"
            log "💡 Try using --force to bypass compatibility checks (use with caution)"
            return 1
        fi
    fi
}

# Burn firmware to device
burn_firmware() {
    local device="$1"
    local firmware_file="$2"
    local mst_device="${DEVICE_MST_PATHS[$device]}"
    
    log "Burning firmware to device $device ($mst_device)..."
    log "Firmware file: $firmware_file"
    
    # Create backup of current firmware (optional)
    log "Creating firmware backup..."
    local backup_file="/tmp/firmware_backup_${device//[:\/]/_}_$(date +%Y%m%d_%H%M%S).bin"
    if flint -d "$device" read "$backup_file" 2>/dev/null; then
        log "✅ Firmware backup created: $backup_file"
    else
        log "WARNING: Could not create firmware backup"
    fi
    
    # Burn firmware
    log "Starting firmware burn process..."
    log "⚠️  WARNING: Do not interrupt this process or power off the system!"
    
    if flint -d "$mst_device" -i "$firmware_file" burn -y; then
        log "✅ Firmware burned successfully to device $device"
        return 0
    else
        log "❌ Firmware burn failed for device $device"
        return 1
    fi
}

# Main firmware installation process
install_firmware() {
    local unique_psids=($(printf '%s\n' "${DEVICE_PSIDS[@]}" | sort -u))
    
    log "Unique PSIDs detected: ${unique_psids[*]}"
    
    # Download firmware for each unique PSID
    declare -A PSID_FIRMWARE_FILES
    
    for psid in "${unique_psids[@]}"; do
        local firmware_file=$(download_firmware "$psid")
        PSID_FIRMWARE_FILES["$psid"]="$firmware_file"
    done
    
    # Verify and burn firmware for each device
    local success_count=0
    local total_devices=${#DEVICE_PSIDS[@]}
    
    for device in "${!DEVICE_PSIDS[@]}"; do
        local psid="${DEVICE_PSIDS[$device]}"
        local firmware_file="${PSID_FIRMWARE_FILES[$psid]}"
        
        log "Processing device $device with PSID $psid..."
        
        # Verify compatibility
        if ! verify_firmware_compatibility "$device" "$firmware_file"; then
            log "❌ Skipping device $device due to compatibility issues"
            continue
        fi
        
        # Ask for confirmation before burning
        echo ""
        echo "⚠️  FIRMWARE BURN WARNING ⚠️"
        echo "About to burn firmware to device: $device"
        echo "PSID: $psid"
        echo "Firmware: $(basename "$firmware_file")"
        echo ""
        read -p "Continue with firmware burn? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            log "Firmware burn cancelled by user for device $device"
            continue
        fi
        
        # Burn firmware
        if burn_firmware "$device" "$firmware_file"; then
            ((success_count++))
        fi
    done
    
    log "Firmware installation completed: $success_count/$total_devices devices updated"
    
    if [ $success_count -gt 0 ]; then
        log "⚠️  REBOOT REQUIRED: Please reboot the system to activate new firmware"
    fi
}

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        cd /
        rm -rf "$TEMP_DIR"
        log "Temporary files cleaned up"
    fi
}

# Main execution
main() {
    log "Starting ConnectX-7 firmware installation script"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Pre-flight checks
    check_root
    check_mft_tools
    start_mst_service
    
    # Load firmware mappings (auto-detect or fallback)
    load_firmware_mappings
    
    # Show firmware mapping summary
    echo ""
    echo "=== FIRMWARE MAPPING SUMMARY ==="
    if [ "$AUTO_DETECT_FIRMWARE" = "true" ] && [ ${#FIRMWARE_MAP[@]} -gt 0 ]; then
        echo "Source: Auto-detected (latest available)"
    else
        echo "Source: Static fallback mappings"
    fi
    echo "Available firmware mappings:"
    for psid in "${!FIRMWARE_MAP[@]}"; do
        echo "  PSID: $psid"
        echo "    Firmware: ${FIRMWARE_MAP[$psid]}"
    done
    echo "================================="
    echo ""
    
    # Detect devices and PSIDs
    detect_devices_and_psids
    
    # Show detected devices summary
    echo ""
    echo "=== DETECTED DEVICES SUMMARY ==="
    for device in "${!DEVICE_PSIDS[@]}"; do
        echo "Device: $device"
        echo "  PSID: ${DEVICE_PSIDS[$device]}"
        echo "  MST Path: ${DEVICE_MST_PATHS[$device]}"
        echo ""
    done
    
    # Confirm before proceeding
    read -p "Proceed with firmware download and installation? (yes/no): " proceed
    if [ "$proceed" != "yes" ]; then
        log "Installation cancelled by user"
        exit 0
    fi
    
    # Install firmware
    install_firmware
    
    log "Script execution completed"
}

# Script usage information
usage() {
    echo "ConnectX-7 Firmware Installation Script"
    echo ""
    echo "This script automatically:"
    echo "1. Auto-detects latest LTS firmware versions (or uses static mappings)"
    echo "2. Detects ConnectX-7 devices and their PSIDs"
    echo "3. Downloads appropriate firmware based on PSID"
    echo "4. Verifies firmware compatibility"
    echo "5. Burns firmware to devices (with user confirmation)"
    echo ""
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    --no-auto-detect     Use static firmware mappings instead of auto-detecting latest"
    echo "    --help, -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "    sudo $0                    # Auto-detect and install latest LTS firmware"
    echo "    sudo $0 --no-auto-detect  # Use static firmware mappings"
    echo ""
    echo "Prerequisites:"
    echo "- MFT tools must be installed (run install-mft.sh first)"
    echo "- Root privileges required"
    echo "- Internet connectivity for firmware download (auto-detect mode)"
    echo ""
    echo "⚠️  WARNING: This is a personal reference project - test thoroughly in lab!"
    echo "⚠️  Firmware updates can cause system instability if interrupted"
    echo "⚠️  Always test in lab environment before production use"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    *)
        # Parse arguments first
        parse_arguments "$@"
        # Then run main function
        main
        ;;
esac