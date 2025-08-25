#!/bin/bash
# Enhanced wrapper for ConnectX-7 firmware updates
# Supports both auto-detection and static configuration modes
#
# Usage:
#   ./update-cx7-firmware.sh                    # Auto-detect latest firmware (default)
#   ./update-cx7-firmware.sh --no-auto-detect  # Use static firmware-config.json
#   ./update-cx7-firmware.sh --help            # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/firmware-config.json"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cx7-firmware.sh"
AUTO_DETECT_MODE=true

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-auto-detect)
                AUTO_DETECT_MODE=false
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    cat << EOF
ConnectX-7 Firmware Update Tool

This is a user-friendly wrapper for the ConnectX-7 firmware installation script.

Usage: $0 [OPTIONS]

OPTIONS:
    --no-auto-detect     Use static firmware-config.json instead of auto-detecting latest
    --help, -h           Show this help message

MODES:
    Auto-Detection Mode (default):
        - Automatically detects latest LTS firmware from NVIDIA website
        - Downloads and installs the most current versions
        - Requires internet connectivity
        - Recommended for staying up-to-date

    Static Configuration Mode (--no-auto-detect):
        - Uses firmware-config.json for PSID-to-firmware mappings
        - Predictable, repeatable installations
        - Works offline (if firmware files are cached)
        - Recommended for controlled environments

Examples:
    $0                    # Auto-detect and install latest firmware
    $0 --no-auto-detect  # Use static configuration file

⚠️  WARNING: This is a personal reference project - test thoroughly in lab environment!

EOF
}

# Check if jq is available for JSON parsing (only needed in static mode)
check_jq_availability() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq for JSON parsing..."
        sudo yum install -y jq || sudo apt-get install -y jq
    fi
}

# Check if install script exists
check_prerequisites() {
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "ERROR: Installation script not found: $INSTALL_SCRIPT"
        exit 1
    fi
    
    # Only check config file in static mode
    if [ "$AUTO_DETECT_MODE" = "false" ]; then
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "ERROR: Configuration file not found: $CONFIG_FILE"
            echo "Static mode requires firmware-config.json for PSID mappings"
            exit 1
        fi
        check_jq_availability
    fi
}

# Show firmware information based on mode
show_firmware_info() {
    echo "=== ConnectX-7 Firmware Update Tool ==="
    echo ""
    
    if [ "$AUTO_DETECT_MODE" = "true" ]; then
        echo "🔍 Mode: Auto-Detection (Latest LTS Firmware)"
        echo "   - Will automatically detect latest firmware from NVIDIA website"
        echo "   - Downloads most current LTS versions for detected PSIDs"
        echo "   - Requires internet connectivity"
        echo ""
        echo "📋 Process:"
        echo "   1. Auto-detect latest firmware versions"
        echo "   2. Detect ConnectX-7 devices and PSIDs"
        echo "   3. Match PSIDs to latest firmware"
        echo "   4. Download and install firmware"
        echo ""
    else
        echo "📁 Mode: Static Configuration (firmware-config.json)"
        echo "   - Using predefined firmware mappings from configuration file"
        echo "   - Predictable, repeatable installations"
        echo "   - Works offline if firmware files are cached"
        echo ""
        
        # Show available firmware versions from config
        echo "Available firmware configurations:"
        jq -r '.firmware_mappings | to_entries[] | "   PSID: \(.key) - Version: \(.value.version) - \(.value.description)"' "$CONFIG_FILE"
        echo ""
        
        # Show latest LTS versions
        echo "Latest LTS versions (from config):"
        jq -r '.latest_lts_versions | to_entries[] | "   Model: \(.key) - Version: \(.value)"' "$CONFIG_FILE"
        echo ""
    fi
    
    # Show important notes (from config file if available, or general warnings)
    echo "⚠️  Important Notes:"
    if [ -f "$CONFIG_FILE" ]; then
        jq -r '.notes[]' "$CONFIG_FILE" | sed 's/^/   - /'
    else
        echo "   - This is a personal reference project - test thoroughly in lab!"
        echo "   - Always backup current firmware before updates"
        echo "   - Verify PSID compatibility before installation"
        echo "   - Reboot required after firmware installation"
    fi
    echo ""
}

# Get user confirmation
get_user_confirmation() {
    echo "🚀 Ready to proceed with firmware update"
    echo ""
    
    if [ "$AUTO_DETECT_MODE" = "true" ]; then
        read -p "Proceed with auto-detection and firmware update? (yes/no): " confirm
    else
        read -p "Proceed with static configuration firmware update? (yes/no): " confirm
    fi
    
    if [ "$confirm" != "yes" ]; then
        echo "Update cancelled by user"
        exit 0
    fi
}

# Run the firmware installation
run_firmware_installation() {
    echo ""
    echo "🔧 Starting firmware installation..."
    echo "=================================="
    
    if [ "$AUTO_DETECT_MODE" = "true" ]; then
        # Run with auto-detection (default behavior)
        sudo "$INSTALL_SCRIPT"
    else
        # Run with static mappings
        sudo "$INSTALL_SCRIPT" --no-auto-detect
    fi
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Show firmware information
    show_firmware_info
    
    # Get user confirmation
    get_user_confirmation
    
    # Run firmware installation
    run_firmware_installation
    
    echo ""
    echo "✅ Firmware update process completed!"
    echo "⚠️  Remember to reboot the system to activate new firmware"
}

# Execute main function
main "$@"