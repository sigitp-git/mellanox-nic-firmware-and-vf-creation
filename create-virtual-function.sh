#!/bin/bash
# Virtual Function Creation Script for Mellanox ConnectX-7 NICs
# This script automatically detects ConnectX-7 interfaces and creates Virtual Functions

set -e

# Configuration
NUMBER_VFS=127
LOG_FILE="/var/log/create-vf.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting Virtual Function creation script"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Ensure required tools are installed
if ! command -v lshw >/dev/null 2>&1; then
    log "Installing lshw..."
    yum install -y lshw
fi

if ! command -v jq >/dev/null 2>&1; then
    log "Installing jq..."
    yum install -y jq
fi

# Check if MFT tools are available for mlxconfig
if ! command -v mlxconfig >/dev/null 2>&1; then
    log "WARNING: mlxconfig not found. Hardware VF configuration will be skipped."
    log "Install MFT tools first if you want to configure hardware VF limits."
    MLXCONFIG_AVAILABLE=false
else
    MLXCONFIG_AVAILABLE=true
    log "✅ mlxconfig found - hardware VF configuration will be performed"
fi

# Configure hardware VF limits using mlxconfig
configure_hardware_vf_limits() {
    if [ "$MLXCONFIG_AVAILABLE" = "false" ]; then
        log "Skipping hardware VF configuration - mlxconfig not available"
        return 0
    fi
    
    log "Configuring hardware VF limits using mlxconfig..."
    
    # Detect only physical function Mellanox devices (not VFs)
    # Physical functions typically end in .0 or .1, VFs have higher numbers
    local mellanox_devices=$(lspci | grep -i "mellanox\|connectx" | awk '{print $1}' | grep -E '\.(0|1)$' || true)
    
    if [ -z "$mellanox_devices" ]; then
        log "No Mellanox devices found via lspci"
        return 0
    fi
    
    local devices_configured=0
    local reboot_required=false
    
    # Process each device
    while IFS= read -r device; do
        if [ -z "$device" ]; then
            continue
        fi
        
        log "Processing Mellanox device: $device"
        
        # Check current VF configuration
        local current_vfs=$(mlxconfig -d "$device" query 2>/dev/null | grep "NUM_OF_VFS" | awk '{print $2}' || echo "unknown")
        log "Current hardware VF limit for $device: $current_vfs"
        
        # Set VF limit if different from target
        if [ "$current_vfs" != "$NUMBER_VFS" ]; then
            log "Setting hardware VF limit to $NUMBER_VFS for device $device..."
            
            # Try with --yes flag first
            if mlxconfig -d "$device" set NUM_OF_VFS="$NUMBER_VFS" --yes >/dev/null 2>&1; then
                log "✅ Successfully configured hardware VF limit for $device"
                devices_configured=$((devices_configured + 1))
                reboot_required=true
            else
                # Fallback: try with echo "y" pipe
                log "Retrying with interactive prompt..."
                if echo "y" | mlxconfig -d "$device" set NUM_OF_VFS="$NUMBER_VFS" >/dev/null 2>&1; then
                    log "✅ Successfully configured hardware VF limit for $device (with prompt)"
                    devices_configured=$((devices_configured + 1))
                    reboot_required=true
                else
                    log "❌ Failed to configure hardware VF limit for $device"
                    log "   You may need to run manually: mlxconfig -d $device set NUM_OF_VFS=$NUMBER_VFS"
                fi
            fi
        else
            log "Hardware VF limit already correct for $device ($current_vfs)"
        fi
        
    done <<< "$mellanox_devices"
    
    if [ "$devices_configured" -gt 0 ]; then
        log "⚠️  Hardware VF configuration completed for $devices_configured device(s)"
        log "⚠️  REBOOT REQUIRED for hardware changes to take effect!"
        log "⚠️  Run 'sudo reboot' after this script completes"
    fi
    
    return 0
}

