#!/bin/bash
# ConnectX-7 Firmware Update Script using mlxup
# This script uses NVIDIA's official mlxup tool for safer firmware updates

set -e

# Configuration
LOG_FILE="/var/log/cx7-firmware-mlxup.log"
MLXUP_URL="https://network.nvidia.com/support/firmware/mlxup-mft/"

# Parse command line arguments
FORCE_UPDATE=false
QUERY_ONLY=false

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --query)
                QUERY_ONLY=true
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
ConnectX-7 Firmware Update Script using mlxup

Usage: sudo $0 [OPTIONS]

OPTIONS:
    --query              Query available firmware updates without installing
    --force              Force firmware update even if same version
    --help, -h           Show this help message

Examples:
    sudo $0              # Check and install firmware updates
    sudo $0 --query      # Only check for available updates
    sudo $0 --force      # Force update even if same version

About mlxup:
    mlxup is NVIDIA's official firmware update utility that:
    - Automatically detects compatible firmware versions
    - Handles dependency resolution and compatibility checks
    - Provides safer firmware updates with built-in validation
    - Supports rollback and recovery procedures

More information: https://network.nvidia.com/support/firmware/mlxup-mft/

⚠️  WARNING: This is a personal reference project. Test thoroughly in lab environment!

EOF
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&2
}

# Error exit function
error_exit() {
    log "ERROR: $1"
    exit 1
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
    
    if ! command -v mst >/dev/null 2>&1; then
        error_exit "MST tools not found. Please install MFT first using install-mft.sh"
    fi
    
    if ! command -v mlxup >/dev/null 2>&1; then
        log "mlxup not found, attempting to install..."
        install_mlxup
    fi
    
    log "✅ MFT tools are available"
}

# Install mlxup tool
install_mlxup() {
    log "Installing mlxup tool..."
    
    # First check if mlxup binary exists in current directory
    if [ -f "./mlxup" ]; then
        log "✅ mlxup binary found in current directory"
        log "Installing mlxup to /usr/local/bin/"
        cp "./mlxup" /usr/local/bin/mlxup
        chmod +x /usr/local/bin/mlxup
        
        # Verify installation
        if command -v mlxup >/dev/null 2>&1; then
            local installed_version=$(mlxup --version 2>/dev/null | head -1 || echo "unknown")
            log "✅ mlxup installed successfully: $installed_version"
            return 0
        else
            log "⚠️  mlxup installation verification failed, trying other methods..."
        fi
    fi
    
    # Check if it's available in the MFT installation
    local mft_path=$(which mst 2>/dev/null | xargs dirname 2>/dev/null)
    
    if [ -n "$mft_path" ] && [ -f "$mft_path/mlxup" ]; then
        log "✅ mlxup found in MFT installation: $mft_path/mlxup"
        # Create symlink if not in PATH
        if ! command -v mlxup >/dev/null 2>&1; then
            ln -sf "$mft_path/mlxup" /usr/local/bin/mlxup
        fi
        return 0
    fi
    
    # If not found locally or in MFT, download from NVIDIA website
    log "mlxup not found locally or in MFT installation, downloading from NVIDIA..."
    download_mlxup_from_nvidia
}

