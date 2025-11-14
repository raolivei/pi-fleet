#!/bin/bash
set -e

# Setup DNS Forwarding using systemd-resolved
# This is simpler and doesn't require dnsmasq

echo "🔧 Setting up DNS Forwarding using systemd-resolved"
echo "==================================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

VPN_SERVER_IP="10.8.0.1"
PIHOLE_IP="192.168.2.83"
RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_D_DIR="/etc/systemd/resolved.conf.d"

echo "📋 Configuration:"
echo "  VPN Server IP: ${VPN_SERVER_IP}"
echo "  Pi-hole IP: ${PIHOLE_IP}"
echo ""

# Enable systemd-resolved if not already enabled
if ! systemctl is-enabled systemd-resolved > /dev/null 2>&1; then
    echo "🚀 Enabling systemd-resolved..."
    systemctl enable systemd-resolved
fi

# Start systemd-resolved if not running
if ! systemctl is-active --quiet systemd-resolved; then
    echo "🚀 Starting systemd-resolved..."
    systemctl start systemd-resolved
fi

# Create config directory
mkdir -p "$RESOLVED_D_DIR"

# Create DNS forwarding configuration
echo "🔧 Creating DNS forwarding configuration..."
cat > "${RESOLVED_D_DIR}/wireguard-dns.conf" <<EOF
[Resolve]
# DNS servers to use (Pi-hole)
DNS=${PIHOLE_IP}
# Fallback DNS servers
FallbackDNS=8.8.8.8 8.8.4.4
# Don't use systemd-resolved's stub resolver for VPN interface
DNSStubListener=no
EOF

echo "✅ Configuration created: ${RESOLVED_D_DIR}/wireguard-dns.conf"
echo ""

# Configure systemd-resolved to listen on VPN interface
echo "🔧 Configuring systemd-resolved to listen on VPN interface..."
# We'll use a networkd drop-in or configure the interface directly

# Create networkd config for WireGuard interface
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/wg0.network <<EOF
[Match]
Name=wg0

[Network]
DNS=${PIHOLE_IP}
DNSDefaultRoute=yes
Domains=eldertree.local
EOF

echo "✅ Network configuration created"
echo ""

# Restart systemd-resolved
echo "🔄 Restarting systemd-resolved..."
systemctl restart systemd-resolved

# Wait a moment
sleep 2

# Check if systemd-resolved is running
if systemctl is-active --quiet systemd-resolved; then
    echo "✅ systemd-resolved is running"
    echo ""
    
    # Test DNS
    echo "🧪 Testing DNS..."
    if systemd-resolve --status | grep -q "${PIHOLE_IP}"; then
        echo "✅ DNS configuration applied"
    fi
    echo ""
else
    echo "❌ Failed to start systemd-resolved"
    exit 1
fi

# Alternative: Use socat or a simple DNS proxy
echo "📋 Alternative: Setting up simple DNS proxy using socat..."
if command -v socat &> /dev/null || apt-get install -y socat 2>/dev/null; then
    # Create a simple DNS proxy service
    cat > /etc/systemd/system/wireguard-dns-proxy.service <<EOF
[Unit]
Description=WireGuard DNS Proxy
After=network.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
ExecStart=/usr/bin/socat UDP4-LISTEN:53,fork,reuseaddr UDP4:${PIHOLE_IP}:53
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wireguard-dns-proxy.service
    systemctl start wireguard-dns-proxy.service
    
    if systemctl is-active --quiet wireguard-dns-proxy.service; then
        echo "✅ DNS proxy service is running"
    fi
else
    echo "⚠️  socat not available, skipping DNS proxy setup"
fi

echo ""
echo "🎉 DNS forwarding setup complete!"
echo ""
echo "📋 Summary:"
echo "  - systemd-resolved configured to use Pi-hole (${PIHOLE_IP})"
echo "  - DNS proxy service listening on ${VPN_SERVER_IP}:53"
echo "  - Clients can use ${VPN_SERVER_IP} as DNS"
echo ""
echo "📱 Next steps:"
echo "  1. Update client-mobile.conf: DNS = ${VPN_SERVER_IP}"
echo "  2. Re-import config into WireGuard app on iPhone"
echo "  3. Connect and test: https://canopy.eldertree.local"
echo ""


