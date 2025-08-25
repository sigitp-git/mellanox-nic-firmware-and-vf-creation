# Mellanox ConnectX-7 NIC Configuration and Health Monitoring

## ⚠️ IMPORTANT DISCLAIMER ⚠️

**This is a personal reference project and educational resource only.**

- **NOT FOR PRODUCTION USE** without extensive testing in your specific lab environment
- **TEST MULTIPLE TIMES** in isolated lab environments before considering any production deployment
- **NO WARRANTY** - Use at your own risk and responsibility
- **FIRMWARE UPDATES** can permanently damage hardware if not compatible
- **ALWAYS BACKUP** your current firmware before making any changes
- **VERIFY COMPATIBILITY** with your specific hardware model and PSID
- The author assumes **NO RESPONSIBILITY** for any hardware damage, data loss, or system downtime

**Recommended Approach:**
1. Set up dedicated lab environment with identical hardware
2. Test all scripts and procedures multiple times
3. Document your specific configuration and results
4. Only proceed to production after thorough validation
5. Have rollback procedures ready

---

This guide provides comprehensive instructions for installing, configuring, and monitoring Mellanox ConnectX-7 NICs on AWS instances with SR-IOV support.

## Overview

This repository contains enhanced tools and scripts for:
- **Automated MFT Installation** with latest version detection
- **Intelligent Firmware Management** with auto-detection of latest LTS versions
- **Comprehensive Health Monitoring** of ConnectX-7 NICs
- **SR-IOV Virtual Function** configuration and management
- **Automated Testing Framework** for validation and quality assurance
- **User-friendly Wrappers** for simplified operations

### 🆕 New Features

- **Auto-Detection**: Automatically finds latest MFT and firmware versions from NVIDIA
- **Smart Fallbacks**: Uses static configurations when auto-detection fails
- **Comprehensive Testing**: Built-in test suites for validation
- **Enhanced Safety**: Multiple confirmation prompts and backup creation
- **Consistent Interface**: Standardized help and error handling across all scripts

## Understanding PSID (Parameter-Set IDentification)

A Mellanox NIC PSID, or Parameter-Set IDentification, is a 16-character string embedded in the firmware image of a Mellanox (now NVIDIA) network adapter. It serves as a unique identifier for a specific configuration of the firmware, allowing firmware tools to recognize and manage settings during updates. The PSID helps ensure that custom firmware configurations are handled correctly by the burning tools and that the device retains its intended settings.

### What it does:

**Identifies firmware configuration:**
The PSID acts as a label for a particular set of firmware parameters and settings.

**Manages firmware updates:**
Firmware burning tools use the PSID to understand the existing firmware configuration on the device, helping to preserve settings when updating firmware.

**Supports custom configurations:**
It allows OEMs or users to assign a unique PSID to their own custom firmware configurations, distinguishing them from standard releases.

### How to find it:

You can use the NVIDIA command-line tools, such as `flint` or `mst start`, to query the device and retrieve its PSID. For example:

```bash
# Query PSID using flint
flint -d /dev/mst/mt4099_pci_cr0 query

# Or start MST service and query specific device
mst start
# Then query the specific device name
```

### Key Characteristics:

- **16-character ASCII string:** The PSID is a fixed-length string of 16 ASCII characters
- **Firmware component:** It is an integral part of the firmware image stored on the device's non-volatile memory (NVMEM)
- **Configuration identifier:** Each PSID corresponds to a specific firmware configuration and feature set

### PSID to OPN Mapping:

Source: https://docs.nvidia.com/networking/display/connectx7firmwarev28352000lts/firmware+compatible+products

The following table shows the mapping between PSID (Parameter-Set IDentification) and OPN (Ordering Part Number) for ConnectX-7 devices:

| PSID | OPN | Description |
|------|-----|-------------|
| MT_0000000834 | MCX755106AS-HEA | ConnectX-7 Dual-Port 200GbE QSFP112 Adapter Card |
| MT_0000000833 | MCX755106AS-HEA | ConnectX-7 Dual-Port 200GbE QSFP112 Adapter Card (Alternative PSID) |

**Note:** The PSID is used by firmware management tools to identify the correct firmware version and configuration for your specific hardware model. Always verify your device's PSID before firmware updates using `flint -d <device> query`.

## Prerequisites

- AWS EC2 instance with ConnectX-7 NICs
- Root or sudo access
- Internet connectivity for downloading tools
- Amazon Linux 2023 or compatible Linux distribution

