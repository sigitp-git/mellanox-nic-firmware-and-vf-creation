#!/bin/bash
# Mellanox ConnectX-7 NIC Health Check Script
# This script provides comprehensive health monitoring for Mellanox ConnectX-7 NICs
#
# Usage: ./mlx-nic-health-check.sh [OPTIONS]

# Show usage information
show_usage() {
    cat << EOF
Mellanox ConnectX-7 NIC Health Check Script

This script provides comprehensive health monitoring for Mellanox ConnectX-7 NICs.

Usage: $0 [OPTIONS]

OPTIONS:
    --help, -h           Show this help message

Features:
    • Auto-detects all ConnectX-7 devices
    • Checks MST service status
    • Monitors device configuration and link status
    • Reports firmware versions and temperature
    • Verifies VF configuration
    • Provides detailed troubleshooting information

Prerequisites:
    • MFT tools must be installed
    • Root privileges recommended for full functionality
    • ConnectX-7 hardware present in system

Examples:
    sudo $0              # Run comprehensive health check
    $0 --help           # Show this help message

⚠️  Note: This is a personal reference project - test thoroughly in lab environment!

EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    "")
        # No arguments, proceed with health check
        ;;
    *)
        echo "ERROR: Unknown option: $1"
        show_usage
        exit 1
        ;;
esac

echo "=== Mellanox NIC Health Check ==="
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"

# Start MST service
echo "Starting MST service..."
mst start

# Check MST status
echo -e "\n=== MST Status ==="
mst status

# Auto-detect ConnectX-7 devices
echo -e "\n=== Detecting ConnectX-7 Devices ==="
mapfile -t DEVICES < <(lspci | grep -i "MT2910\|ConnectX-7" | awk '{print $1}')

if [ ${#DEVICES[@]} -eq 0 ]; then
    echo "No ConnectX-7 devices found!"
    exit 1
fi

echo "Found ${#DEVICES[@]} ConnectX-7 device(s): ${DEVICES[*]}"

# Health check for each device
for device in "${DEVICES[@]}"; do
    echo -e "\n========================================"
    echo "=== Device: $device ==="
    echo "========================================"

    # Get MST device path for this PCI device
    MST_DEVICE=$(mst status -v | grep "$device" | awk '{print $2}')

    # Basic configuration query
    echo -e "\n--- Configuration Status ---"
    mlxconfig -d $device query | grep -E "(Device type|Name|Description|Configurations)" || echo "Configuration query failed"

    # Link status for both ports
    echo -e "\n--- Link Status ---"
    for port in 1 2; do
        echo "Port $port:"
        mlxlink -d $device -p $port 2>/dev/null | grep -E "(Operational|Physical state|Speed|Width|Enabled Link Speed|Supported Cable Speed)" || echo "  Port $port not available or link down"
    done

    # Firmware info
    echo -e "\n--- Firmware Information ---"
    flint -d $device query 2>/dev/null | grep -E "(FW Version|Product Version|PSID|Description)" || echo "Firmware query failed"

    # Temperature check
    echo -e "\n--- Temperature Monitoring ---"
    if [ -n "$MST_DEVICE" ]; then
        TEMP=$(mget_temp -d "$MST_DEVICE" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "Temperature: ${TEMP}°C"
            # Temperature warning thresholds
            if [ "$TEMP" -gt 80 ]; then
                echo "⚠️  WARNING: High temperature detected! ($TEMP°C > 80°C)"
            elif [ "$TEMP" -gt 70 ]; then
                echo "⚠️  CAUTION: Elevated temperature ($TEMP°C > 70°C)"
            else
                echo "✅ Temperature normal ($TEMP°C)"
            fi
        else
            echo "Temperature data not available"
        fi
    else
        echo "MST device path not found for $device"
    fi

    # PCIe link status
    echo -e "\n--- PCIe Information ---"
    lspci -vvv -s $device 2>/dev/null | grep -E "(LnkCap|LnkSta)" || echo "PCIe information not available"
done

# VF Status Check
echo -e "\n========================================"
echo "=== Virtual Function Status ==="
echo "========================================"

for device in "${DEVICES[@]}"; do
    echo -e "\nDevice $device:"
    VF_COUNT=$(mlxconfig -d $device query 2>/dev/null | grep NUM_OF_VFS | awk '{print $2}')
    if [ -n "$VF_COUNT" ]; then
        echo "  Configured VFs: $VF_COUNT"
        if [ "$VF_COUNT" -eq 127 ]; then
            echo "  ✅ Maximum VFs configured"
        elif [ "$VF_COUNT" -gt 0 ]; then
            echo "  ⚠️  Partial VF configuration ($VF_COUNT/127)"
        else
            echo "  ❌ No VFs configured"
        fi
    else
        echo "  ❌ VF query failed"
    fi
done

# Network interface status
echo -e "\n========================================"
echo "=== Network Interface Status ==="
echo "========================================"

# Check if lshw is available
if command -v lshw >/dev/null 2>&1; then
    echo "ConnectX-7 Network Interfaces:"
    lshw -class network -json 2>/dev/null | jq -r '.[] | select(.product=="MT2910 Family [ConnectX-7]") | "  Interface: \(.logicalname // "N/A") - \(.description // "N/A")"' 2>/dev/null || echo "  Network interface information not available"
else
    echo "lshw not installed - network interface details unavailable"
fi

# Summary
echo -e "\n========================================"
echo "=== Health Check Summary ==="
echo "========================================"
echo "Devices checked: ${#DEVICES[@]}"
echo "Timestamp: $(date)"
echo "Status: Health check completed"
echo -e "\n💡 Tip: Run 'sudo systemctl status create-vf.service' to check VF creation service status"
echo "💡 Tip: Monitor logs with 'dmesg | grep -i mellanox' for hardware messages"