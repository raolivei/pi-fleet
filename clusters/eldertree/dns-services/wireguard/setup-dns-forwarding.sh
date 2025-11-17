#!/bin/bash
set -e

# Setup DNS Forwarding on WireGuard VPN Server
# This allows iOS clients to use VPN server IP (10.8.0.1) as DNS,
# which forwards queries to Pi-hole (192.168.2.83)

echo "🔧 Setting up DNS Forwarding on WireGuard Server"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Configuration
VPN_SERVER_IP="10.8.0.1"
PIHOLE_IP="192.168.2.83"
DNSMASQ_CONF="/etc/dnsmasq.conf"
DNSMASQ_D_DIR="/etc/dnsmasq.d"

echo "📋 Configuration:"
echo "  VPN Server IP: ${VPN_SERVER_IP}"
echo "  Pi-hole IP: ${PIHOLE_IP}"
echo ""

# Install dnsmasq
echo "📦 Installing dnsmasq..."
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y dnsmasq
elif command -v dnf &> /dev/null; then
    dnf install -y dnsmasq
else
    echo "❌ Cannot detect package manager"
    exit 1
fi

echo "✅ dnsmasq installed"
echo ""

# Backup existing config
if [ -f "$DNSMASQ_CONF" ]; then
    echo "📋 Backing up existing dnsmasq.conf..."
    cp "$DNSMASQ_CONF" "${DNSMASQ_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create dnsmasq config directory if it doesn't exist
mkdir -p "$DNSMASQ_D_DIR"

# Create WireGuard DNS forwarding config
echo "🔧 Creating DNS forwarding configuration..."
cat > "${DNSMASQ_D_DIR}/wireguard-dns.conf" <<EOF
# WireGuard VPN DNS Forwarding Configuration
# Created: $(date)

# Listen on VPN server IP
listen-address=${VPN_SERVER_IP},127.0.0.1

# Forward DNS queries to Pi-hole
server=${PIHOLE_IP}

# Don't use /etc/hosts (Pi-hole handles local domains)
no-hosts

# Cache size
cache-size=1000

# Log queries (optional, for debugging)
# log-queries
# log-facility=/var/log/dnsmasq.log
EOF

echo "✅ Configuration created: ${DNSMASQ_D_DIR}/wireguard-dns.conf"
echo ""

# Disable systemd-resolved if it's running (conflicts with dnsmasq)
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo "⚠️  systemd-resolved is running, disabling it..."
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    echo "✅ systemd-resolved disabled"
    echo ""
fi

# Enable and start dnsmasq
echo "🚀 Starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq

# Check if dnsmasq is running
if systemctl is-active --quiet dnsmasq; then
    echo "✅ dnsmasq is running"
    echo ""
    
    # Test DNS forwarding
    echo "🧪 Testing DNS forwarding..."
    if dig @${VPN_SERVER_IP} google.com +short > /dev/null 2>&1; then
        echo "✅ DNS forwarding is working!"
    else
        echo "⚠️  DNS forwarding test failed, but dnsmasq is running"
    fi
    echo ""
else
    echo "❌ Failed to start dnsmasq"
    echo "Check logs: sudo journalctl -u dnsmasq -n 50"
    exit 1
fi

# Check firewall
if command -v ufw &> /dev/null; then
    echo "🔥 Checking firewall..."
    if ufw status | grep -q "53/udp"; then
        echo "✅ DNS port 53 is already allowed"
    else
        echo "⚠️  Adding DNS port to firewall..."
        ufw allow 53/udp comment 'DNS forwarding'
        echo "✅ DNS port added to firewall"
    fi
    echo ""
fi

echo "🎉 DNS forwarding setup complete!"
echo ""
echo "📋 Summary:"
echo "  - dnsmasq is listening on ${VPN_SERVER_IP}"
echo "  - DNS queries are forwarded to Pi-hole (${PIHOLE_IP})"
echo "  - Clients can now use ${VPN_SERVER_IP} as DNS"
echo ""
echo "📱 Next steps:"
echo "  1. Update client-mobile.conf: DNS = ${VPN_SERVER_IP}"
echo "  2. Re-import config into WireGuard app on iPhone"
echo "  3. Connect and test: https://canopy.eldertree.local"
echo ""
echo "To test DNS forwarding:"
echo "  dig @${VPN_SERVER_IP} canopy.eldertree.local"
echo ""