## Quick Start

1. **Test Scripts**: Validate all functionality before use
   ```bash
   ./quick-test.sh              # Quick validation (30 seconds)
   ./test-all-scripts.sh        # Comprehensive testing (2-3 minutes)
   ```

2. **Install MFT Tools**: Automatically detect and install latest version
   ```bash
   sudo ./install-mft.sh        # Auto-detect latest LTS version
   sudo ./install-mft.sh --help # Show all options
   ```

3. **Health Check**: Monitor ConnectX-7 NIC status
   ```bash
   sudo ./mlx-nic-health-check.sh
   ```

4. **Firmware Update**: Auto-detect and install latest firmware
   ```bash
   # Using mlxup (NVIDIA's official firmware update tool) - RECOMMENDED
   sudo ./update-cx7-firmware-mlxup.sh        # Check and install firmware updates
   sudo ./update-cx7-firmware-mlxup.sh --query # Only check for available updates
   sudo ./update-cx7-firmware-mlxup.sh --force # Force update even if same version
   
   # Alternative: Custom firmware scripts
   sudo ./update-cx7-firmware.sh              # Auto-detect mode
   sudo ./update-cx7-firmware.sh --no-auto-detect  # Static config mode
   ```

5. **Configure VFs**: Set up Virtual Functions as needed
   ```bash
   sudo ./create-virtual-function.sh           # Configure hardware VF limits and create VFs
   # Note: Reboot may be required if hardware VF limits are changed
   ```

## Testing Framework

### 🧪 Built-in Test Suites

Before using any scripts in production, validate them with our comprehensive testing framework:

#### Quick Test (30 seconds)
```bash
./quick-test.sh
```
**Validates:**
- Script existence and permissions
- Help function availability
- JSON configuration validity
- Basic network connectivity
- Hardware detection

#### Comprehensive Test (2-3 minutes)
```bash
./test-all-scripts.sh
```
**Validates:**
- All quick test items plus:
- Version detection logic
- Command-line argument parsing
- Dependency checking
- Error handling mechanisms
- Security and safety features
- Integration testing

#### Test Results
```
🚀 Quick Test - Mellanox ConnectX-7 Scripts
===========================================

📁 Checking required files...
  ✓ install-mft.sh
  ✓ install-cx7-firmware.sh
  ✓ update-cx7-firmware.sh
  ✓ firmware-config.json
  ✓ mlx-nic-health-check.sh

✅ Quick test completed!
```

## Installation

### 1. Automated MFT Installation

**🆕 Enhanced with Auto-Detection**: The script automatically detects and downloads the latest LTS version:

```bash
# Automated installation (recommended)
sudo ./install-mft.sh                    # Auto-detect latest LTS version
sudo ./install-mft.sh --no-auto-detect  # Use fallback version
sudo ./install-mft.sh --version 4.30.1-1210  # Specify exact version
sudo ./install-mft.sh --help            # Show all options
```

**Features:**
- **Auto-Detection**: Finds latest LTS version from NVIDIA website
- **Fallback Safety**: Uses static version if detection fails
- **Version Validation**: Ensures proper version format
- **Comprehensive Logging**: Detailed installation logs
- **Dependency Management**: Automatically installs required packages

**Manual Installation** (if needed):
```bash
# Install dependencies first
sudo yum install -y gcc rpm-build make kernel-devel elfutils-libelf-devel perl lshw jq

# Then run automated installer
sudo ./install-mft.sh
```

### 2. Health Check Script

**🆕 Enhanced with Help System**: Comprehensive health monitoring with standardized interface:

```bash
# Show help and options
./mlx-nic-health-check.sh --help

# Run comprehensive health check
sudo ./mlx-nic-health-check.sh
```

**Features:**
- Auto-detects all ConnectX-7 devices
- Monitors configuration, link status, and firmware
- Reports temperature and VF configuration
- Provides troubleshooting information

## Scripts and Tools

### 🧪 Testing and Validation Scripts

- **`quick-test.sh`**: Fast 30-second validation of all core functionality
- **`test-all-scripts.sh`**: Comprehensive 2-3 minute test suite with detailed reporting

**Testing Features:**
- Non-destructive validation without hardware requirements
- Color-coded output with clear pass/fail indicators
- Detailed logging and actionable error messages
- Network connectivity and dependency checking
- Integration testing between scripts

### 🔧 Installation and Management Scripts

