#!/bin/bash
# Test iPhone VPN connectivity from server side

echo "=== iPhone VPN Connection Test ==="
echo ""

echo "📊 Server-side WireGuard Status:"
kubectl exec -n wireguard deployment/wireguard -- wg show | grep -A 6 "0q2Hmp7wvLUxuH8BuS1uj/Cd51eZw5C8w8G/Cm4njkM="

echo ""
echo "🧪 Testing Connectivity:"
echo ""

echo "1. Testing VPN tunnel (10.8.0.3)..."
kubectl exec -n wireguard deployment/wireguard -- ping -c 2 10.8.0.3 2>&1 | tail -3

echo ""
echo "2. Checking routing..."
kubectl exec -n wireguard deployment/wireguard -- ip route get 10.8.0.3

echo ""
echo "✅ If you see handshake times and ping responses, iPhone VPN is working!"
echo ""
echo "📱 On your iPhone, test:"
echo "   - Safari → google.com (should work)"
echo "   - Safari → ifconfig.me (should show YOUR cellular IP)"
echo "   - WireGuard app → Check 'Latest handshake' is recent"

