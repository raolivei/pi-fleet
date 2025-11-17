#!/bin/bash
# WireGuard VPN Diagnostic Script

echo "🔍 WireGuard VPN Diagnostic"
echo "=========================="
echo ""

PI_HOST="${PI_HOST:-192.168.2.83}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-Control01!}"

ssh_cmd() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$@"
}

echo "1️⃣  Server Status:"
echo "-------------------"
if ssh_cmd "sudo systemctl is-active --quiet wg-quick@wg0"; then
    echo "✅ WireGuard service is running"
else
    echo "❌ WireGuard service is NOT running"
    exit 1
fi

echo ""
echo "2️⃣  Server Configuration:"
echo "-------------------"
SERVER_PUBKEY=$(ssh_cmd "sudo cat /etc/wireguard/server_public.key")
echo "Server Public Key: $SERVER_PUBKEY"

echo ""
echo "3️⃣  Active Connections:"
echo "-------------------"
CONNECTIONS=$(ssh_cmd "sudo wg show wg0 dump | tail -n +2")
if [ -z "$CONNECTIONS" ]; then
    echo "⚠️  No peer connections found"
else
    echo "$CONNECTIONS" | while IFS=$'\t' read -r pubkey privkey endpoint allowed_ips transfer_rx transfer_tx last_handshake; do
        if [ "$endpoint" = "(none)" ]; then
            echo "⚠️  Peer $pubkey: No handshake (endpoint: $endpoint)"
        else
            echo "✅ Peer $pubkey: Connected from $endpoint"
            echo "   Last handshake: $last_handshake"
            echo "   Transfer: RX=$transfer_rx, TX=$transfer_tx"
        fi
    done
fi

echo ""
echo "4️⃣  Port Forwarding Test:"
echo "-------------------"
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Your current public IP: $PUBLIC_IP"
echo "Testing UDP port 51820..."
if nc -zv -u -w 2 "$PUBLIC_IP" 51820 2>&1 | grep -q "succeeded"; then
    echo "✅ Port 51820 is open and reachable"
else
    echo "⚠️  Port 51820 may not be reachable (this is normal if testing from home network)"
fi

echo ""
echo "5️⃣  Network Context:"
echo "-------------------"
CURRENT_NETWORK=$(route -n get default | grep interface | awk '{print $2}')
echo "Current network interface: $CURRENT_NETWORK"

if ping -c 1 -W 1 192.168.2.83 > /dev/null 2>&1; then
    echo "⚠️  You are on the HOME network (can reach 192.168.2.83 directly)"
    echo "   VPN testing from home network may not work due to NAT loopback"
    echo "   💡 Test from mobile LTE or different WiFi network for accurate results"
else
    echo "✅ You are on an EXTERNAL network (cannot reach 192.168.2.83 directly)"
    echo "   VPN should work from here"
fi

echo ""
echo "6️⃣  Client Configuration Check:"
echo "-------------------"
if [ -f "/usr/local/etc/wireguard/wg0.conf" ]; then
    CLIENT_ENDPOINT=$(grep "^Endpoint" /usr/local/etc/wireguard/wg0.conf | awk '{print $3}')
    CLIENT_PUBKEY=$(grep "^PublicKey" /usr/local/etc/wireguard/wg0.conf | awk '{print $3}')
    echo "Client config found at: /usr/local/etc/wireguard/wg0.conf"
    echo "Endpoint: $CLIENT_ENDPOINT"
    echo "Server PublicKey: $CLIENT_PUBKEY"
    
    if [ "$CLIENT_PUBKEY" = "$SERVER_PUBKEY" ]; then
        echo "✅ Server public key matches"
    else
        echo "❌ Server public key MISMATCH!"
        echo "   Client expects: $CLIENT_PUBKEY"
        echo "   Server has:    $SERVER_PUBKEY"
    fi
    
    if [ "$CLIENT_ENDPOINT" = "$PUBLIC_IP:51820" ]; then
        echo "✅ Endpoint IP matches current public IP"
    else
        echo "⚠️  Endpoint IP mismatch"
        echo "   Client config: $CLIENT_ENDPOINT"
        echo "   Current public IP: $PUBLIC_IP:51820"
    fi
else
    echo "⚠️  Client config not found at /usr/local/etc/wireguard/wg0.conf"
fi

echo ""
echo "📋 Recommendations:"
echo "-------------------"
echo "1. If testing from HOME network:"
echo "   - VPN may not work due to NAT loopback"
echo "   - Test from mobile LTE or different WiFi"
echo ""
echo "2. If testing from EXTERNAL network:"
echo "   - Ensure router port forwarding is configured (UDP 51820 → 192.168.2.83)"
echo "   - Check firewall allows UDP 51820"
echo ""
echo "3. To force VPN routing even on home network:"
echo "   - Temporarily disconnect from WiFi"
echo "   - Connect to mobile hotspot"
echo "   - Then connect VPN"