#### **`install-mft.sh`** - Enhanced MFT Installation
**🆕 Auto-Detection Capabilities:**
- Automatically detects latest LTS MFT version from NVIDIA website
- Multiple detection methods with robust fallback system
- Version format validation and comprehensive error handling
- Command-line options for manual control

```bash
sudo ./install-mft.sh                    # Auto-detect latest
sudo ./install-mft.sh --no-auto-detect  # Use fallback version
sudo ./install-mft.sh --version X.Y.Z-W # Specify exact version
```

#### **`install-cx7-firmware.sh`** - Intelligent Firmware Management
**🆕 Auto-Detection Capabilities:**
- Automatically detects latest LTS firmware versions for different PSIDs
- PSID-to-firmware mapping with model recognition
- Firmware compatibility verification before installation
- Automatic backup creation and comprehensive safety checks

```bash
sudo ./install-cx7-firmware.sh                    # Auto-detect latest firmware
sudo ./install-cx7-firmware.sh --no-auto-detect  # Use static mappings
```

#### **`update-cx7-firmware.sh`** - User-Friendly Wrapper
**🆕 Mode-Aware Operation:**
- Auto-detection mode for latest firmware (default)
- Static configuration mode for predictable deployments
- Clear process explanation and mode indication
- Enhanced user interface with progress indicators

```bash
sudo ./update-cx7-firmware.sh                    # Auto-detect mode
sudo ./update-cx7-firmware.sh --no-auto-detect  # Static config mode
```

### 📊 Health Monitoring Scripts

#### **`mlx-nic-health-check.sh`** - Enhanced Health Monitoring
**🆕 Standardized Interface:**
- Comprehensive help system with usage information
- Auto-discovery of MT2910/ConnectX-7 devices via `lspci`
- Temperature monitoring, link status verification, and firmware checking
- VF count verification and detailed troubleshooting output

```bash
./mlx-nic-health-check.sh --help    # Show help and options
sudo ./mlx-nic-health-check.sh      # Run comprehensive check
```

### 🔄 Virtual Function Management

#### **`create-virtual-function.sh`** - VF Creation Script
- Auto-detects ConnectX-7 network interfaces
- Creates maximum supported VFs (up to 127 per port)
- Validates VF creation with comprehensive logging
- Supports both manual execution and systemd service

### 📋 Configuration Files

#### **`firmware-config.json`** - Firmware Configuration
**Enhanced Structure:**
- PSID-to-firmware mappings with version information
- Latest LTS version tracking for different models
- Comprehensive metadata and release notes
- Easy updates for new firmware releases

```json
{
  "firmware_mappings": {
    "MT_0000000834": {
      "filename": "fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip",
      "version": "28.39.3560",
      "description": "MCX755106AS-HEA_Ax LTS Firmware"
    }
  }
}
```

### 🛠️ Service Management

- **`install-vf-service.sh`**: Systemd service installation for automatic VF creation
- **`create-vf.service`**: Systemd service unit for automatic VF creation on boot

### Expected Health Check Output

```
=== Mellanox NIC Health Check ===
=== Device: 0000:05:00.0 ===
Configuration Status:
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Link Status:
Physical state      : LinkUp
Speed              : 200G
Width              : 4x
Firmware Info:
FW Version:        28.40.1000
Temperature:       65°C
```

## Firmware Management

**⚠️ CRITICAL WARNING: FIRMWARE OPERATIONS ARE HIGH-RISK ⚠️**

**Before proceeding with ANY firmware operations:**
- This is a **PERSONAL REFERENCE PROJECT** - not production-ready
- **MANDATORY LAB TESTING** required before any production use
- Firmware updates can **PERMANENTLY DAMAGE** your hardware
- **BACKUP CURRENT FIRMWARE** before making changes
- Ensure you have **RECOVERY PROCEDURES** in place
- **VERIFY PSID COMPATIBILITY** with your exact hardware model

### Download Latest LTS Firmware
As of 8/24/2025

Always use the latest LTS firmware version from NVIDIA:

```bash
# Check https://network.nvidia.com/support/firmware/connectx7/ for latest LTS version

# For firmware version 28.43.3608 (MCX755106AS-HEA_Ax PSID):
# The right download for 28.43.3608 is:
wget https://www.mellanox.com/downloads/firmware/fw-ConnectX7-rel-28_43_3608-MCX755106AS-HEA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin.zip

# Example for other versions:
# wget https://www.mellanox.com/downloads/firmware/fw-ConnectX7-rel-28_45_1200-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip

unzip fw-ConnectX7-rel-*.zip
```

