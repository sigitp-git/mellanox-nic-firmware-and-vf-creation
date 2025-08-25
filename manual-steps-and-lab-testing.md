Install Mellanox Firmware tool, and execute script to check Mellanox NIC health

## SSH/SSM to the worker node/bmn-cx2 instance

ubuntu@cloud9-sigitp2:~$ aws ssm start-session --t i-0c6b7476fccdb1ac1

Starting session with SessionId: i-04d8979669e38addf-uy5hsp5te6o6xkhsbocdq975c8

## Download and Install Mellanox MFT tools rpm (LTS)
## https://network.nvidia.com/products/adapter-software/firmware-tools/

sh-5.2$ wget https://www.mellanox.com/downloads/MFT/mft-4.30.1-1210-x86_64-rpm.tgz
--2025-07-17 14:36:02--  https://www.mellanox.com/downloads/MFT/mft-4.30.1-1210-x86_64-rpm.tgz
Resolving www.mellanox.com (www.mellanox.com)... 23.48.203.142, 23.48.203.137
Connecting to www.mellanox.com (www.mellanox.com)|23.48.203.142|:443... connected.
HTTP request sent, awaiting response... 301 Moved Permanently
Location: https://content.mellanox.com/MFT/mft-4.30.1-1210-x86_64-rpm.tgz [following]
--2025-07-17 14:36:03--  https://content.mellanox.com/MFT/mft-4.30.1-1210-x86_64-rpm.tgz
Resolving content.mellanox.com (content.mellanox.com)... 107.178.241.102
Connecting to content.mellanox.com (content.mellanox.com)|107.178.241.102|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 72212536 (69M) [application/gzip]
Saving to: ‘mft-4.30.1-1210-x86_64-rpm.tgz’

mft-4.30.1-1210-x86_64-rpm.tgz                100%[===============================================================================================>]  68.87M  21.1MB/s    in 3.6s

2025-07-17 14:36:07 (19.4 MB/s) - ‘mft-4.30.1-1210-x86_64-rpm.tgz’ saved [72212536/72212536]

sh-5.2$

sh-5.2$ tar xvf mft-4.30.1-1210-x86_64-rpm.tgz
mft-4.30.1-1210-x86_64-rpm/LICENSE.txt
mft-4.30.1-1210-x86_64-rpm/RPMS/
mft-4.30.1-1210-x86_64-rpm/RPMS/mft-4.30.1-1210.x86_64.rpm
mft-4.30.1-1210-x86_64-rpm/RPMS/mft-oem-4.30.1-1210.x86_64.rpm
mft-4.30.1-1210-x86_64-rpm/RPMS/mft-autocomplete-4.30.1-1210.x86_64.rpm
mft-4.30.1-1210-x86_64-rpm/RPMS/mft-pcap-4.30.1-1210.x86_64.rpm
mft-4.30.1-1210-x86_64-rpm/SDEBS/
mft-4.30.1-1210-x86_64-rpm/SDEBS/kernel-mft-dkms_4.30.1-1210_all.deb
mft-4.30.1-1210-x86_64-rpm/SRPMS/
mft-4.30.1-1210-x86_64-rpm/SRPMS/kernel-mft-4.30.1-1210.src.rpm
mft-4.30.1-1210-x86_64-rpm/install.sh
mft-4.30.1-1210-x86_64-rpm/old-mft-uninstall.sh
mft-4.30.1-1210-x86_64-rpm/uninstall.sh
sh-5.2$

sh-5.2$ sudo yum install gcc rpm-build make kernel-devel-6.1.132-147.221.amzn2023.x86_64 -y

sh-5.2$ sudo yum install elfutils-libelf-devel perl -y

sh-5.2$ pwd
/home/ssm-user/mft-4.30.1-1210-x86_64-rpm
sh-5.2$

sh-5.2$ sudo ./install.sh
-I- Removing any old MFT file if exists...
-I- Building the MFT kernel binary RPM...
-I- Installing the MFT RPMs...
Verifying...                          ################################# [100%]
Preparing...                          ################################# [100%]
Updating / installing...
   1:kernel-mft-4.30.1-6.1.132_147.221################################# [100%]
