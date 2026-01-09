#!/bin/bash
# Configure fresh Raspberry Pi installation
# - Set hostname
# - Configure PoE+ HAT
# - Prepare for NVMe boot migration
# Usage: ./configure-node-fresh-install.sh <node-name> <ip-address>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NODE_NAME="${1:-}"
IP_ADDRESS="${2:-}"

if [ -z "$NODE_NAME" ] || [ -z "$IP_ADDRESS" ]; then
    echo -e "${RED}❌ Error: Node name and IP address required${NC}"
    echo "Usage: $0 <node-name> <ip-address>"
    echo "Example: $0 node-1 192.168.2.85"
    exit 1
fi

echo -e "${BLUE}=== Configuring Fresh Installation for $NODE_NAME ===${NC}"
echo ""

# Set hostname
echo -e "${YELLOW}[1/4] Setting hostname...${NC}"
echo "$NODE_NAME" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NODE_NAME $NODE_NAME.eldertree.local/" /etc/hosts || \
    echo "127.0.1.1\t$NODE_NAME $NODE_NAME.eldertree.local" | sudo tee -a /etc/hosts > /dev/null
sudo hostnamectl set-hostname "$NODE_NAME"
echo -e "${GREEN}✓ Hostname set to $NODE_NAME${NC}"
echo ""

# Configure static IP (if needed)
echo -e "${YELLOW}[2/4] Configuring network...${NC}"
if [ -d /etc/netplan ]; then
    NETPLAN_FILE="/etc/netplan/50-eldertree.yaml"
    sudo tee "$NETPLAN_FILE" > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - $IP_ADDRESS/24
      gateway4: 192.168.2.1
      nameservers:
        addresses:
          - 192.168.2.1
          - 8.8.8.8
EOF
    sudo netplan apply
    echo -e "${GREEN}✓ Network configured${NC}"
else
    echo -e "${YELLOW}⚠️  netplan not found, skipping network config${NC}"
fi
echo ""

# Configure PoE+ HAT
echo -e "${YELLOW}[3/4] Configuring PoE+ HAT...${NC}"
# Check if PoE HAT is detected
if [ -f /proc/device-tree/hat/product ] && grep -qi "poe" /proc/device-tree/hat/product 2>/dev/null; then
    echo -e "${GREEN}✓ PoE+ HAT detected${NC}"
    
    # Enable PoE+ in config.txt if needed
    if [ -f /boot/firmware/config.txt ]; then
        BOOT_CONFIG="/boot/firmware/config.txt"
    elif [ -f /boot/config.txt ]; then
        BOOT_CONFIG="/boot/config.txt"
    else
        BOOT_CONFIG=""
    fi
    
    if [ -n "$BOOT_CONFIG" ]; then
        # Add PoE+ configuration if not present
        if ! grep -q "poe" "$BOOT_CONFIG" 2>/dev/null; then
            echo "" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "# PoE+ HAT Configuration" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "dtparam=poe_fan_temp0=50000" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "dtparam=poe_fan_temp1=60000" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "dtparam=poe_fan_temp2=70000" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "dtparam=poe_fan_temp3=80000" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo -e "${GREEN}✓ PoE+ configuration added to $BOOT_CONFIG${NC}"
        else
            echo -e "${GREEN}✓ PoE+ already configured${NC}"
        fi
    fi
    
    # Check PoE+ status
    if command -v vcgencmd &> /dev/null; then
        POE_STATUS=$(vcgencmd get_throttled 2>/dev/null || echo "unknown")
        echo "  PoE status: $POE_STATUS"
    fi
else
    echo -e "${YELLOW}⚠️  PoE+ HAT not detected in device tree${NC}"
    echo "  This is normal if HAT is not yet connected or needs driver"
    echo "  PoE+ will work once connected to PoE+ switch"
fi
echo ""

# Verify NVMe is detected
echo -e "${YELLOW}[4/4] Checking NVMe drive...${NC}"
if [ -b /dev/nvme0n1 ]; then
    NVME_SIZE=$(blockdev --getsize64 /dev/nvme0n1)
    NVME_SIZE_GB=$((NVME_SIZE / 1024 / 1024 / 1024))
    echo -e "${GREEN}✓ NVMe detected: ${NVME_SIZE_GB}GB${NC}"
    
    # Check if already partitioned
    if [ -b /dev/nvme0n1p1 ] || [ -b /dev/nvme0n1p2 ]; then
        echo -e "${YELLOW}⚠️  NVMe already has partitions${NC}"
        lsblk /dev/nvme0n1
    else
        echo -e "${GREEN}✓ NVMe is empty, ready for migration${NC}"
    fi
else
    echo -e "${RED}❌ NVMe not detected${NC}"
    echo "  Please verify HAT and NVMe are properly connected"
fi
echo ""

echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot to apply hostname: sudo reboot"
echo "  2. After reboot, run migration: sudo ./migrate-nvme-hat.sh $NODE_NAME"
echo "  3. Connect PoE+ to switch (when ready)"
echo ""