# Download mlxup from NVIDIA website
download_mlxup_from_nvidia() {
    log "Downloading mlxup from NVIDIA website..."
    
    # Install curl if not available
    if ! command -v curl >/dev/null 2>&1; then
        log "Installing curl for mlxup download..."
        yum install -y curl || apt-get install -y curl
    fi
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Step 1: Determine mlxup version to download
    log "Detecting latest mlxup version..."
    
    # Use known current working version as primary method
    local latest_version="4.30.0"
    
    # Verify this version exists
    local test_url="https://www.mellanox.com/downloads/firmware/mlxup/${latest_version}/SFX/linux_x64/mlxup"
    log "Verifying version $latest_version is available..."
    if curl -I --connect-timeout 5 --max-time 10 -f "$test_url" >/dev/null 2>&1; then
        log "✅ Confirmed version $latest_version is available"
    else
        log "⚠️  Version $latest_version not confirmed, trying web detection..."
        
        # Fallback: Parse the mlxup page
        local page_content=$(curl -s --connect-timeout 15 "$MLXUP_URL" 2>/dev/null || echo "")
        
        if [ -n "$page_content" ]; then
            # Look for mlxup-specific version patterns, prioritizing 4.30.x versions
            local versions=($(echo "$page_content" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | grep -E '^4\.(3[0-9]|[4-9][0-9])\.' | sort -V -u -r))
            
            # If no 4.30+ versions found, look for any 4.x versions
            if [ ${#versions[@]} -eq 0 ]; then
                versions=($(echo "$page_content" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | grep -E '^4\.' | sort -V -u -r))
            fi
            
            if [ ${#versions[@]} -gt 0 ]; then
                latest_version="${versions[0]}"
                log "Web detection found version: $latest_version"
            fi
        fi
    fi
    
    log "Using mlxup version: $latest_version"
    
    # Step 2: Construct download URLs for Linux x64
    # Use the correct NVIDIA mlxup download URL pattern
    local download_urls=(
        "https://www.mellanox.com/downloads/firmware/mlxup/${latest_version}/SFX/linux_x64/mlxup"
        "https://content.mellanox.com/firmware/mlxup/${latest_version}/SFX/linux_x64/mlxup"
        "https://network.nvidia.com/downloads/firmware/mlxup/${latest_version}/SFX/linux_x64/mlxup"
    )
    
    # Also try some fallback patterns in case the structure changes
    local fallback_urls=(
        "https://www.mellanox.com/downloads/MFT/mlxup-${latest_version}-linux-x64.tar.gz"
        "https://content.mellanox.com/MFT/mlxup-${latest_version}-linux-x64.tar.gz"
    )
    
    # Combine primary and fallback URLs
    download_urls+=("${fallback_urls[@]}")
    
    local primary_url="${download_urls[0]}"
    log "Primary download URL: $primary_url"
    log "Will try ${#download_urls[@]} different URL combinations..."
    
    # Try all URLs until one works
    local downloaded=false
    local download_file=""
    local is_binary=false
    
    for url in "${download_urls[@]}"; do
        log "Trying: $url"
        local filename=$(basename "$url")
        
        # Check if this is a direct binary download or archive
        if [[ "$filename" == "mlxup" ]]; then
            is_binary=true
            filename="mlxup-${latest_version}"
        else
            is_binary=false
        fi
        
        # Use curl with better error handling and timeout
        if curl -L --connect-timeout 10 --max-time 60 -f -o "$filename" "$url" 2>/dev/null; then
            log "✅ Downloaded mlxup from: $url"
            download_file="$filename"
            downloaded=true
            break
        fi
        
        # Clean up failed download attempt
        [ -f "$filename" ] && rm -f "$filename"
    done
    
    if [ "$downloaded" = false ]; then
        log "❌ All download attempts failed"
        log "Trying fallback: checking for mlxup in MFT package repositories..."
        
        # Last resort: try to find mlxup in system package repositories
        if command -v yum >/dev/null 2>&1; then
            if yum search mlxup 2>/dev/null | grep -q mlxup; then
                log "Found mlxup in yum repositories, attempting installation..."
                if yum install -y mlxup 2>/dev/null; then
                    log "✅ mlxup installed via yum"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 0
                fi
            fi
        elif command -v apt-get >/dev/null 2>&1; then
            if apt-cache search mlxup 2>/dev/null | grep -q mlxup; then
                log "Found mlxup in apt repositories, attempting installation..."
                if apt-get install -y mlxup 2>/dev/null; then
                    log "✅ mlxup installed via apt"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 0
                fi
            fi
        fi
        
        log ""
        log "Manual download instructions:"
        log "1. Visit: $MLXUP_URL"
        log "2. Look for mlxup version $latest_version"
        log "3. Download the Linux x64 package"
        log "4. Extract and copy mlxup binary to /usr/local/bin/"
        log ""
        error_exit "Failed to download mlxup automatically"
    fi
    
    # Step 3: Extract and install mlxup
    if [ -z "$download_file" ]; then
        error_exit "No download file specified"
    fi
    
    if [ ! -f "$download_file" ]; then
        error_exit "Downloaded mlxup file not found: $download_file"
    fi
    
    local mlxup_binary=""
    
    if [ "$is_binary" = "true" ]; then
        # Direct binary download
        log "Downloaded mlxup binary directly: $download_file"
        mlxup_binary="$download_file"
        chmod +x "$mlxup_binary"
    else
        # Archive download - extract it
        log "Extracting mlxup archive: $download_file"
        if tar -xzf "$download_file"; then
            log "✅ mlxup archive extracted successfully"
        else
            error_exit "Failed to extract mlxup archive"
        fi
        
        # Find the mlxup binary
        mlxup_binary=$(find . -name "mlxup" -type f -executable | head -1)
        
        if [ -z "$mlxup_binary" ]; then
            error_exit "mlxup binary not found in extracted archive"
        fi
    fi
    
    # Install mlxup to system location
    log "Installing mlxup to /usr/local/bin/"
    cp "$mlxup_binary" /usr/local/bin/mlxup
    chmod +x /usr/local/bin/mlxup
    
    # Verify installation
    if command -v mlxup >/dev/null 2>&1; then
        local installed_version=$(mlxup --version 2>/dev/null | head -1 || echo "unknown")
        log "✅ mlxup installed successfully: $installed_version"
    else
        error_exit "mlxup installation verification failed"
    fi
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    log "Temporary files cleaned up"
}

# Start MST service
start_mst_service() {
    log "Starting MST service..."
    
    if mst start >/dev/null 2>&1; then
        log "✅ MST service started successfully"
    else
        log "⚠️  MST service may already be running"
    fi
    
    # Wait a moment for service to initialize
    sleep 2
}

# Detect ConnectX-7 devices
detect_cx7_devices() {
    log "Detecting ConnectX-7 devices..."
    
    # Use lspci to find ConnectX-7 devices
    local devices=$(lspci | grep -i "MT2910\|ConnectX-7" | wc -l)
    
    if [ "$devices" -eq 0 ]; then
        error_exit "No ConnectX-7 devices detected"
    fi
    
    log "✅ Found $devices ConnectX-7 device(s)"
    
    # List devices for user information
    log "ConnectX-7 devices:"
    lspci | grep -i "MT2910\|ConnectX-7" | while read -r line; do
        log "  $line"
    done
}

# Query firmware updates
query_firmware_updates() {
    log "Querying available firmware updates..."
    
    echo ""
    echo "=== FIRMWARE UPDATE QUERY ==="
    
    # Run mlxup query to check for updates
    if mlxup --query; then
        log "✅ Firmware query completed successfully"
    else
        log "⚠️  Firmware query completed with warnings or no updates available"
    fi
    
    echo "============================="
    echo ""
}

# Update firmware using mlxup
update_firmware() {
    log "Starting firmware update process..."
    
    echo ""
    echo "=== FIRMWARE UPDATE PROCESS ==="
    
    # Prepare mlxup command
    local mlxup_cmd="mlxup"
    
    if [ "$FORCE_UPDATE" = "true" ]; then
        mlxup_cmd="$mlxup_cmd --force"
        log "⚠️  Force mode enabled"
    fi
    
    # Show what will be updated
    log "Checking for firmware updates..."
    if ! mlxup --query; then
        log "No firmware updates available or query failed"
        return 1
    fi
    
    echo ""
    echo "⚠️  FIRMWARE UPDATE WARNING ⚠️"
    echo "About to update firmware on all ConnectX-7 devices"
    echo "This process:"
    echo "- Will automatically download and install compatible firmware"
    echo "- May require a system reboot to complete"
    echo "- Should not be interrupted once started"
    echo ""
    read -p "Continue with firmware update? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Firmware update cancelled by user"
        return 0
    fi
    
    # Perform the firmware update
    log "Executing firmware update..."
    log "Command: $mlxup_cmd"
    
    if eval "$mlxup_cmd"; then
        log "✅ Firmware update completed successfully"
        
        echo ""
        echo "✅ Firmware Update Successful!"
        echo ""
        echo "Next steps:"
        echo "1. Reboot the system to activate new firmware:"
        echo "   sudo reboot"
        echo ""
        echo "2. After reboot, verify firmware versions:"
        echo "   sudo ./mlx-nic-health-check.sh"
        echo ""
        
        return 0
    else
        log "❌ Firmware update failed"
        return 1
    fi
}

# Main execution
main() {
    log "Starting ConnectX-7 firmware update using mlxup"
    
    # Pre-flight checks
    check_root
    check_mft_tools
    start_mst_service
    detect_cx7_devices
    
    if [ "$QUERY_ONLY" = "true" ]; then
        # Query mode - just check for updates
        query_firmware_updates
    else
        # Update mode - check and install updates
        query_firmware_updates
        
        if update_firmware; then
            log "Firmware update process completed successfully"
        else
            log "Firmware update process completed with issues"
            exit 1
        fi
    fi
    
    log "Script execution completed"
}

# Parse arguments and run main function
parse_arguments "$@"
main "$@"