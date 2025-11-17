#!/bin/bash
# Quick deployment script - run WireGuard setup via SSH

set -e

echo "=== Quick WireGuard Deployment via SSH ==="
echo ""

# Configuration
PI_HOST="${PI_HOST:-eldertree.local}"
PI_USER="${PI_USER:-pi}"

echo "📡 Connecting to: $PI_USER@$PI_HOST"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo "1️⃣ Uploading WireGuard setup scripts..."
scp -r ../wireguard/ $PI_USER@$PI_HOST:/tmp/wireguard-setup/

echo ""
echo "2️⃣ Running server setup..."
ssh -t $PI_USER@$PI_HOST "cd /tmp/wireguard-setup && sudo ./setup-server.sh"

echo ""
echo "3️⃣ Getting server public key..."
SERVER_PUBKEY=$(ssh $PI_USER@$PI_HOST "sudo cat /etc/wireguard/publickey")
echo "Server Public Key: $SERVER_PUBKEY"

echo ""
echo "4️⃣ Setting up DNS..."
ssh -t $PI_USER@$PI_HOST "cd /tmp/wireguard-setup && sudo ./setup-dns.sh"

echo ""
echo "✅ WireGuard server deployed!"
echo ""
echo "📋 Next steps:"
echo "1. Generate client config for your MacBook"
echo "2. Get your public IP/domain"
echo "3. Configure port forwarding (UDP 51820)"
echo ""

