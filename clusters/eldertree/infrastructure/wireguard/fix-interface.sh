#!/bin/bash
set -e

# Fix WireGuard Interface Configuration
# Updates existing WireGuard config to use the correct network interface

echo "🔧 WireGuard Interface Fix"
echo "========================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Check if WireGuard config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "❌ WireGuard config not found at /etc/wireguard/wg0.conf"
    echo "   Run install-wireguard.sh first to create the configuration."
    exit 1
fi

# Detect the default network interface
echo "🌐 Detecting network interface..."
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Fallback: try common interface names if detection fails
if [ -z "$DEFAULT_INTERFACE" ] || [ ! -d "/sys/class/net/$DEFAULT_INTERFACE" ]; then
    echo "⚠️  Could not detect default interface, trying common names..."
    for iface in wlan0 eth0 enp0s3 enp0s8; do
        if [ -d "/sys/class/net/$iface" ] && ip addr show "$iface" | grep -q "inet "; then
            DEFAULT_INTERFACE="$iface"
            echo "✅ Using detected interface: $DEFAULT_INTERFACE"
            break
        fi
    done
fi

if [ -z "$DEFAULT_INTERFACE" ]; then
    echo "❌ Could not detect network interface. Please set DEFAULT_INTERFACE manually."
    exit 1
fi

echo "✅ Detected interface: $DEFAULT_INTERFACE"
echo ""

# Check if config already uses the correct interface
if grep -q "POSTROUTING -o ${DEFAULT_INTERFACE}" /etc/wireguard/wg0.conf; then
    echo "✅ Configuration already uses correct interface: $DEFAULT_INTERFACE"
    exit 0
fi

# Backup existing config
BACKUP_FILE="/etc/wireguard/wg0.conf.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/wireguard/wg0.conf "$BACKUP_FILE"
echo "📋 Backup created: $BACKUP_FILE"
echo ""

# Update the config file
echo "🔧 Updating configuration..."

# Use sed to replace interface names in PostUp/PostDown lines
# Replace common interface names (eth0, wlan0, etc.) with detected interface
sed -i.bak \
    -e "s/-o eth0 -j MASQUERADE/-o ${DEFAULT_INTERFACE} -j MASQUERADE/g" \
    -e "s/-o wlan0 -j MASQUERADE/-o ${DEFAULT_INTERFACE} -j MASQUERADE/g" \
    -e "s/-o enp0s3 -j MASQUERADE/-o ${DEFAULT_INTERFACE} -j MASQUERADE/g" \
    -e "s/-o enp0s8 -j MASQUERADE/-o ${DEFAULT_INTERFACE} -j MASQUERADE/g" \
    /etc/wireguard/wg0.conf

# Remove backup file created by sed
rm -f /etc/wireguard/wg0.conf.bak

echo "✅ Configuration updated"
echo ""

# Show the updated PostUp/PostDown lines
echo "📋 Updated NAT rules:"
grep -E "PostUp|PostDown" /etc/wireguard/wg0.conf | grep MASQUERADE
echo ""

# Restart WireGuard to apply changes
echo "🔄 Restarting WireGuard service..."
if systemctl is-active --quiet wg-quick@wg0; then
    systemctl restart wg-quick@wg0
    sleep 2
    
    if systemctl is-active --quiet wg-quick@wg0; then
        echo "✅ WireGuard restarted successfully"
        echo ""
        echo "📊 Current status:"
        wg show
    else
        echo "⚠️  WireGuard restart had issues. Check logs:"
        echo "   sudo journalctl -u wg-quick@wg0 -n 50"
        exit 1
    fi
else
    echo "⚠️  WireGuard service is not running. Start it with:"
    echo "   sudo systemctl start wg-quick@wg0"
fi

echo ""
echo "🎉 Interface fix complete!"
echo ""
echo "Verify NAT is working:"
echo "  sudo iptables -t nat -L POSTROUTING -n -v | grep ${DEFAULT_INTERFACE}"
echo ""
echo "Should show MASQUERADE rule with packet counts increasing."

