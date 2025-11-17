#!/bin/bash
# DNS Setup for WireGuard Split-Tunnel
# This configures dnsmasq to forward cluster.local queries to k3s CoreDNS

set -e

echo "=== DNS Setup for k3s Cluster Access ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Install dnsmasq
echo "📦 Installing dnsmasq..."
apt update
apt install -y dnsmasq

# Backup existing config
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d-%H%M%S)
fi

# Get k3s CoreDNS service IP
echo "🔍 Detecting k3s CoreDNS service IP..."
COREDNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "10.43.0.10")

if [ "$COREDNS_IP" == "10.43.0.10" ]; then
    echo "⚠️  Could not detect CoreDNS IP, using default: 10.43.0.10"
    echo "   If this is incorrect, edit /etc/dnsmasq.d/k3s-cluster.conf manually"
else
    echo "✅ Detected CoreDNS IP: $COREDNS_IP"
fi

# Create dnsmasq config for cluster DNS
echo "📝 Creating dnsmasq configuration..."
cat > /etc/dnsmasq.d/k3s-cluster.conf <<EOF
# DNS configuration for k3s cluster access via WireGuard
# Forward cluster.local queries to k3s CoreDNS

# Listen on WireGuard interface
interface=wg0
bind-interfaces

# Forward cluster.local to k3s CoreDNS
server=/cluster.local/${COREDNS_IP}

# Forward custom domains to k3s CoreDNS (uncomment as needed)
server=/swimto.local/${COREDNS_IP}
server=/canopy.local/${COREDNS_IP}
server=/journey.local/${COREDNS_IP}
server=/nima.local/${COREDNS_IP}

# Cache size
cache-size=1000

# Log queries (disable in production)
# log-queries
EOF

# Configure systemd-resolved to not conflict with dnsmasq
if systemctl is-active --quiet systemd-resolved; then
    echo "🔧 Configuring systemd-resolved..."
    
    # Create resolved.conf override
    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/dnsmasq.conf <<EOF
[Resolve]
DNSStubListener=no
EOF
    
    # Restart systemd-resolved
    systemctl restart systemd-resolved
fi

# Enable and restart dnsmasq
echo "🚀 Starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq

# Verify dnsmasq is running
if systemctl is-active --quiet dnsmasq; then
    echo "✅ dnsmasq is running"
else
    echo "❌ dnsmasq failed to start"
    echo "Check logs with: journalctl -xeu dnsmasq"
    exit 1
fi

echo ""
echo "✅ DNS setup complete!"
echo ""
echo "📋 Configuration details:"
echo "- Listening on: wg0 (10.8.0.1)"
echo "- Forwarding *.cluster.local to: $COREDNS_IP"
echo "- Custom domains configured: swimto.local, canopy.local, journey.local, nima.local"
echo ""
echo "🧪 Test DNS resolution from client:"
echo "  nslookup kubernetes.default.svc.cluster.local 10.8.0.1"
echo ""

