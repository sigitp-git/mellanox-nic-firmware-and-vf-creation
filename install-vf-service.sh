#!/bin/bash
# Installation script for Mellanox VF Creation Service

set -e

LOG_FILE="/var/log/vf-service-install.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

log "Installing Mellanox VF Creation Service"

# Copy the VF creation script to system location
SCRIPT_SOURCE="./create-virtual-function.sh"
SCRIPT_DEST="/usr/local/bin/create-virtual-function.sh"

if [ ! -f "$SCRIPT_SOURCE" ]; then
    log "ERROR: $SCRIPT_SOURCE not found in current directory"
    exit 1
fi

log "Copying VF creation script to $SCRIPT_DEST"
cp "$SCRIPT_SOURCE" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
chown root:root "$SCRIPT_DEST"

# Copy the service file to systemd directory
SERVICE_SOURCE="./create-vf.service"
SERVICE_DEST="/etc/systemd/system/create-vf.service"

if [ ! -f "$SERVICE_SOURCE" ]; then
    log "ERROR: $SERVICE_SOURCE not found in current directory"
    exit 1
fi

log "Installing systemd service file to $SERVICE_DEST"
cp "$SERVICE_SOURCE" "$SERVICE_DEST"
chmod 644 "$SERVICE_DEST"
chown root:root "$SERVICE_DEST"

# Reload systemd daemon
log "Reloading systemd daemon"
systemctl daemon-reload

# Enable the service
log "Enabling create-vf service"
systemctl enable create-vf.service

# Check service status
log "Service installation completed"
log "Service status:"
systemctl status create-vf.service --no-pager || true

log "Installation summary:"
log "✅ Script installed to: $SCRIPT_DEST"
log "✅ Service file installed to: $SERVICE_DEST"
log "✅ Service enabled for automatic startup"

echo ""
echo "Service installation completed!"
echo ""
echo "Available commands:"
echo "  Start service:    sudo systemctl start create-vf"
echo "  Stop service:     sudo systemctl stop create-vf"
echo "  Check status:     sudo systemctl status create-vf"
echo "  View logs:        sudo journalctl -u create-vf -f"
echo "  Disable service:  sudo systemctl disable create-vf"
echo ""
echo "The service will automatically run on system boot/reboot."
echo "Check logs at: $LOG_FILE"