Verifying...                          ################################# [100%]
Preparing...                          ################################# [100%]
Updating / installing...
   1:mft-4.30.1-1210                  ################################# [100%]
Verifying...                          ################################# [100%]
Preparing...                          ################################# [100%]
Updating / installing...
   1:mft-autocomplete-4.30.1-1210     ################################# [100%]
-I- In order to start mst, please run "mst start".
sh-5.2$

sh-5.2$ sudo mst start
Starting MST (Mellanox Software Tools) driver set
Loading MST PCI module - Success
Loading MST PCI configuration module - Success
Create devices
-W- Missing "lsusb" command, skipping MTUSB devices detection
Unloading MST PCI module (unused) - Success
sh-5.2$



wget https://www.mellanox.com/downloads/MFT/mft-4.30.1-1210-x86_64-rpm.tgz
tar xvf mft-4.30.1-1210-x86_64-rpm.tgz
yum install gcc rpm-build make kernel-devel-6.1.132-147.221.amzn2023.x86_64 -y
yum install elfutils-libelf-devel perl -y
cd mft-4.30.1-1210-x86_64-rpm
./install.sh

## Script utilizing MFT/MST tools to 

check Mellanox NIC health

sh-5.2$ vi mlx-nic-health-check.sh

#!/bin/bash
# Mellanox Health Check Script

echo "=== Mellanox NIC Health Check ==="

# Start MST service
echo "Starting MST service..."
mst start

# Check MST status
echo -e "\n=== MST Status ==="
mst status

# Check each device from your setup
# DEVICES=("0000:05:00.0" "0000:05:00.1" "0001:05:00.0" "0001:05:00.1")

mapfile -t DEVICES < <(lspci | grep -i "MT2910\|ConnectX-7" | awk '{print $1}')

for device in "${DEVICES[@]}"; do
    echo -e "\n=== Device: $device ==="

    # Get MST device path for this PCI device
    MST_DEVICE=$(mst status -v | grep "$device" | awk '{print $2}')

    # Basic configuration query
    echo "Configuration Status:"
    mlxconfig -d $device query | grep -E "(Device type|Name|Description|Configurations)"

    # Link status
    echo -e "\nLink Status:"
    mlxlink -d $device -p 1 2>/dev/null | grep -E "(Operational|Link|Speed|Width)"

    # Firmware info
    echo -e "\nFirmware Info:"
    flint -d $device query 2>/dev/null | grep -E "(FW Version|Product Version|PSID)"

    # Temperature check
    echo -e "\nTemperature (Celsius degrees):"
    if [ -n "$MST_DEVICE" ]; then
        mget_temp -d "$MST_DEVICE" 2>/dev/null || echo "Temperature data not available"
    else
        echo "MST device path not found for $device"
    fi
done

echo -e "\n=== VF Status Check ==="
# Check VF configuration from your setup
for device in "${DEVICES[@]}"; do
    echo "Device $device VF count:"
    mlxconfig -d $device query | grep NUM_OF_VFS
done

sh-5.2$ chmod u+x mlx-nic-health-check.sh


## Example output from lab testing


sh-5.2$ sudo ./mlx-nic-health-check.sh
=== Mellanox NIC Health Check ===
Starting MST service...
Starting MST (Mellanox Software Tools) driver set
Loading MST PCI module - Success
[warn] mst_pciconf is already loaded, skipping
Create devices
-W- Missing "lsusb" command, skipping MTUSB devices detection
Unloading MST PCI module (unused) - Success

=== MST Status ===
MST modules:
------------
    MST PCI module is not loaded
    MST PCI configuration module loaded

MST devices:
------------
/dev/mst/mt4129_pciconf0         - PCI configuration cycles access.
                                   domain:bus:dev.fn=0000:05:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 00