### Automated Firmware Installation

**🆕 Recommended Method:** Use NVIDIA's official `mlxup` tool for the safest and most reliable firmware updates:

```bash
# Using mlxup (NVIDIA's official firmware update tool) - RECOMMENDED
sudo ./update-cx7-firmware-mlxup.sh        # Check and install firmware updates
sudo ./update-cx7-firmware-mlxup.sh --query # Only check for available updates
sudo ./update-cx7-firmware-mlxup.sh --force # Force update even if same version
```

**Alternative Methods:** Custom firmware installation scripts:

```bash
# Custom automated firmware update
sudo ./update-cx7-firmware.sh

# Direct method with full automation
sudo ./install-cx7-firmware.sh
```

**Features of mlxup (Recommended):**
- **Official NVIDIA Tool:** Uses NVIDIA's official firmware update utility
- **Automatic Compatibility:** Handles dependency resolution and compatibility checks automatically
- **Safe Updates:** Built-in validation and rollback procedures
- **Latest Firmware:** Always downloads the most appropriate firmware version
- **Comprehensive Support:** Supports all ConnectX series devices
- **Production Ready:** Designed for enterprise and production environments

**Features of Custom Scripts (Alternative):**
- **Auto-detection:** Automatically detects ConnectX-7 devices and their PSIDs
- **PSID matching:** Downloads correct firmware based on detected PSID
- **Safety checks:** Verifies firmware compatibility before installation
- **Backup creation:** Creates automatic backups of current firmware
- **User confirmation:** Requires explicit confirmation before burning firmware
- **Comprehensive logging:** Detailed logs for troubleshooting and audit trails

**Configuration Management:**
The `firmware-config.json` file contains PSID-to-firmware mappings and can be updated with new firmware versions:

```json
{
  "firmware_mappings": {
    "MT_0000000834": {
      "filename": "fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip",
      "version": "28.39.3560",
      "description": "MCX755106AS-HEA_Ax LTS Firmware"
    }
  }
}
```

### Manual Firmware Update (Use with Caution)

**⚠️ Warning: Manual firmware updates require careful testing and can cause system downtime**

```bash
# Manual method - burn firmware to devices (test in lab environment first)
sudo flint -d /dev/mst/mt4129_pciconf0 -i fw-ConnectX7-rel-*.bin burn
sudo flint -d /dev/mst/mt4129_pciconf1 -i fw-ConnectX7-rel-*.bin burn
```

## 🆕 Enhanced Features and Capabilities

### Auto-Detection System
**Intelligent Version Management:**
- **MFT Tools**: Automatically detects latest LTS versions from NVIDIA website
- **Firmware**: Auto-discovers latest firmware for specific PSIDs and models
- **Fallback Safety**: Uses static configurations when auto-detection fails
- **Multiple Methods**: Employs various detection strategies for reliability

### Command-Line Interface
**Consistent User Experience:**
- Standardized `--help` functionality across all scripts
- Consistent argument parsing and error handling
- Clear usage examples and option descriptions
- Professional output formatting with color coding

### Safety and Validation
**Comprehensive Protection:**
- **Pre-flight Checks**: Validates prerequisites before operations
- **User Confirmations**: Multiple confirmation prompts for destructive operations
- **Backup Creation**: Automatic firmware backups before updates
- **Compatibility Verification**: Checks firmware compatibility before installation
- **Error Recovery**: Detailed error messages with recovery suggestions

### Testing Framework
**Built-in Quality Assurance:**
- **Quick Test**: 30-second validation of core functionality
- **Comprehensive Test**: Detailed validation with 12 test categories
- **Non-destructive**: Safe to run in any environment
- **Detailed Reporting**: Clear pass/fail indicators with actionable results

### Logging and Monitoring
**Professional Operations:**
- **Comprehensive Logging**: Detailed logs with timestamps for all operations
- **Progress Indicators**: Clear indication of current operation status
- **Error Tracking**: Detailed error logging for troubleshooting
- **Audit Trail**: Complete record of all changes and operations

### Configuration Management
**Flexible Deployment:**
- **JSON Configuration**: Structured configuration files for firmware mappings
- **Environment Variables**: Support for environment-based configuration
- **Mode Selection**: Choose between auto-detection and static configuration
- **Version Control**: Easy updates for new firmware releases

## SR-IOV Configuration

### Automated VF Configuration Script

The `create-virtual-function.sh` script provides comprehensive Virtual Function management with both hardware and runtime configuration:

