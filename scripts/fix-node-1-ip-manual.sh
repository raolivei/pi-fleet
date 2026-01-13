#!/bin/bash
# Manual fix for node-1 IP issue
# Run this ON node-1 (via physical access or SSH)

set -e

echo "=========================================="
echo "Fixing Node-1 IP Configuration"
echo "Removing 192.168.2.86, keeping only 192.168.2.101"
echo "=========================================="
echo ""

# Check current state
echo "Current wlan0 IPs:"
ip addr show wlan0 | grep "inet " || echo "No IPs found"

echo ""
echo "=== Step 1: Removing wrong IP (192.168.2.86) ==="
sudo ip addr del 192.168.2.86/24 dev wlan0 2>/dev/null && echo "✅ Removed 192.168.2.86" || echo "⚠️  Could not remove (may not exist)"

echo ""
echo "=== Step 2: Ensuring correct IP (192.168.2.101) exists ==="
if ! ip addr show wlan0 | grep -q "192.168.2.101"; then
    echo "Adding 192.168.2.101..."
    sudo ip addr add 192.168.2.101/24 dev wlan0
    echo "✅ Added 192.168.2.101"
else
    echo "✅ 192.168.2.101 already exists"
fi

echo ""
echo "=== Step 3: Disabling DHCP in netplan ==="
NETPLAN_FILE="/etc/netplan/90-NM-a22ee936-95b8-3145-95e5-9b44c6e6b7ca.yaml"
if [ -f "$NETPLAN_FILE" ]; then
    # Backup
    sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "✅ Backed up netplan config"
    
    # Disable DHCP
    sudo sed -i 's/dhcp4: true/dhcp4: false/' "$NETPLAN_FILE"
    echo "✅ Disabled DHCP in netplan"
    
    # Verify
    echo ""
    echo "Netplan dhcp4 setting:"
    sudo grep "dhcp4:" "$NETPLAN_FILE"
else
    echo "⚠️  Netplan file not found: $NETPLAN_FILE"
    echo "   Looking for other netplan files..."
    sudo ls -la /etc/netplan/
fi

echo ""
echo "=== Step 4: Applying network changes ==="
sudo netplan apply
echo "✅ Netplan applied"

echo ""
echo "=== Step 5: Restarting NetworkManager ==="
sudo systemctl restart NetworkManager
sleep 3

echo ""
echo "=== Step 6: Verification ==="
echo "wlan0 IPs after fix:"
ip addr show wlan0 | grep "inet "

echo ""
echo "Routing table:"
ip route show | grep wlan0

echo ""
echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "wlan0 should now have only 192.168.2.101"
echo ""
echo "If you still see 192.168.2.86, try:"
echo "  1. Reboot: sudo reboot"
echo "  2. Or manually remove: sudo ip addr del 192.168.2.86/24 dev wlan0"