/dev/mst/mt4129_pciconf1         - PCI configuration cycles access.
                                   domain:bus:dev.fn=0001:05:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 00


=== Device: 0000:05:00.0 ===
Configuration Status:
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Configurations:                                          Next Boot

Link Status:
Operational Info
Physical state                     : LinkUp
Speed                              : 200G
Width                              : 4x
Enabled Link Speed (Ext.)          : 0x00003ff2 (200G_2X,200G_4X,100G_1X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)
Supported Cable Speed (Ext.)       : 0x000017f2 (200G_4X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)

Firmware Info:
FW Version:            28.40.1000
Product Version:       28.40.1000
PSID:                  MT_0000000834

Temperature (Celsius degrees):
65

=== Device: 0000:05:00.1 ===
Configuration Status:
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Configurations:                                          Next Boot

Link Status:
Operational Info
Physical state                     : LinkUp
Speed                              : 200G
Width                              : 4x
Enabled Link Speed (Ext.)          : 0x00003ff2 (200G_2X,200G_4X,100G_1X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)
Supported Cable Speed (Ext.)       : 0x000017f2 (200G_4X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)

Firmware Info:
FW Version:            28.40.1000
Product Version:       28.40.1000
PSID:                  MT_0000000834

Temperature (Celsius degrees):
65

=== Device: 0001:05:00.0 ===
Configuration Status:
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Configurations:                                          Next Boot

Link Status:
Operational Info
Physical state                     : LinkUp
Speed                              : 200G
Width                              : 4x
Enabled Link Speed (Ext.)          : 0x00003ff2 (200G_2X,200G_4X,100G_1X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)
Supported Cable Speed (Ext.)       : 0x000017f2 (200G_4X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)

Firmware Info:
FW Version:            28.40.1000
Product Version:       28.40.1000
PSID:                  MT_0000000834

Temperature (Celsius degrees):
65

=== Device: 0001:05:00.1 ===
Configuration Status:
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Configurations:                                          Next Boot

Link Status:
Operational Info
Physical state                     : LinkUp
Speed                              : 200G
Width                              : 4x
Enabled Link Speed (Ext.)          : 0x00003ff2 (200G_2X,200G_4X,100G_1X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)
Supported Cable Speed (Ext.)       : 0x000017f2 (200G_4X,100G_2X,100G_4X,50G_1X,50G_2X,40G,25G,10G,1G)

Firmware Info:
FW Version:            28.40.1000
Product Version:       28.40.1000
PSID:                  MT_0000000834

Temperature (Celsius degrees):
65

=== VF Status Check ===
Device 0000:05:00.0 VF count:
        NUM_OF_VFS                                  16
Device 0000:05:00.1 VF count:
        NUM_OF_VFS                                  16
Device 0001:05:00.0 VF count:
        NUM_OF_VFS                                  16
Device 0001:05:00.1 VF count:
        NUM_OF_VFS                                  16
sh-5.2$


Download and install CX-7 firmware with the correct PSID
https://network.nvidia.com/support/firmware/connectx7/


sh-5.2$ pwd
/home/ssm-user
sh-5.2$ wget https://www.mellanox.com/downloads/firmware/fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip
--2024-09-24 20:56:42--  https://www.mellanox.com/downloads/firmware/fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip
Resolving www.mellanox.com (www.mellanox.com)... 23.212.249.25, 23.212.249.9
Connecting to www.mellanox.com (www.mellanox.com)|23.212.249.25|:443... connected.
HTTP request sent, awaiting response... 301 Moved Permanently
Location: https://content.mellanox.com/firmware/fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip [following]
--2024-09-24 20:56:43--  https://content.mellanox.com/firmware/fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip
Resolving content.mellanox.com (content.mellanox.com)... 107.178.241.102
Connecting to content.mellanox.com (content.mellanox.com)|107.178.241.102|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 8759903 (8.4M) [application/zip]
Saving to: ‘fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip’

fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI- 100%[====================================================================================================================>]   8.35M  11.1MB/s    in 0.8s