```bash
# Run the automated VF configuration script
sudo ./create-virtual-function.sh
```

**What the script does:**

1. **Hardware VF Limit Configuration** (Persistent):
   - Uses `mlxconfig` to set `NUM_OF_VFS=127` for all Mellanox devices
   - Configures hardware limits that survive reboots
   - Only targets physical functions (.0/.1) to avoid VF sub-devices

2. **Runtime VF Creation** (Immediate):
   - Auto-detects ConnectX-7 network interfaces
   - Resets existing VFs to 0 first (required for changes)
   - Creates up to 127 VFs per interface (based on hardware limits)
   - Uses proper `tee` commands for sysfs file writes with sudo

**Key Features:**
- **Two-step process**: Hardware configuration + Runtime creation
- **Automatic device detection**: Finds all ConnectX-7 interfaces
- **Proper privilege handling**: Works with `sudo` without requiring root shell
- **Enhanced stability**: 10-second wait times for VF state transitions
- **Comprehensive logging**: Step-by-step process tracking
- **Reboot detection**: Warns when hardware changes require reboot

### Manual VF Configuration (Alternative)

If you prefer manual configuration:

```bash
# Check current VF configuration
mlxconfig -d 0000:05:00.0 query | grep NUM_OF_VFS

# Set hardware VF limits (requires reboot)
sudo mlxconfig -d 0000:05:00.0 set NUM_OF_VFS=127 --yes
sudo mlxconfig -d 0000:05:00.1 set NUM_OF_VFS=127 --yes
sudo reboot

# Create runtime VFs after reboot
echo 0 | sudo tee /sys/class/net/ens1f0np0/device/sriov_numvfs
echo 127 | sudo tee /sys/class/net/ens1f0np0/device/sriov_numvfs
```

### Understanding VF Configuration

**Hardware vs Runtime Configuration:**

| Aspect | Hardware Configuration | Runtime Configuration |
|--------|----------------------|---------------------|
| **Tool** | `mlxconfig` | `sysfs` (`/sys/class/net/*/device/sriov_numvfs`) |
| **Persistence** | Survives reboots | Lost on reboot |
| **Reboot Required** | Yes | No |
| **Purpose** | Sets maximum VF limit | Creates actual VFs |
| **Scope** | Per physical device | Per network interface |

**Process Flow:**
1. **Hardware Limits** → Set with `mlxconfig` (persistent, requires reboot)
2. **Runtime Creation** → Create VFs with sysfs (immediate, temporary)
3. **Verification** → Check both hardware limits and active VFs

**Common Issues:**
- **"Failed to set VFs to 127"** → Hardware limits not applied yet (reboot required)
- **"Partial VF configuration"** → Runtime VFs limited by current hardware maximum
- **Permission denied** → Use `tee` instead of direct redirection with sudo
```

### Systemd Service for Auto VF Creation

Install the VF creation service to run automatically on boot/reboot:

```bash
# Install the service (copies files and enables service)
sudo ./install-vf-service.sh
```

**Manual Installation (Alternative):**

1. Copy the script to system location:
```bash
sudo cp create-virtual-function.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/create-virtual-function.sh
```

2. Install the service file:
```bash
sudo cp create-vf.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable create-vf.service
```

**Service Management:**
```bash
# Start service immediately
sudo systemctl start create-vf

# Check service status
sudo systemctl status create-vf

# View service logs
sudo journalctl -u create-vf -f

# Stop service
sudo systemctl stop create-vf

# Disable automatic startup
sudo systemctl disable create-vf
```

## Monitoring and Troubleshooting

### Key Commands

#### MST (Mellanox Software Tools) Service Management

```bash
# Start MST service - Initializes the MST driver and creates device files
# Required before using any MFT tools like mlxconfig, flint, or mlxlink
sudo mst start

# Check MST service status - Shows running MST devices and their paths
# Displays all detected Mellanox devices with their /dev/mst/ paths
sudo mst status

# Stop MST service - Cleanly shuts down MST driver and removes device files
# Use when troubleshooting or before system maintenance
sudo mst stop
```

#### Device Management and Monitoring

```bash
# Query device configuration
mlxconfig -d <device> query

# Check link status
mlxlink -d <device> -p 1

# Check firmware info
flint -d <device> query

# Monitor temperature
mget_temp -d <mst_device>

