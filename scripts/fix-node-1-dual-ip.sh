#!/bin/bash
# Fix dual IP issue on node-1 wlan0 interface
# This script removes the secondary DHCP IP and disables DHCP on wlan0

set -e

echo "=========================================="
echo "Fixing Node-1 Dual IP Issue"
echo "=========================================="
echo ""

# Remove secondary IP immediately
echo "1. Removing secondary IP (192.168.2.86)..."
sudo ip addr del 192.168.2.86/24 dev wlan0 2>/dev/null || echo "   Secondary IP already removed or doesn't exist"

# Backup current netplan config
NETPLAN_FILE="/etc/netplan/90-NM-a22ee936-95b8-3145-95e5-9b44c6e6b7ca.yaml"
if [ -f "$NETPLAN_FILE" ]; then
    echo ""
    echo "2. Backing up netplan config..."
    sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
fi

# Update netplan to disable DHCP
echo ""
echo "3. Updating netplan to disable DHCP..."
sudo sed -i 's/dhcp4: true/dhcp4: false/' "$NETPLAN_FILE"

# Verify the change
echo ""
echo "4. Verifying netplan config..."
sudo grep -A 2 "dhcp4:" "$NETPLAN_FILE" || echo "   Config updated"

# Apply netplan
echo ""
echo "5. Applying netplan changes..."
sudo netplan apply

# Wait for network to stabilize
echo ""
echo "6. Waiting for network to stabilize..."
sleep 5

# Verify fix
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""
echo "wlan0 IPs:"
ip addr show wlan0 | grep "inet " || echo "   No IPs found"

echo ""
echo "Routing table (wlan0 routes):"
ip route show | grep wlan0 || echo "   No wlan0 routes found"

echo ""
echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "wlan0 should now have only 192.168.2.101"
echo "If you still see 192.168.2.86, you may need to:"
echo "  1. Restart NetworkManager: sudo systemctl restart NetworkManager"
echo "  2. Or reboot the node"


