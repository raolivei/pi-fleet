#!/bin/bash
set -e

# WireGuard VPN Server Installation Script for Raspberry Pi
# This script installs and configures WireGuard on the Raspberry Pi host

echo "🔐 WireGuard VPN Server Installation"
echo "===================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

echo "📦 Installing WireGuard..."

# Install WireGuard based on OS
if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ] || [ "$OS" = "raspbian" ]; then
    apt-get update
    apt-get install -y wireguard wireguard-tools iptables qrencode
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p
    
elif [ "$OS" = "fedora" ] || [ "$OS" = "rhel" ] || [ "$OS" = "centos" ]; then
    dnf install -y wireguard-tools iptables qrencode
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

echo "✅ WireGuard installed"

# Create WireGuard directory
mkdir -p /etc/wireguard
cd /etc/wireguard

# Generate server keys if they don't exist
if [ ! -f /etc/wireguard/server_private.key ]; then
    echo "🔑 Generating server keys..."
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    chmod 644 server_public.key
    echo "✅ Server keys generated"
fi

# Read server keys
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Network configuration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.8.0.0/24"
WG_SERVER_IP="10.8.0.1"
LOCAL_NETWORK="192.168.2.0/24"
LOCAL_GATEWAY="192.168.2.1"

# Detect the default network interface (for NAT masquerading)
# This finds the interface used for the default route
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

echo "🌐 Detected network interface: $DEFAULT_INTERFACE"

# Get public IP or use placeholder (will need to be updated)
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_PUBLIC_IP")

# Create server configuration
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# Server private key
PrivateKey = ${SERVER_PRIVATE_KEY}
# Server IP in VPN network
Address = ${WG_SERVER_IP}/24
# Listen on all interfaces
ListenPort = ${WG_PORT}

# Enable IP forwarding and NAT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE

# DNS (use Pi-hole if available, otherwise router)
DNS = 192.168.2.83, ${LOCAL_GATEWAY}

# Clients will be added here
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "✅ Server configuration created at /etc/wireguard/wg0.conf"
echo ""
echo "📋 Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "📋 Server Public IP: ${PUBLIC_IP} (update if using dynamic DNS)"
echo ""

# Enable and start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Check status
if systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard is running"
    wg show
else
    echo "⚠️  WireGuard started but may need configuration"
fi

# Configure firewall (UFW)
if command -v ufw &> /dev/null; then
    echo "🔥 Configuring firewall..."
    ufw allow ${WG_PORT}/udp comment 'WireGuard'
    ufw allow from ${WG_NETWORK} to ${LOCAL_NETWORK} comment 'WireGuard to LAN'
    echo "✅ Firewall configured"
fi

echo ""
echo "🎉 WireGuard installation complete!"
echo ""
echo "Next steps:"
echo "1. Update PUBLIC_IP in server config if needed (currently: ${PUBLIC_IP})"
echo "2. Generate client configurations using generate-client.sh"
echo "3. Add client public keys to /etc/wireguard/wg0.conf"
echo ""
echo "To view server public key:"
echo "  cat /etc/wireguard/server_public.key"
echo ""
echo "To add a client, run on your Mac:"
echo "  ./generate-client.sh <client-name>"
echo ""

