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

# Ensure required tools are installed
if ! command -v lshw >/dev/null 2>&1; then
    log "Installing lshw..."
    yum install -y lshw
fi

if ! command -v jq >/dev/null 2>&1; then
    log "Installing jq..."
    yum install -y jq
fi

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

# Create VFs for each interface
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
    
    # Validate VF count
    if [ "$NUMBER_VFS" -gt "$MAX_VFS" ]; then
        log "WARNING: Requested VFs ($NUMBER_VFS) exceeds maximum ($MAX_VFS) for $interface. Using maximum."
        VFS_TO_CREATE=$MAX_VFS
    else
        VFS_TO_CREATE=$NUMBER_VFS
    fi
    
    # Create VFs if needed
    if [ "$CURRENT_VFS" -ne "$VFS_TO_CREATE" ]; then
        log "Creating $VFS_TO_CREATE Virtual Functions for interface: $interface"
        
        # First, reset to 0 if VFs already exist
        if [ "$CURRENT_VFS" -gt 0 ]; then
            log "Resetting existing VFs for $interface..."
            echo 0 > "/sys/class/net/$interface/device/sriov_numvfs"
            sleep 2
        fi
        
        # Create new VFs
        if echo "$VFS_TO_CREATE" > "/sys/class/net/$interface/device/sriov_numvfs"; then
            log "Successfully created $VFS_TO_CREATE VFs for $interface"
            
            # Verify creation
            sleep 2
            CREATED_VFS=$(cat "/sys/class/net/$interface/device/sriov_numvfs" 2>/dev/null || echo "0")
            if [ "$CREATED_VFS" -eq "$VFS_TO_CREATE" ]; then
                log "✅ VF creation verified for $interface: $CREATED_VFS VFs active"
            else
                log "❌ VF creation verification failed for $interface: expected $VFS_TO_CREATE, got $CREATED_VFS"
            fi
        else
            log "ERROR: Failed to create VFs for $interface"
        fi
    else
        log "VFs already configured correctly for $interface ($CURRENT_VFS VFs)"
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