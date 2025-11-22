#!/bin/bash
# Check WireGuard Server Status and Configuration
# Run this from home network to diagnose VPN issues

set -e

PI_HOST="${PI_HOST:-192.168.2.83}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-}"

if [ -z "$PI_PASSWORD" ]; then
    echo "❌ Error: PI_PASSWORD environment variable is required"
    echo "Usage: PI_PASSWORD='your-password' $0"
    exit 1
fi

echo "🔍 WireGuard Server Diagnostic"
echo "=============================="
echo ""

ssh_cmd() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$@"
}

echo "1️⃣  Service Status:"
echo "-------------------"
if ssh_cmd "sudo systemctl is-active --quiet wg-quick@wg0"; then
    echo "✅ WireGuard service is running"
else
    echo "❌ WireGuard service is NOT running"
    exit 1
fi

echo ""
echo "2️⃣  Server Public IP:"
echo "-------------------"
SERVER_PUBLIC_IP=$(ssh_cmd "curl -s ifconfig.me")
echo "Current server public IP: $SERVER_PUBLIC_IP"

echo ""
echo "3️⃣  WireGuard Interface Status:"
echo "-------------------"
ssh_cmd "sudo wg show wg0"

echo ""
echo "4️⃣  Listening Port:"
echo "-------------------"
LISTENING=$(ssh_cmd "sudo ss -ulnp | grep 51820")
if [ -n "$LISTENING" ]; then
    echo "✅ WireGuard is listening on UDP 51820"
    echo "$LISTENING"
else
    echo "❌ WireGuard is NOT listening on port 51820"
fi

echo ""
echo "5️⃣  Firewall Rules:"
echo "-------------------"
echo "Forwarding rules:"
ssh_cmd "sudo iptables -L FORWARD -n -v | grep wg0 || echo 'No wg0 forwarding rules found'"
echo ""
echo "NAT/MASQUERADE rules:"
ssh_cmd "sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE | head -3"

echo ""
echo "6️⃣  IP Forwarding:"
echo "-------------------"
IP_FORWARD=$(ssh_cmd "cat /proc/sys/net/ipv4/ip_forward")
if [ "$IP_FORWARD" = "1" ]; then
    echo "✅ IP forwarding is enabled"
else
    echo "❌ IP forwarding is disabled"
fi

echo ""
echo "7️⃣  Server Configuration:"
echo "-------------------"
echo "Network interface used for NAT:"
ssh_cmd "sudo grep -E 'PostUp.*MASQUERADE' /etc/wireguard/wg0.conf | grep -oE '-o [a-z0-9]+' | awk '{print \$2}' || echo 'Not found'"

echo ""
echo "8️⃣  Recent Connection Attempts:"
echo "-------------------"
echo "Checking for recent handshakes..."
PEERS=$(ssh_cmd "sudo wg show wg0 dump | tail -n +2")
if [ -z "$PEERS" ]; then
    echo "⚠️  No peers configured"
else
    echo "$PEERS" | while IFS=$'\t' read -r pubkey privkey endpoint allowed_ips transfer_rx transfer_tx last_handshake; do
        if [ "$endpoint" != "(none)" ]; then
            echo "✅ Peer connected from: $endpoint"
            echo "   Last handshake: $last_handshake"
            echo "   Transfer: RX=$transfer_rx, TX=$transfer_tx"
        else
            echo "⚠️  Peer $pubkey: No handshake (endpoint: $endpoint)"
        fi
    done
fi

echo ""
echo "📋 Summary:"
echo "-----------"
echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "Make sure your client config uses: Endpoint = $SERVER_PUBLIC_IP:51820"
echo ""
echo "If no handshakes are occurring:"
echo "1. Verify router port forwarding (UDP 51820 → 192.168.2.83)"
echo "2. Check router firewall allows UDP 51820"
echo "3. Test from external network (mobile LTE)"
echo "4. Verify client config matches server public key"