2024-09-24 20:56:44 (11.1 MB/s) - ‘fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip’ saved [8759903/8759903]

sh-5.2$

sh-5.2$ ls
fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip  mft-4.26.1-6-x86_64-rpm  mft-4.26.1-6-x86_64-rpm.tgz  usbutils-013-4.el9.x86_64.rpm
sh-5.2$

sh-5.2$ unzip fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip
Archive:  fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip
  inflating: fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.cbor
  inflating: fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin
sh-5.2$ ls
fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin      mft-4.26.1-6-x86_64-rpm
fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin.zip  mft-4.26.1-6-x86_64-rpm.tgz
fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.cbor     usbutils-013-4.el9.x86_64.rpm
sh-5.2$

### burning the firmware
### https://network.nvidia.com/support/firmware/nic/
sudo flint -d /dev/mst/mt4129_pciconf0 -i fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin burn
sudo flint -d /dev/mst/mt4129_pciconf1  -i fw-ConnectX7-rel-28_39_3560-MCX755106AS-HEA_Ax-UEFI-14.32.17-FlexBoot-3.7.300.signed.bin burn

VF Number modification

First, make sure the NICs has the LTS version of the firmware:
https://network.nvidia.com/support/firmware/connectx7/
For example "28.45.120028.43.3608-LTS"

Use mlxconfig tool, and change the PCI ID to the right one:
https://enterprise-support.nvidia.com/s/article/HowTo-Configure-SR-IOV-for-ConnectX-4-ConnectX-5-ConnectX-6-with-KVM-Ethernet

[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# lspci | grep MT2910
0000:05:00.0 Ethernet controller: Mellanox Technologies MT2910 Family [ConnectX-7]
0000:05:00.1 Ethernet controller: Mellanox Technologies MT2910 Family [ConnectX-7]
0001:05:00.0 Ethernet controller: Mellanox Technologies MT2910 Family [ConnectX-7]
0001:05:00.1 Ethernet controller: Mellanox Technologies MT2910 Family [ConnectX-7]
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 05:00.0 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  16
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 05:00.0 set NUM_OF_VFS=127
Device #1:
----------
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Device:             05:00.0
Configurations:                                          Next Boot       New
        NUM_OF_VFS                                  16                   127
 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 05:00.1 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  127
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 0000:05:00.0 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  127
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 0000:05:00.1 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  127
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 0001:05:00.0 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  16
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 0001:05:00.0 set NUM_OF_VFS=127
Device #1:
----------
Device type:        ConnectX7
Name:               MCX755106AS-HEA_Ax
Description:        NVIDIA ConnectX-7 HHHL Adapter Card; 200GbE (default mode) / NDR200 IB; Dual-port QSFP112; PCIe 5.0 x16 with x16 PCIe extension option; Crypto Disabled; Secure Boot Enabled
Device:             0001:05:00.0
Configurations:                                          Next Boot       New
        NUM_OF_VFS                                  16                   127
 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]# mlxconfig -d 0001:05:00.1 q | grep NUM_OF_VFS
        NUM_OF_VFS                                  127
[root@ip-10-0-58-16 mft-4.30.1-113-x86_64-rpm]#

Virtual Function Creation Script

#!/bin/bash

# This script initializes Nvidia Mellanox CX-7 cards. Slight changes will be required for different NICs.
yum install -y lshw

INTERFACES=$(lshw -class network -json | jq '.[] | select(.product=="MT2910 Family [ConnectX-7]").logicalname' | tr -d '"')
NUMBER_VFS=127

for interface in ${INTERFACES[@]}
do
    echo Updating Virtual Functions for interface: ${interface}
    echo ${NUMBER_VFS} > /sys/class/net/${interface}/device/sriov_numvfs
done

Virtual Function Creation Service File

[Unit]
Description=Runs Virtual Function Creation Script
After=iptables.service NetworkManager.service libvirtd.service

[Service]
Type=forking
ExecStart=/bin/create-virtual-function.sh

[Install]
WantedBy=default.target