# Auto-detect ConnectX-7 interfaces
log "Detecting ConnectX-7 network interfaces..."
INTERFACES=$(lshw -class network -json 2>/dev/null | jq -r '.[] | select(.product=="MT2910 Family [ConnectX-7]").logicalname' 2>/dev/null | grep -v null || true)

if [ -z "$INTERFACES" ]; then
    log "ERROR: No ConnectX-7 interfaces found!"
    exit 1
fi

# Convert to array
readarray -t INTERFACE_ARRAY <<< "$INTERFACES"

log "Found ${#INTERFACE_ARRAY[@]} ConnectX-7 interface(s): ${INTERFACE_ARRAY[*]}"

# Step 1: Configure hardware VF limits (requires reboot)
configure_hardware_vf_limits

# Step 2: Create runtime VFs for each interface
for interface in "${INTERFACE_ARRAY[@]}"; do
    if [ -z "$interface" ]; then
        continue
    fi
    
    log "Processing interface: $interface"
    
    # Check if interface exists
    if [ ! -d "/sys/class/net/$interface" ]; then
        log "WARNING: Interface $interface not found in /sys/class/net/"
        continue
    fi
    
    # Check current VF count
    CURRENT_VFS=$(cat "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null || echo "0")
    log "Current VFs for $interface: $CURRENT_VFS"
    
    # Check maximum supported VFs
    MAX_VFS=$(cat "/sys/class/net/$interface/device/sriov_totalvfs" 2>/dev/null || echo "0")
    log "Maximum supported VFs for $interface: $MAX_VFS"
    
    # Always try to set to the requested number (127), regardless of current max
    VFS_TO_CREATE=$NUMBER_VFS
    
    log "Attempting to create $VFS_TO_CREATE Virtual Functions for interface: $interface"
    log "Current VFs: $CURRENT_VFS, Hardware maximum: $MAX_VFS"
    
    # Always reset to 0 first, then set to desired number
    log "Step 1: Resetting VFs to 0 for $interface..."
    if echo 0 > "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null; then
        log "✅ Successfully reset VFs to 0 for $interface"
        sleep 3  # Give more time for reset
        
        # Verify reset
        RESET_VFS=$(cat "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null || echo "unknown")
        log "Verified reset: $interface now has $RESET_VFS VFs"
        
        # Step 2: Set to desired number
        log "Step 2: Setting VFs to $VFS_TO_CREATE for $interface..."
        if echo "$VFS_TO_CREATE" > "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null; then
            log "✅ Successfully set VFs to $VFS_TO_CREATE for $interface"
            
            # Verify creation
            sleep 3
            CREATED_VFS=$(cat "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null || echo "0")
            ACTUAL_MAX=$(cat "/sys/class/net/$interface/device/sriov_totalvfs" 2>/dev/null || echo "0")
            
            if [ "$CREATED_VFS" -eq "$VFS_TO_CREATE" ]; then
                log "✅ VF creation verified for $interface: $CREATED_VFS VFs active (max: $ACTUAL_MAX)"
            elif [ "$CREATED_VFS" -gt 0 ]; then
                log "⚠️  Partial success for $interface: created $CREATED_VFS VFs (requested $VFS_TO_CREATE, max: $ACTUAL_MAX)"
            else
                log "❌ VF creation failed for $interface: expected $VFS_TO_CREATE, got $CREATED_VFS"
            fi
        else
            log "❌ Failed to set VFs to $VFS_TO_CREATE for $interface"
            log "   This may indicate the hardware limit hasn't been applied yet (reboot required)"
        fi
    else
        log "❌ Failed to reset VFs to 0 for $interface"
    fi
done

# Summary
log "Virtual Function creation completed"
log "Summary:"
for interface in "${INTERFACE_ARRAY[@]}"; do
    if [ -z "$interface" ]; then
        continue
    fi
    FINAL_VFS=$(cat "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null || echo "0")
    log "  $interface: $FINAL_VFS VFs"
done

log "Script execution finished"