# List PCI devices
lspci | grep -i "MT2910\|ConnectX-7"
```

### Common Issues and Solutions

1. **MST service not starting**: Ensure kernel modules are loaded
2. **Temperature warnings**: Check cooling and airflow
3. **Link down**: Verify cable connections and compatibility
4. **VF creation fails**: Ensure firmware supports SR-IOV and reboot after configuration

## Hardware Specifications

### Tested Configuration
- **Model**: MCX755106AS-HEA_Ax
- **Type**: NVIDIA ConnectX-7 HHHL Adapter Card
- **Speed**: 200GbE (default mode) / NDR200 IB
- **Ports**: Dual-port QSFP112
- **PCIe**: 5.0 x16 with x16 extension option
- **VF Support**: Up to 127 VFs per port
- **Operating Temperature**: Normal range 60-70°C

### Lab Test Results
- 4 ConnectX-7 ports detected
- All ports LinkUp at 200G speed
- Firmware version: 28.40.1000
- Temperature: 65°C (normal)
- VF configuration: 127 VFs per port

## Important Notes

**⚠️ PRODUCTION USE DISCLAIMER:**
- This is a **PERSONAL REFERENCE PROJECT** for educational purposes
- **NOT INTENDED FOR PRODUCTION** without extensive lab validation
- **NO SUPPORT OR WARRANTY** provided - use at your own risk
- **MANDATORY TESTING** required in isolated lab environments
- Author assumes **NO RESPONSIBILITY** for any damage or issues

**Technical Guidelines:**
1. **Always use LTS firmware versions** for production environments
2. **Test firmware updates in lab environment first** - multiple iterations required
3. **Reboot required** after VF configuration changes
4. **Monitor temperatures** regularly to prevent overheating
5. **Verify PSID compatibility** before firmware updates
6. **Create firmware backups** before any updates
7. **Have recovery procedures** ready before making changes

## Version Information

- **MFT Version**: 4.30.1-1210 (update to latest LTS)
- **Firmware Version**: 28.40.1000+ (use latest LTS)
- **Supported OS**: Amazon Linux 2023, RHEL 8/9, Ubuntu 20.04+

## 🚀 Usage Examples and Workflows

### Complete Setup Workflow
```bash
# 1. Validate all scripts first
./quick-test.sh

# 2. Install MFT tools with auto-detection
sudo ./install-mft.sh

# 3. Run health check to verify installation
sudo ./mlx-nic-health-check.sh

# 4. Update firmware to latest LTS version
sudo ./update-cx7-firmware.sh

# 5. Configure Virtual Functions (if needed)
sudo ./create-virtual-function.sh

# Note: If hardware VF limits were changed, reboot is required:
# sudo reboot
```

### Testing and Validation Workflow
```bash
# Quick validation before deployment
./quick-test.sh

# Comprehensive testing for production readiness
./test-all-scripts.sh

# Test specific script help functions
./install-mft.sh --help
./install-cx7-firmware.sh --help
./update-cx7-firmware.sh --help
./mlx-nic-health-check.sh --help
```

### Firmware Management Workflows

#### Auto-Detection Mode (Recommended)
```bash
# Let scripts automatically find latest versions
sudo ./update-cx7-firmware.sh
```

#### Static Configuration Mode (Controlled Environments)
```bash
# Use predefined firmware mappings
sudo ./update-cx7-firmware.sh --no-auto-detect
```

#### Manual Version Control
```bash
# Install specific MFT version
sudo ./install-mft.sh --version 4.30.1-1210

# Use static firmware configuration
sudo ./install-cx7-firmware.sh --no-auto-detect
```

### Troubleshooting Workflow
```bash
# 1. Run comprehensive health check
sudo ./mlx-nic-health-check.sh

# 2. Check MFT installation
sudo mst status

# 3. Verify device detection
lspci | grep -i "MT2910\|ConnectX-7"

# 4. Check firmware versions
sudo flint -d 0000:05:00.0 query

# 5. Monitor temperatures
sudo mget_temp -d /dev/mst/mt4129_pciconf0
```

## References

- [NVIDIA Mellanox Firmware Tools](https://network.nvidia.com/products/adapter-software/firmware-tools/)
- [ConnectX-7 Firmware Downloads](https://network.nvidia.com/support/firmware/connectx7/)
- [SR-IOV Configuration Guide](https://enterprise-support.nvidia.com/s/article/HowTo-Configure-SR-IOV-for-ConnectX-4-ConnectX-5-ConnectX-6-with-KVM-Ethernet)

## License

This project is licensed under the MIT License - see the LICENSE file for details.