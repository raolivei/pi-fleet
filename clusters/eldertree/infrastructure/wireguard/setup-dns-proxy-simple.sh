#!/bin/bash
set -e

# Simple DNS Proxy using socat
# Listens on VPN server IP (10.8.0.1) and forwards to Pi-hole

echo "🔧 Setting up Simple DNS Proxy"
echo "==============================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

VPN_SERVER_IP="10.8.0.1"
PIHOLE_IP="192.168.2.83"

echo "📋 Configuration:"
echo "  Listen on: ${VPN_SERVER_IP}:53"
echo "  Forward to: ${PIHOLE_IP}:53"
echo ""

# Install socat
echo "📦 Installing socat..."
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y socat
elif command -v dnf &> /dev/null; then
    dnf install -y socat
else
    echo "❌ Cannot detect package manager"
    exit 1
fi

echo "✅ socat installed"
echo ""

# Create systemd service for DNS proxy
echo "🔧 Creating DNS proxy service..."
cat > /etc/systemd/system/wireguard-dns-proxy.service <<EOF
[Unit]
Description=WireGuard DNS Proxy (forwards to Pi-hole)
After=network.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
ExecStart=/usr/bin/socat UDP4-LISTEN:53,bind=${VPN_SERVER_IP},fork,reuseaddr UDP4:${PIHOLE_IP}:53
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created: /etc/systemd/system/wireguard-dns-proxy.service"
echo ""

# Reload systemd
systemctl daemon-reload

# Enable and start the service
echo "🚀 Starting DNS proxy service..."
systemctl enable wireguard-dns-proxy.service

# Check if WireGuard is running before starting DNS proxy
if systemctl is-active --quiet wg-quick@wg0.service; then
    systemctl start wireguard-dns-proxy.service
    sleep 2
    
    if systemctl is-active --quiet wireguard-dns-proxy.service; then
        echo "✅ DNS proxy service is running"
        echo ""
        
        # Test DNS proxy
        echo "🧪 Testing DNS proxy..."
        if dig @${VPN_SERVER_IP} google.com +short > /dev/null 2>&1; then
            echo "✅ DNS proxy is working!"
        else
            echo "⚠️  DNS proxy test failed, but service is running"
            echo "   Check logs: sudo journalctl -u wireguard-dns-proxy.service -n 20"
        fi
    else
        echo "⚠️  DNS proxy service failed to start"
        echo "   Check logs: sudo journalctl -u wireguard-dns-proxy.service -n 20"
        echo "   Note: Service will start automatically when WireGuard is running"
    fi
else
    echo "⚠️  WireGuard is not running"
    echo "   DNS proxy service is enabled and will start when WireGuard starts"
fi

echo ""

# Check firewall
if command -v ufw &> /dev/null; then
    echo "🔥 Checking firewall..."
    if ufw status | grep -q "53/udp"; then
        echo "✅ DNS port 53 is already allowed"
    else
        echo "⚠️  Adding DNS port to firewall..."
        ufw allow 53/udp comment 'WireGuard DNS proxy'
        echo "✅ DNS port added to firewall"
    fi
    echo ""
fi

echo "🎉 DNS proxy setup complete!"
echo ""
echo "📋 Summary:"
echo "  - DNS proxy listening on ${VPN_SERVER_IP}:53"
echo "  - Forwards queries to Pi-hole (${PIHOLE_IP}:53)"
echo "  - Service will start automatically with WireGuard"
echo ""
echo "📱 Next steps:"
echo "  1. Update client-mobile.conf: DNS = ${VPN_SERVER_IP}"
echo "  2. Re-import config into WireGuard app on iPhone"
echo "  3. Connect WireGuard (DNS proxy will start automatically)"
echo "  4. Test: https://canopy.eldertree.local"
echo ""
echo "To check status:"
echo "  sudo systemctl status wireguard-dns-proxy.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u wireguard-dns-proxy.service -f"
echo ""


