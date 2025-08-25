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
    
    # mlxup is typically included with MFT, but may need separate installation
    # Check if it's available in the MFT installation
    local mft_path=$(which mst 2>/dev/null | xargs dirname 2>/dev/null)
    
    if [ -n "$mft_path" ] && [ -f "$mft_path/mlxup" ]; then
        log "✅ mlxup found in MFT installation: $mft_path/mlxup"
        # Create symlink if not in PATH
        if ! command -v mlxup >/dev/null 2>&1; then
            ln -sf "$mft_path/mlxup" /usr/local/bin/mlxup
        fi
    else
        log "⚠️  mlxup not found in MFT installation"
        log "Please ensure you have the latest MFT version that includes mlxup"
        log "Visit: $MLXUP_URL"
        error_exit "mlxup tool not available"
    fi
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